/// Applies the session, the decoder, and the text effects. Touch order is the transaction.
public struct KeyboardEngine: Sendable {
    public var settings: EngineSettings
    public var field = Field()
    public private(set) var phase: WordPhase = .idle
    public private(set) var settleCount = 0
    public var decodesInline: Bool
    public var strip: Strip { assistant.strip }
    public var observations: [Observation] { draft }
    public var learning: LearningMemory { memory }

    private var layout: KeyboardLayout
    private var lexicon: any Lexicon
    private var memory: LearningMemory
    private var segmenter = GestureSegmenter()
    private var composer = GestureComposer()
    private var assistant = WordAssistant()
    private let costs = DecodeCosts.standard
    private var draft: [Observation] = []
    private var chunks: [GestureChunk] = []
    private var graceResult: DecodeResult?
    private var graceMerged = false
    private var fragmentCount = 0
    private var queued: [Boundary] = []
    private var effects: [EngineEffect] = []
    private var pendingRequest: DecodeRequest?
    private var pendingPurpose: PendingPurpose?
    private var lastCommit: CommitRecord?
    private var previousWord: String?
    private var lastSpaceTime: Int?
    private var now = 0
    private var shift = ShiftState.off
    private var lastShiftTap = 0
    private var verbatim = false
    private var repeatUnit: RepeatUnit?
    private var suppressLiftDelete = false
    private var scrubUndo: [Character] = []
    private let policy: HandOffPolicy

    public init(
        lexicon: any Lexicon,
        layout: KeyboardLayout,
        settings: EngineSettings = .default,
        memory: LearningMemory = .empty,
        decodesInline: Bool = true
    ) {
        self.lexicon = lexicon
        self.layout = layout
        self.settings = settings
        self.memory = memory
        self.decodesInline = decodesInline
        self.policy = HandOffPolicy(settings: settings)
        draft.reserveCapacity(32)
        effects.reserveCapacity(8)
    }

    public mutating func update(layout: KeyboardLayout) {
        self.layout = layout
    }

    public mutating func replaceLearning(_ memory: LearningMemory) {
        self.memory = memory
    }

    @discardableResult
    public mutating func handle(_ input: EngineInput) -> [EngineEffect] {
        effects.removeAll(keepingCapacity: true)
        switch input {
        case .touch(let sample):
            now = sample.time.milliseconds
            ingestTouch(sample)
        case .boundary(let boundary):
            ingestBoundary(boundary)
        case .tick(let time):
            now = time.milliseconds
            expireGrace()
        case .host(let event):
            ingestHost(event)
        case .promoteChip(let index):
            promote(index)
        case .acceptChip(let index):
            acceptChip(index)
        case .rejectChip(let index):
            rejectChip(index)
        case .suppressLiftDelete:
            suppressLiftDelete = true
        }
        return effects
    }

    public func takePendingDecode() -> DecodeRequest? {
        pendingRequest
    }

    @discardableResult
    public mutating func resolve(_ result: DecodeResult) -> [EngineEffect] {
        effects.removeAll(keepingCapacity: true)
        let purpose = pendingPurpose
        pendingRequest = nil
        pendingPurpose = nil
        switch purpose {
        case .preview:
            applyPreview(result)
        case .lift(let time):
            enterGrace(result, at: time)
            drainQueue()
        case .settle(let reason):
            commitSettled(result, reason: reason)
        case nil:
            break
        }
        return effects
    }

    public mutating func preview() -> [EngineEffect] {
        effects.removeAll(keepingCapacity: true)
        guard !draft.isEmpty else { return [] }
        if decodesInline {
            applyPreview(decode(draft))
        } else {
            schedule(draft, purpose: .preview)
        }
        return effects
    }

    private mutating func ingestTouch(_ sample: TouchSample) {
        if verbatim {
            ingestVerbatim(sample)
            return
        }
        switch sample.phase {
        case .down:
            guard let key = sample.key else { return }
            ingestDown(sample, key: key)
        case .move:
            ingestMove(sample)
        case .up:
            ingestUp(sample)
        case .cancel:
            ingestCancel(sample)
        }
    }

    private mutating func ingestDown(_ sample: TouchSample, key: PlacedKey) {
        repeatUnit = nil
        let startingFresh = phase == .idle && key.kind.isStrokeEligible
        if case .backspace = key.kind {
            scrubUndo.removeAll(keepingCapacity: true)
        }
        let published: [Observation]
        if key.kind.isStrokeEligible {
            resolveGrace(at: sample.time.milliseconds)
            let thumb = ThumbIdentity.thumb(at: sample.point, midline: layout.midline)
            let othersDown = segmenter.activeCount > 0
            published = segmenter.down(
                sample,
                key: key,
                thumb: thumb,
                shifted: shift != .off,
                otherThumbDown: othersDown
            )
        } else {
            published = segmenter.down(
                sample,
                key: key,
                thumb: .right,
                shifted: false,
                otherThumbDown: segmenter.activeCount > 0
            )
        }
        accept(published, decodeNow: true)
        if startingFresh, !decodesInline {
            emitStrip(assistant.beginDecision())
        }
    }

