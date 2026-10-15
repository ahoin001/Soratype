/// Folds fresh key observations into the open draft and marks slips.
public struct GestureComposer: Sendable {
    public init() {}

    public func integrate(
        _ incoming: [Observation],
        draft: inout [Observation],
        chunks: inout [GestureChunk]
    ) {
        for var observation in incoming {
            if draft.contains(where: { existing in
                existing.letter == observation.letter
                    && existing.thumb != observation.thumb
                    && abs(existing.time - observation.time) <= GestureThresholds.slipMilliseconds
            }) {
                observation.kind = .slip
            }
            if observation.stroke != 0,
               let index = draft.lastIndex(where: { $0.stroke == observation.stroke && $0.letter == observation.letter && $0.thumb == observation.thumb }) {
                draft[index] = observation
                continue
            }
            let continuesStroke = observation.stroke != 0 && chunks.last?.isStroke == true && draft.last?.stroke == observation.stroke
            let start = draft.count
            draft.append(observation)
            if continuesStroke, var chunk = chunks.last {
                chunk.end = draft.count
                chunks[chunks.count - 1] = chunk
            } else {
                chunks.append(GestureChunk(start: start, end: draft.count, isStroke: observation.stroke != 0))
            }
        }
    }
}
