import Foundation
@testable import SoratypeEngine

struct Script {
    var engine: KeyboardEngine
    var layout: KeyboardLayout
    var time = 0

    init(words: [String] = Fixture.words, settings: EngineSettings = .default) {
        layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        engine = KeyboardEngine(
            lexicon: MemoryLexicon(wordsInFrequencyOrder: words),
            layout: layout,
            settings: settings
        )
    }

    var text: String { engine.field.text }

    mutating func tap(_ letters: String, finger: Int = 1) {
        for character in letters {
            down(character, finger: finger)
            wait(30)
            up(finger)
            wait(20)
        }
    }

    mutating func swipe(_ letters: String, finger: Int = 1) {
        let characters = Array(letters)
        guard let first = characters.first else { return }
        down(first, finger: finger)
        for character in characters.dropFirst() {
            wait(16)
            move(character, finger: finger)
        }
        wait(16)
        up(finger)
    }

    mutating func down(_ character: Character, finger: Int) {
        send(.down, character: character, finger: finger)
    }

    mutating func move(_ character: Character, finger: Int) {
        send(.move, character: character, finger: finger)
    }

    mutating func up(_ finger: Int) {
        send(.up, character: nil, finger: finger)
    }

    mutating func cancel(_ finger: Int) {
        send(.cancel, character: nil, finger: finger)
    }

    mutating func wait(_ milliseconds: Int) {
        time += milliseconds
    }

    mutating func elapseGrace() {
        wait(engine.settings.handoffGraceMilliseconds)
        engine.handle(.tick(EngineInstant(milliseconds: time)))
    }

    mutating func space() {
        guard let key = layout.keys.first(where: { $0.kind == .space }) else {
            preconditionFailure("Missing space")
        }
        send(.down, key: key, finger: 9)
        wait(20)
        send(.up, key: key, finger: 9)
    }

    mutating func backspace() {
        guard let key = layout.keys.first(where: { $0.kind == .backspace }) else {
            preconditionFailure("Missing backspace")
        }
        send(.down, key: key, finger: 8)
        wait(20)
        send(.up, key: key, finger: 8)
    }

    mutating func dismiss() {
        engine.handle(.host(.dismiss))
    }

    private mutating func send(_ phase: TouchPhase, character: Character, finger: Int) {
        guard let key = layout.key(for: character) else {
            preconditionFailure("Missing \(character)")
        }
        send(phase, key: key, finger: finger)
    }

    private mutating func send(_ phase: TouchPhase, character: Character?, finger: Int) {
        let key = character.flatMap { layout.key(for: $0) }
        let point = key?.frame.center ?? layout.keys.first { $0.id == "\(finger)" }?.frame.center ?? Point(x: 10, y: 10)
        send(phase, key: key, finger: finger, point: point)
    }

    private mutating func send(_ phase: TouchPhase, key: PlacedKey?, finger: Int, point: Point? = nil) {
        let sample = TouchSample(
            time: EngineInstant(milliseconds: time),
            finger: FingerID(finger),
            phase: phase,
            point: point ?? key?.frame.center ?? .zero,
            key: key
        )
        engine.handle(.touch(sample))
        time += 1
    }
}

enum Fixture {
    static let words = [
        "the", "to", "and", "you", "that", "love", "for", "with", "this", "have",
        "hey", "howdy", "stay", "quit", "private", "friend", "wait", "pill", "pile",
        "intense", "estranged", "walking", "walk", "don't", "then", "live", "cat",
        "hello", "how", "what", "sat",
    ]
}