    private mutating func ingestMove(_ sample: TouchSample) {
        let others = segmenter.activeCount > 1
        let published = segmenter.move(sample, key: sample.key, otherThumbDown: others)
        accept(published, decodeNow: false)
    }

    private mutating func ingestUp(_ sample: TouchSample) {
        if let key = sample.key, case .letter = key.kind {
            let center = key.frame.center
            memory.noteBias(
                thumb: ThumbIdentity.thumb(at: sample.point, midline: layout.midline),
                dx: sample.point.x - center.x,
                dy: sample.point.y - center.y,
                limit: max(1, layout.keyWidth * 0.35)
            )
        }
        if let travel = segmenter.spaceTravel(for: sample.finger, at: sample.time.milliseconds) {
            _ = segmenter.up(sample, otherThumbDown: false)
            resolveSpaceGesture(travel)
            return
        }
        let others = segmenter.activeCount > 1
        let published = segmenter.up(sample, otherThumbDown: others)
        if let key = sample.key, !key.kind.isStrokeEligible, published.isEmpty {
            ingestNonLetterLift(key)
        }
        accept(published, decodeNow: true)
        if segmenter.activeCount == 0 {
            finishContact()
        }
    }

    private mutating func ingestCancel(_ sample: TouchSample) {
        let others = segmenter.activeCount > 1
        let published = segmenter.cancel(sample, otherThumbDown: others)
        if !published.isEmpty, published.allSatisfy({ $0.stroke == 0 }) {
            retract(published)
        } else {
            accept(published, decodeNow: true)
        }
        if segmenter.activeCount == 0 {
            finishContact()
        }
    }

    /// A cancelled finger that never traveled types nothing, including the letter shown at touch-down.
    private mutating func retract(_ published: [Observation]) {
        for observation in published {
            guard let index = draft.lastIndex(where: {
                $0.stroke == 0 && $0.thumb == observation.thumb && $0.time == observation.time
            }) else { continue }
            removeDraft(at: index)
        }
        if draft.isEmpty {
            chunks.removeAll(keepingCapacity: true)
            closeComposing()
            graceResult = nil
            if segmenter.activeCount == 0 {
                phase = .idle
            }
        } else {
            refreshComposing(allowDecode: true)
        }
    }

    private mutating func removeDraft(at index: Int) {
        draft.remove(at: index)
        var rebuilt: [GestureChunk] = []
        rebuilt.reserveCapacity(chunks.count)
        for var chunk in chunks {
            if index >= chunk.end {
                rebuilt.append(chunk)
            } else if index < chunk.start {
                chunk.start -= 1
                chunk.end -= 1
                rebuilt.append(chunk)
            } else {
                chunk.end -= 1
                if chunk.end > chunk.start {
                    rebuilt.append(chunk)
                }
            }
        }
        chunks = rebuilt
    }

    private mutating func ingestNonLetterLift(_ key: PlacedKey) {
        switch key.kind {
        case .backspace:
            if suppressLiftDelete {
                suppressLiftDelete = false
                return
            }
            ingestBoundary(.backspace)
        case .return:
            ingestBoundary(.return)
        case .shift:
            toggleShift()
        case .symbols:
            effects.append(.page(.numbers))
        case .letters:
            effects.append(.page(.letters))
        case .digit(let character), .punctuation(let character):
            ingestBoundary(.punctuation(character))
        case .letter, .space, .nextKeyboard:
            break
        }
    }

    private mutating func resolveSpaceGesture(_ travel: (distance: Double, dx: Double, dy: Double, held: Int)) {
        let horizontal = abs(travel.dx) > abs(travel.dy)
        if travel.distance >= GestureThresholds.spaceTravel, horizontal {
            _ = settleOpenWord(.caret)
            let delta = Int((travel.dx / max(layout.keyWidth, 1)).rounded())
            let moved = delta == 0 ? (travel.dx > 0 ? 1 : -1) : delta
            field.moveCaret(to: field.caret + moved)
            retireNextMove()
            return
        }
        if travel.distance >= GestureThresholds.spaceTravel, travel.dy > 0, abs(travel.dy) > abs(travel.dx) {
            _ = settleOpenWord(.space)
            effects.append(.page(.punctuation))
            return
        }
        if travel.distance >= GestureThresholds.spaceTravel, travel.dy < 0, abs(travel.dy) > abs(travel.dx) {
            ingestBoundary(.liftWord)
            return
        }
        ingestBoundary(.space)
    }

    private mutating func accept(_ published: [Observation], decodeNow: Bool) {
        guard !published.isEmpty else { return }
        if phase == .idle { phase = .contact }
        var adjusted = published
        for index in adjusted.indices {
            let bias = memory.bias(for: adjusted[index].thumb)
            adjusted[index].x -= bias.dx
            adjusted[index].y -= bias.dy
        }
        composer.integrate(adjusted, draft: &draft, chunks: &chunks)
        if phase == .contact, draft.contains(where: { $0.stroke != 0 }) {
            phase = .swipeOpen
        }
        if shift == .once {
            shift = .off
            effects.append(.shift(.off))
        }
        guard decodeNow else { return }
        refreshComposing(allowDecode: true)
    }

