import UIKit
import LeanTypeEngine

final class KeyboardViewController: UIInputViewController {
    private var engine: KeyboardEngine
    private var surface: KeyboardSurfaceView!
    private var suggestions: SuggestionStripView!
    private var heightConstraint: NSLayoutConstraint?
    private var fingers: [ObjectIdentifier: FingerTrack] = [:]
    private var nextFinger = 1
    private var queued: [EngineInput] = []
    private var decodeInFlight = false
    private var graceToken = 0
    private var suppressHostUntil = Date.distantPast
    private var started = Date()

    init() {
        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        engine = KeyboardEngine(
            lexicon: MemoryLexicon(wordsInFrequencyOrder: []),
            layout: layout,
            decodesInline: false
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The keyboard is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyboardChrome.paper
        overrideUserInterfaceStyle = .light
        let height = view.heightAnchor.constraint(equalToConstant: 292)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        heightConstraint = height

        suggestions = SuggestionStripView { [weak self] index in
            guard let self else { return }
            let input: EngineInput = self.engine.strip.preview ? .promoteChip(index) : .acceptChip(index)
            self.forward(input)
        }
        surface = KeyboardSurfaceView(frame: .zero) { [weak self] layout in
            guard let self else { return }
            self.engine.update(layout: layout)
        }
        surface.onTouch = { [weak self] phase, touches in
            guard let self else { return }
            self.route(phase, touches)
        }
        suggestions.translatesAutoresizingMaskIntoConstraints = false
        surface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(suggestions)
        view.addSubview(surface)
        NSLayoutConstraint.activate([
            suggestions.topAnchor.constraint(equalTo: view.topAnchor),
            suggestions.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestions.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestions.heightAnchor.constraint(equalToConstant: KeyboardChrome.stripHeight),
            surface.topAnchor.constraint(equalTo: suggestions.bottomAnchor),
            surface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadResources()
        syncHost()
    }

    override func viewWillDisappear(_ animated: Bool) {
        forward(.host(.dismiss))
        if let url = SharedFiles.memoryURL() {
            MemoryStore(url: url).save(engine.learning)
        }
        super.viewWillDisappear(animated)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let compact = traitCollection.verticalSizeClass == .compact
        heightConstraint?.constant = compact ? 216 : 292
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        guard Date() > suppressHostUntil else { return }
        syncHost()
    }

    private func reloadResources() {
        let settings = SettingsStore().load()
        let memory = SharedFiles.memoryURL().map { MemoryStore(url: $0).load() } ?? .empty
        let lexicon = loadLexicon()
        engine = KeyboardEngine(
            lexicon: lexicon,
            layout: surface.layout,
            settings: settings,
            memory: memory,
            decodesInline: false
        )
        let secure = textDocumentProxy.isSecureTextEntry
        forward(.host(.verbatim(secure || lexicon.wordCount == 0)))
    }

    private func loadLexicon() -> any Lexicon {
        let bundled = Bundle.main.url(forResource: "lexicon", withExtension: "ltlex")
        for url in [SharedFiles.lexiconURL(), bundled].compactMap({ $0 }) {
            if let mapped = try? MappedLexicon(contentsOf: url), mapped.wordCount > 0 {
                return mapped
            }
        }
        return MemoryLexicon(wordsInFrequencyOrder: [])
    }

    private func syncHost() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        forward(.host(.textChanged(before + after, caret: before.count)))
    }

    private func route(_ phase: TouchPhase, _ touches: Set<UITouch>) {
        for touch in touches {
            let point = touch.location(in: surface)
            let identity = ObjectIdentifier(touch)
            switch phase {
            case .down:
                let key = surface.key(at: point)
                if let key {
                    surface.setPressed(key.id, pressed: true)
                }
                let track = FingerTrack(id: nextFinger)
                nextFinger += 1
                track.keyID = key?.id
                track.points.append(point)
                fingers[identity] = track
                send(phase, finger: track.id, point: point, key: key)
            case .move:
                guard let track = fingers[identity] else { continue }
                if track.points.count < 64 {
                    track.points.append(point)
                }
                let key = surface.key(at: point)
                if key?.id != track.keyID {
                    if let previous = track.keyID {
                        surface.setPressed(previous, pressed: false)
                    }
                    if let key {
                        surface.setPressed(key.id, pressed: true)
                    }
                    track.keyID = key?.id
                }
                send(phase, finger: track.id, point: point, key: key)
            case .up, .cancel:
                guard let track = fingers.removeValue(forKey: identity) else { continue }
                if let keyID = track.keyID {
                    surface.setPressed(keyID, pressed: false)
                }
                let key = surface.key(at: point)
                send(phase, finger: track.id, point: point, key: key)
            }
        }
        let strokes = fingers.values.map(\.points).filter(isStroke)
        surface.setTrails(strokes)
    }

    private func isStroke(_ points: [CGPoint]) -> Bool {
        guard let first = points.first, let last = points.last else { return false }
        let dx = last.x - first.x
        let dy = last.y - first.y
        return (dx * dx + dy * dy) > 64
    }

    private func send(_ phase: TouchPhase, finger: Int, point: CGPoint, key: PlacedKey?) {
        let sample = TouchSample(
            time: now(),
            finger: FingerID(finger),
            phase: phase,
            point: Point(x: Double(point.x), y: Double(point.y)),
            key: key
        )
        forward(.touch(sample))
    }

    private func forward(_ input: EngineInput) {
        if decodeInFlight {
            queued.append(input)
            return
        }
        let before = engine.observations.count
        present(engine.handle(input))
        let waiting = engine.takePendingDecode() != nil
        if engine.observations.count != before, !waiting {
            present(engine.preview())
        }
        scheduleDecode()
        scheduleGrace()
    }

    private func present(_ effects: [EngineEffect]) {
        guard !effects.isEmpty else { return }
        var document: [EngineEffect] = []
        document.reserveCapacity(effects.count)
        for effect in effects {
            switch effect {
            case .strip(let strip):
                suggestions.show(strip)
            case .page(let page):
                surface.show(page: page)
            default:
                document.append(effect)
            }
        }
        guard !document.isEmpty else { return }
        suppressHostUntil = Date().addingTimeInterval(0.05)
        ProxyBridge.apply(document, proxy: textDocumentProxy)
    }

    private func scheduleDecode() {
        guard let request = engine.takePendingDecode() else { return }
        decodeInFlight = true
        Task { @MainActor in
            let result = await DecoderPool.match(request)
            let effects = self.engine.resolve(result)
            self.decodeInFlight = false
            self.present(effects)
            self.scheduleGrace()
            let pending = self.queued
            self.queued.removeAll(keepingCapacity: true)
            for input in pending {
                self.forward(input)
            }
            if self.view.window == nil, let url = SharedFiles.memoryURL() {
                MemoryStore(url: url).save(self.engine.learning)
            }
        }
    }

    private func scheduleGrace() {
        guard case .grace(let deadline) = engine.phase else { return }
        graceToken += 1
        let token = graceToken
        let wait = max(0, deadline - now().milliseconds)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(wait))
            guard token == self.graceToken else { return }
            guard case .grace = self.engine.phase else { return }
            self.forward(.tick(EngineInstant(milliseconds: deadline)))
        }
    }

    private func now() -> EngineInstant {
        EngineInstant(milliseconds: Int(Date().timeIntervalSince(started) * 1000))
    }
}

private final class FingerTrack {
    let id: Int
    var keyID: String?
    var points: [CGPoint] = []

    init(id: Int) {
        self.id = id
        points.reserveCapacity(64)
    }
}