    private mutating func refreshComposing(allowDecode: Bool) {
        guard !draft.isEmpty else { return }
        let hasStroke = draft.contains { $0.stroke != 0 }
        if hasStroke, allowDecode {
            if decodesInline {
                applyPreview(decode(draft))
            } else {
                schedule(draft, purpose: .preview)
                showComposing(AimedSpelling.text(from: draft))
            }
        } else {
            showComposing(AimedSpelling.text(from: draft))
            if allowDecode, decodesInline {
                let result = decode(draft)
                if splitJoinedDraft(using: result) { return }
                presentPreview(result, at: now)
            }
        }
    }

    private mutating func finishContact() {
        switch phase {
        case .swipeOpen:
            if settings.handoffGraceEnabled {
                if decodesInline {
                    enterGrace(decode(draft), at: now)
                } else {
                    showComposing(AimedSpelling.text(from: draft))
                    schedule(draft, purpose: .lift(now))
                    return
                }
            } else if decodesInline {
                commitSwipe(decode(draft))
            } else {
                schedule(draft, purpose: .lift(now))
                return
            }
        case .contact:
            phase = .tapOpen
            refreshComposing(allowDecode: true)
        case .tapOpen:
            refreshComposing(allowDecode: true)
        case .grace, .idle:
            break
        }
        drainQueue()
    }

    private mutating func resolveGrace(at time: Int) {
        guard case .grace(let deadline) = phase else { return }
        if time <= deadline, let graceResult, policy.isWeak(graceResult, lexicon: lexicon) {
            phase = .swipeOpen
            graceMerged = true
            fragmentCount = draft.count
            return
        }
        commitSwipe(graceResult ?? decode(draft))
    }

    private mutating func expireGrace() {
        guard case .grace(let deadline) = phase, now >= deadline, segmenter.activeCount == 0 else { return }
        commitSwipe(graceResult ?? decode(draft))
        drainQueue()
    }

    private mutating func enterGrace(_ result: DecodeResult, at time: Int) {
        if !settings.handoffGraceEnabled {
            commitSwipe(result)
            return
        }
        graceResult = result
        phase = .grace(deadline: time + settings.handoffGraceMilliseconds)
        showComposing(displayWord(result))
        presentPreview(result, at: time)
    }

    private mutating func ingestBoundary(_ boundary: Boundary) {
        let repeating = repeatUnit
        if case .backspace = boundary {
        } else {
            repeatUnit = nil
        }
        if settings.queueBoundaryUntilLift, segmenter.activeCount > 0 {
            switch boundary {
            case .space, .backspace:
                queued.append(boundary)
                return
            default:
                break
            }
        }
        apply(boundary, repeating: repeating)
    }

    private mutating func drainQueue() {
        let pending = queued
        queued.removeAll(keepingCapacity: true)
        for boundary in pending {
            apply(boundary, repeating: nil)
        }
    }

    private mutating func apply(_ boundary: Boundary, repeating: RepeatUnit?) {
        switch boundary {
        case .space:
            handleSpace()
        case .backspace:
            handleBackspace(repeating: repeating)
        case .return:
            _ = settleOpenWord(.return)
            field.insert("\n")
            effects.append(.insert("\n"))
            lastCommit = nil
        case .punctuation(let character):
            handlePunctuation(character)
        case .emoji(let text):
            _ = settleOpenWord(.emoji)
            field.insert(text)
            effects.append(.insert(text))
            lastCommit = nil
        case .caret(let delta):
            _ = settleOpenWord(.caret)
            field.moveCaret(to: field.caret + delta)
            lastCommit = nil
        case .liftWord:
            liftWord()
        case .scrub(let steps):
            scrub(steps)
        }
    }

    private mutating func handleSpace() {
        if phase != .idle {
            _ = settleOpenWord(.space)
            return
        }
        let onCommittedSpace = lastCommit?.trailingSpace == true && lastCommit?.caret == field.caret
        if onCommittedSpace,
           settings.doubleSpacePeriod,
           let lastSpaceTime,
           now - lastSpaceTime <= EngineSettings.doubleSpaceWindowMilliseconds {
            makePeriod()
            return
        }
        field.insert(" ")
        effects.append(.insert(" "))
        lastSpaceTime = now
        retireNextMove()
    }

    private mutating func makePeriod() {
        guard field.text.hasSuffix(" ") else { return }
        field.deleteBackward(1)
        field.insert(". ")
        effects.append(.replaceTail(delete: 1, insert: ". "))
        lastCommit = CommitRecord(
            kind: .period, word: ".", aimed: ".", typed: " ",
            trailingSpace: true, alternatives: [], stem: nil, suffix: nil,
            caret: field.caret, observations: []
        )
        lastSpaceTime = nil
    }

    private mutating func handlePunctuation(_ character: Character) {
        _ = settleOpenWord(.punctuation)
        let sentence = character == "." || character == "!" || character == "?"
        let insertion = sentence ? "\(character) " : String(character)
        if field.text.hasSuffix(" ") {
            field.deleteBackward(1)
            field.insert(insertion)
            effects.append(.replaceTail(delete: 1, insert: insertion))
        } else {
            field.insert(insertion)
            effects.append(.insert(insertion))
        }
        lastCommit = nil
    }

    @discardableResult
    private mutating func settleOpenWord(_ reason: SettleReason) -> Bool {
        switch phase {
        case .idle:
            return false
        case .grace:
            commitSwipe(graceResult ?? decode(draft))
            return true
        case .swipeOpen:
            if decodesInline {
                commitSwipe(decode(draft))
            } else {
                schedule(draft, purpose: .settle(reason))
            }
            return true
        case .contact, .tapOpen:
            if decodesInline {
                commitSettled(decode(draft), reason: reason)
            } else {
                schedule(draft, purpose: .settle(reason))
            }
            return true
        }
    }

    private mutating func commitSettled(_ result: DecodeResult, reason: SettleReason) {
        if splitJoinedDraft(using: result) {
            if !draft.isEmpty, reason == .space || reason == .return {
                commitSwipe(decode(draft))
            }
            return
        }
        let typed = AimedSpelling.text(from: draft)
        if let suffix = InflectionJoiner.suffix(in: typed),
           let stem = lastCommit?.word,
           lastCommit?.kind == .swipe,
           let joined = InflectionJoiner.joined(stem: stem, suffix: suffix, lexicon: lexicon),
           reason == .space || reason == .punctuation {
            join(stem: stem, suffix: suffix, word: joined, observations: draft)
            return
        }
        let autocorrect = reason == .space || reason == .return
        let chosen = autocorrect ? displayWord(result) : (typed.isEmpty ? displayWord(result) : typed)
        let word = chosen.isEmpty ? typed : chosen
        guard !word.isEmpty else {
            phase = .idle
            draft.removeAll(keepingCapacity: true)
            chunks.removeAll(keepingCapacity: true)
            return
        }
        let kind: CommitRecord.Kind = word.lowercased() == typed.lowercased() ? .tap : .autocorrect
        let trailing = reason == .space
        write(word, trailingSpace: trailing, kind: kind, aimed: result.aimed.isEmpty ? typed : result.aimed, typed: typed, result: result, observations: draft)
    }

    private mutating func commitSwipe(_ result: DecodeResult) {
        if graceMerged {
            let joined = displayWord(result)
            if !lexicon.contains(joined.lowercased()), fragmentCount > 0, fragmentCount < draft.count {
                let fragment = Array(draft.prefix(fragmentCount))
                let rest = Array(draft.dropFirst(fragmentCount))
                let fragmentResult = graceResult ?? decode(fragment)
                graceMerged = false
                write(
                    displayWord(fragmentResult),
                    trailingSpace: true,
                    kind: .swipe,
                    aimed: fragmentResult.aimed,
                    typed: fragmentResult.aimed,
                    result: fragmentResult,
                    observations: fragment
                )
                phase = .tapOpen
                draft = rest
                chunks = [GestureChunk(start: 0, end: rest.count, isStroke: rest.contains { $0.stroke != 0 })]
                showComposing(AimedSpelling.text(from: rest))
                return
            }
        }
        let word = displayWord(result)
        guard !word.isEmpty else {
            phase = .idle
            return
        }
        write(word, trailingSpace: true, kind: .swipe, aimed: result.aimed, typed: result.aimed, result: result, observations: draft)
    }

    private mutating func write(
        _ word: String,
        trailingSpace: Bool,
        kind: CommitRecord.Kind,
        aimed: String,
        typed: String,
        result: DecodeResult,
        observations: [Observation],
        stem: String? = nil,
        suffix: String? = nil
    ) {
        let prior = previousWord
        let written = trailingSpace ? word + " " : word
        if field.marked != nil {
            field.commitComposing(written)
            effects.append(.commit(written))
        } else {
            field.insert(written)
            effects.append(.insert(written))
        }
        lastCommit = CommitRecord(
            kind: kind,
            word: word,
            aimed: aimed,
            typed: typed,
            trailingSpace: trailingSpace,
            alternatives: result.readings.map(\.text),
            stem: stem,
            suffix: suffix,
            caret: field.caret,
            observations: observations
        )
        previousWord = word
        if trailingSpace { lastSpaceTime = now }
        phase = .idle
        graceResult = nil
        graceMerged = false
        fragmentCount = 0
        draft.removeAll(keepingCapacity: true)
        chunks.removeAll(keepingCapacity: true)
        assistant.pinned = nil
        memory.noteAccept(word, previous: prior, now: now, observations: observations)
        presentLanded(result, committed: word)
        settleCount += 1
    }

    private mutating func join(stem: String, suffix: String, word: String, observations: [Observation]) {
        let prior = previousWord
        let composingCount = field.composing.count
        let hasSpace = field.marked.map { $0.lowerBound > 0 && String(field.text.prefix($0.lowerBound)).hasSuffix(" ") } ?? false
        let deleteCount = composingCount + (hasSpace ? 1 : 0)
        let start = max(0, field.caret - deleteCount)
        field.replace(from: start, through: field.caret, with: suffix + " ")
        effects.append(.replaceTail(delete: deleteCount, insert: suffix + " "))
        let result = DecodeResult(readings: [Reading(text: word, score: 0, aimed: false)], aimed: stem, unsure: false, budgetExhausted: false)
        lastCommit = CommitRecord(
            kind: .suffix, word: word, aimed: stem + suffix, typed: suffix,
            trailingSpace: true, alternatives: [word, stem], stem: stem, suffix: suffix,
            caret: field.caret, observations: observations
        )
        previousWord = word
        lastSpaceTime = now
        phase = .idle
        draft.removeAll(keepingCapacity: true)
        chunks.removeAll(keepingCapacity: true)
        graceResult = nil
        memory.noteAccept(word, previous: prior, now: now, observations: observations)
        presentLanded(result, committed: word)
        settleCount += 1
    }

    private mutating func handleBackspace(repeating: RepeatUnit?) {
        if let repeating {
            switch repeating {
            case .word:
                deletePreviousWord()
            case .character:
                deleteCharacters(1)
            }
            return
        }
        if phase != .idle {
            backspaceOpenWord()
            return
        }
        guard let commit = lastCommit, commit.caret == field.caret, field.marked == nil else {
            deleteCharacters(1)
            repeatUnit = .character
            return
        }
        switch commit.kind {
        case .swipe, .strip:
            if settings.backspaceMode == .reopenAimedLetters, commit.aimed.lowercased() != commit.word.lowercased() {
                reopen(commit.aimed, deleting: commit.word.count + (commit.trailingSpace ? 1 : 0))
                repeatUnit = .word
            } else {
                let removed = commit
                let count = commit.word.count + (commit.trailingSpace ? 1 : 0)
                deleteCharacters(count)
                memory.noteSwipeRemoval(
                    word: commit.word,
                    aimed: commit.aimed,
                    now: now,
                    observations: commit.observations
                )
                previousWord = nil
                lastCommit = nil
                repeatUnit = .word
                emitStrip(assistant.undoOffer(undoWords(from: removed)))
            }
        case .autocorrect:
            let count = commit.word.count + (commit.trailingSpace ? 1 : 0)
            deleteCharacters(count)
            reopenIntoDecision(commit.typed)
            repeatUnit = .character
        case .tap:
            let count = commit.word.count + (commit.trailingSpace ? 1 : 0)
            deleteCharacters(max(count, 1))
            reopenIntoDecision(commit.word, observations: commit.observations)
            repeatUnit = .character
        case .suffix:
            undoSuffix(commit)
            repeatUnit = .character
        case .period:
            guard field.text.hasSuffix(". ") else {
                deleteCharacters(1)
                return
            }
            field.deleteBackward(2)
            field.insert("  ")
            effects.append(.replaceTail(delete: 2, insert: "  "))
            lastCommit = nil
            repeatUnit = .character
        }
    }

    private mutating func backspaceOpenWord() {
        guard !draft.isEmpty else {
            closeComposing()
            phase = .idle
            return
        }
        if let chunk = chunks.last, chunk.isStroke, chunks.count > 1 {
            draft.removeSubrange(chunk.start..<chunk.end)
            chunks.removeLast()
            refreshComposing(allowDecode: true)
            return
        }
        if let chunk = chunks.last, !chunk.isStroke, chunk.end > chunk.start {
            draft.removeLast()
            if chunk.end - chunk.start == 1 {
                chunks.removeLast()
            } else if var last = chunks.last {
                last.end -= 1
                chunks[chunks.count - 1] = last
            }
            if draft.isEmpty {
                closeComposing()
                phase = .idle
            } else {
                refreshComposing(allowDecode: true)
            }
            return
        }
        draft.removeAll(keepingCapacity: true)
        chunks.removeAll(keepingCapacity: true)
        closeComposing()
        phase = .idle
        graceResult = nil
    }

    private mutating func undoSuffix(_ commit: CommitRecord) {
        let stem = commit.stem ?? commit.word
        let suffix = commit.suffix ?? ""
        let deleteCount = commit.word.count + (commit.trailingSpace ? 1 : 0)
        field.deleteBackward(deleteCount)
        field.insert(stem)
        effects.append(.replaceTail(delete: deleteCount, insert: stem))
        let stemCaret = field.caret
        restoreComposing(suffix)
        lastCommit = CommitRecord(
            kind: .swipe, word: stem, aimed: stem, typed: stem,
            trailingSpace: false, alternatives: [], stem: nil, suffix: nil,
            caret: stemCaret, observations: []
        )
    }

    private mutating func reopen(_ aimed: String, deleting count: Int) {
        deleteCharacters(count)
        reopenIntoDecision(aimed)
    }

    private mutating func reopenIntoDecision(_ text: String, observations: [Observation] = []) {
        restoreComposing(text, observations: observations)
        previewRestoredWord()
    }

    private mutating func previewRestoredWord() {
        guard !draft.isEmpty else { return }
        if decodesInline {
            presentPreview(decode(draft), at: now)
        } else {
            schedule(draft, purpose: .preview)
            emitStrip(assistant.beginDecision())
        }
    }

    private mutating func retireNextMove() {
        lastCommit = nil
        assistant.reset()
        effects.append(.strip(.empty))
    }

    private mutating func restoreComposing(_ text: String, observations: [Observation] = []) {
        lastCommit = nil
        phase = .tapOpen
        draft = observations
        chunks = observations.isEmpty ? [] : [GestureChunk(start: 0, end: observations.count, isStroke: false)]
        showComposing(text)
        if observations.isEmpty {
            draft = text.lowercased().utf8.map { byte in
                Observation(
                    letter: byte, shifted: false, kind: .tap, thumb: .right, time: now,
                    x: 0, y: 0, keyX: 0, keyY: 0, keyWidth: layout.keyWidth, keyHeight: layout.keyHeight,
                    centered: true, stroke: 0, otherThumbDown: false
                )
            }
            chunks = [GestureChunk(start: 0, end: draft.count, isStroke: false)]
        }
    }

    private mutating func deleteCharacters(_ count: Int) {
        guard count > 0 else { return }
        field.deleteBackward(count)
        effects.append(.deleteBackward(count))
    }

    private mutating func deletePreviousWord() {
        if field.marked != nil {
            let count = field.composing.count
            closeComposing()
            phase = .idle
            draft.removeAll(keepingCapacity: true)
            chunks.removeAll(keepingCapacity: true)
            if count > 0 {
                effects.append(.deleteBackward(count))
            }
            return
        }
        var count = 0
        var caret = field.caret
        let characters = Array(field.text)
        while caret > 0, characters[caret - 1] == " " {
            caret -= 1
            count += 1
        }
        while caret > 0, characters[caret - 1] != " ", characters[caret - 1] != "\n" {
            caret -= 1
            count += 1
        }
        deleteCharacters(count)
        lastCommit = nil
    }

    private mutating func liftWord() {
        _ = settleOpenWord(.liftWord)
        guard field.text.hasSuffix(" "), let commit = lastCommit, commit.trailingSpace else { return }
        deleteCharacters(1)
        reopenIntoDecision(commit.word, observations: commit.observations)
    }

    private mutating func promote(_ index: Int) {
        guard let text = assistant.promote(index) else { return }
        if phase != .idle {
            showComposing(text)
        }
        let current = assistant.strip
        emitStrip(current)
    }

    private mutating func rejectChip(_ index: Int) {
        guard let text = assistant.remove(index) else { return }
        memory.noteReject(text)
        emitStrip(assistant.strip)
    }

    private mutating func scrub(_ steps: Int) {
        guard steps != 0 else { return }
        if steps < 0 {
            if lastCommit != nil {
                retireNextMove()
            }
            for _ in 0..<(-steps) {
                guard field.caret > 0, let character = field.text.prefix(field.caret).last else { break }
                scrubUndo.append(character)
                deleteCharacters(1)
            }
        } else {
            for _ in 0..<steps {
                guard let character = scrubUndo.popLast() else { break }
                field.insert(String(character))
                effects.append(.insert(String(character)))
            }
        }
    }

    private mutating func acceptChip(_ index: Int) {
        guard assistant.strip.chips.indices.contains(index) else { return }
        let chip = assistant.strip.chips[index]
        switch chip.role {
        case .context:
            return
        case .follower:
            insertFollower(chip.text)
        case .suffix:
            guard let stem = lastCommit?.word,
                  let suffix = InflectionJoiner.suffix(in: chip.text) ?? Optional(chip.text),
                  let joined = InflectionJoiner.joined(stem: stem, suffix: suffix, lexicon: lexicon)
            else { return }
            let deleteCount = stem.count + ((lastCommit?.trailingSpace ?? false) ? 1 : 0)
            field.deleteBackward(deleteCount)
            field.insert(joined + " ")
            effects.append(.replaceTail(delete: deleteCount, insert: joined + " "))
            lastCommit = CommitRecord(
                kind: .suffix, word: joined, aimed: stem, typed: suffix,
                trailingSpace: true, alternatives: [joined], stem: stem, suffix: suffix,
                caret: field.caret, observations: []
            )
            previousWord = joined
            memory.noteAccept(joined, previous: nil, now: now)
            settleCount += 1
            let result = DecodeResult(
                readings: [Reading(text: joined, score: 0, aimed: false)],
                aimed: joined,
                unsure: false,
                budgetExhausted: false
            )
            presentLanded(result, committed: joined)
        case .leader, .alternative, .aimed:
            guard let commit = lastCommit else {
                insertWord(chip.text, previous: nil)
                return
            }
            let replacement = chip.text
            let deleteCount = commit.word.count + (commit.trailingSpace ? 1 : 0)
            field.deleteBackward(deleteCount)
            field.insert(replacement + " ")
            effects.append(.replaceTail(delete: deleteCount, insert: replacement + " "))
            memory.noteChoice(word: replacement, aimed: commit.aimed, observations: commit.observations)
            memory.noteAccept(replacement, previous: nil, now: now, observations: commit.observations)
            lastCommit = CommitRecord(
                kind: .strip, word: replacement, aimed: commit.aimed, typed: commit.typed,
                trailingSpace: true, alternatives: commit.alternatives, stem: nil, suffix: nil,
                caret: field.caret, observations: commit.observations
            )
            previousWord = replacement
            let result = DecodeResult(
                readings: [Reading(text: replacement, score: 0, aimed: replacement.lowercased() == commit.aimed.lowercased())],
                aimed: commit.aimed,
                unsure: false,
                budgetExhausted: false
            )
            presentLanded(result, committed: replacement)
        }
    }

    private mutating func insertFollower(_ word: String) {
        insertWord(word, previous: previousWord)
    }

    private mutating func insertWord(_ word: String, previous: String?) {
        field.insert(word + " ")
        effects.append(.insert(word + " "))
        let result = DecodeResult(
            readings: [Reading(text: word, score: 0, aimed: true)],
            aimed: word,
            unsure: false,
            budgetExhausted: false
        )
        lastCommit = CommitRecord(
            kind: .strip, word: word, aimed: word, typed: word,
            trailingSpace: true, alternatives: [word], stem: nil, suffix: nil,
            caret: field.caret, observations: []
        )
        previousWord = word
        lastSpaceTime = now
        phase = .idle
        memory.noteAccept(word, previous: previous, now: now)
        presentLanded(result, committed: word)
        settleCount += 1
    }

    private mutating func presentPreview(_ result: DecodeResult, at time: Int) {
        let shown = readable(result)
        let leader = shown.readings.first?.text ?? ""
        emitStrip(assistant.preview(shown, now: time, costs: costs, extras: tailCandidates(for: leader)))
    }

    private mutating func presentLanded(_ result: DecodeResult, committed: String) {
        emitStrip(assistant.landed(committed: committed, extras: suggestionExtras(around: committed, result: result)))
    }

    private func readable(_ result: DecodeResult) -> DecodeResult {
        let readings = result.readings.filter { isSuggestion($0.text) }
        return DecodeResult(
            readings: readings,
            aimed: result.aimed,
            unsure: result.unsure,
            budgetExhausted: result.budgetExhausted
        )
    }

    private func suggestionExtras(around committed: String, result: DecodeResult) -> [Chip] {
        let shown = result.readings.filter { isSuggestion($0.text) }
        let top = shown.first?.score ?? 0
        var chips: [Chip] = []
        for reading in shown {
            if reading.text.lowercased() == committed.lowercased() { continue }
            if top - reading.score > 4 { continue }
            let role: ChipRole = reading.aimed ? .aimed : .alternative
            chips.append(Chip(text: reading.text, role: role))
        }
        chips.append(contentsOf: tailCandidates(for: committed))
        return chips
    }

    private func tailCandidates(for word: String) -> [Chip] {
        guard !word.isEmpty else { return [] }
        var chips: [Chip] = []
        if let suffix = suffixChip(for: word) {
            chips.append(Chip(text: suffix, role: .suffix))
        }
        var seen = Set<String>()
        for follower in followerList(of: word) {
            let key = follower.lowercased()
            guard seen.insert(key).inserted, isSuggestion(follower), key != word.lowercased() else { continue }
            chips.append(Chip(text: follower, role: .follower))
        }
        return chips
    }

    private func followerList(of word: String) -> [String] {
        var list: [String] = []
        if let learned = memory.follower(of: word) {
            list.append(learned)
        }
        list.append(contentsOf: lexicon.followers(of: word.lowercased()))
        return list
    }

    private func isSuggestion(_ word: String) -> Bool {
        let key = word.lowercased()
        guard !key.isEmpty, !memory.blocklist.contains(key), !memory.shouldFade(key) else { return false }
        if lexicon.contains(key) { return true }
        return (memory.personal[key] ?? 0) >= 2
    }

    private func undoWords(from commit: CommitRecord) -> [String] {
        var words = [commit.word]
        for alternative in commit.alternatives where isSuggestion(alternative) {
            words.append(alternative)
        }
        return words
    }

    private mutating func ingestHost(_ event: HostEvent) {
        switch event {
        case .dismiss:
            _ = settleOpenWord(.dismissal)
        case .focusLoss:
            _ = settleOpenWord(.focusLoss)
        case .textChanged(let text, let caret):
            phase = .idle
            draft.removeAll(keepingCapacity: true)
            chunks.removeAll(keepingCapacity: true)
            graceResult = nil
            queued.removeAll(keepingCapacity: true)
            lastCommit = nil
            field = Field(text: text, caret: caret)
            assistant.reset()
        case .verbatim(let enabled):
            verbatim = enabled
            if enabled {
                phase = .idle
                draft.removeAll(keepingCapacity: true)
            }
        }
    }

    private mutating func ingestVerbatim(_ sample: TouchSample) {
        switch sample.phase {
        case .down:
            guard let key = sample.key else { return }
            let thumb = ThumbIdentity.thumb(at: sample.point, midline: layout.midline)
            _ = segmenter.down(
                sample,
                key: key,
                thumb: thumb,
                shifted: shift != .off,
                otherThumbDown: false
            )
        case .move:
            _ = segmenter.move(sample, key: sample.key, otherThumbDown: false)
        case .up, .cancel:
            let key = sample.key ?? segmenter.landingKey(for: sample.finger)
            if sample.phase == .cancel {
                _ = segmenter.cancel(sample, otherThumbDown: false)
            } else {
                _ = segmenter.up(sample, otherThumbDown: false)
            }
            guard sample.phase == .up, let key else { return }
            insertVerbatim(key)
        }
    }

    private mutating func insertVerbatim(_ key: PlacedKey) {
        switch key.kind {
        case .letter(let character):
            let text = shift == .off ? String(character) : String(character).uppercased()
            field.insert(text)
            effects.append(.insert(text))
            if shift == .once {
                shift = .off
                effects.append(.shift(.off))
            }
        case .digit(let character), .punctuation(let character):
            field.insert(String(character))
            effects.append(.insert(String(character)))
        case .space:
            field.insert(" ")
            effects.append(.insert(" "))
        case .backspace:
            deleteCharacters(1)
        case .return:
            field.insert("\n")
            effects.append(.insert("\n"))
        case .shift:
            toggleShift()
        case .symbols:
            effects.append(.page(.numbers))
        case .letters:
            effects.append(.page(.letters))
        case .nextKeyboard:
            break
        }
    }

    private mutating func toggleShift() {
        switch shift {
        case .off:
            shift = .once
        case .once:
            shift = now - lastShiftTap < 350 ? .locked : .off
        case .locked:
            shift = .off
        }
        lastShiftTap = now
        effects.append(.shift(shift))
    }

    private mutating func applyPreview(_ result: DecodeResult) {
        if splitJoinedDraft(using: result) { return }
        let word = displayWord(result)
        if draft.contains(where: { $0.stroke != 0 }) {
            showComposing(word)
        }
        presentPreview(result, at: now)
    }

    private func displayWord(_ result: DecodeResult) -> String {
        if let pinned = assistant.pinned { return pinned }
        if let top = result.top, !top.isEmpty { return top }
        return result.aimed
    }

    private mutating func splitJoinedDraft(using result: DecodeResult) -> Bool {
        guard phase == .tapOpen, segmenter.activeCount == 0 else { return false }
        guard let cut = draft.firstIndex(where: { $0.stroke != 0 }), cut > 0 else { return false }
        let joined = displayWord(result).lowercased()
        let score = result.readings.first?.score ?? costs.weakScore
        let weak = !lexicon.contains(joined) || score <= costs.weakScore
        guard weak else { return false }
        let prefix = Array(draft.prefix(cut))
        let rest = Array(draft.suffix(from: cut))
        let prefixResult = decode(prefix)
        let restResult = decode(rest)
        let prefixWord = displayWord(prefixResult)
        let restWord = displayWord(restResult)
        guard lexicon.contains(prefixWord.lowercased()), lexicon.contains(restWord.lowercased()) else { return false }
        write(
            prefixWord,
            trailingSpace: true,
            kind: .tap,
            aimed: prefixResult.aimed,
            typed: AimedSpelling.text(from: prefix),
            result: prefixResult,
            observations: prefix
        )
        let committed = lastCommit
        restoreComposing(restWord, observations: rest)
        lastCommit = committed
        phase = .swipeOpen
        if !chunks.isEmpty {
            chunks[0] = GestureChunk(start: 0, end: draft.count, isStroke: true)
        }
        return true
    }

    private mutating func emitStrip(_ strip: Strip) {
        var shown = strip
        if !shown.preview {
            for chip in shown.chips where chip.role != .context {
                memory.noteImpression(chip.text)
            }
        }
        if let highlighted = shown.highlighted, !shown.chips.indices.contains(highlighted) {
            shown.highlighted = shown.preview
                ? shown.chips.firstIndex { $0.role == .leader }
                : shown.chips.firstIndex { $0.role == .follower }
        }
        effects.append(.strip(shown))
    }

    private func suffixChip(for word: String) -> String? {
        InflectionJoiner.suffixes.first { suffix in
            lexicon.contains(word.lowercased() + suffix)
        }
    }

    private mutating func showComposing(_ text: String) {
        field.setComposing(text)
        effects.append(.setMarked(text))
    }

    private mutating func closeComposing() {
        let count = field.composing.count
        field.setComposing("")
        if count > 0 {
            effects.append(.setMarked(""))
        }
    }

    private func decode(_ observations: [Observation]) -> DecodeResult {
        AlignmentPathMatcher.match(makeRequest(observations))
    }

    private mutating func schedule(_ observations: [Observation], purpose: PendingPurpose) {
        pendingRequest = makeRequest(observations)
        pendingPurpose = purpose
    }

    private func makeRequest(_ observations: [Observation]) -> DecodeRequest {
        DecodeRequest(
            observations: observations,
            centers: layout.centers,
            costs: costs,
            learning: memory.snapshot(previousWord: previousWord, now: now, observations: observations),
            lexicon: lexicon,
            previousWord: previousWord,
            budgetMilliseconds: costs.budgetMilliseconds
        )
    }
}
