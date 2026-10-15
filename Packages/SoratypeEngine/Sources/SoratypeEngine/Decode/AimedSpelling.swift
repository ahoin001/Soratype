public enum AimedSpelling {
    public static func observations(_ observations: [Observation]) -> [Observation] {
        observations.filter(\.countsInAimedSpelling).sorted { $0.time < $1.time }
    }

    public static func text(from observations: [Observation]) -> String {
        let kept = self.observations(observations)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(kept.count)
        var shifts: UInt64 = 0
        for observation in kept {
            if observation.shifted, bytes.count < 64 {
                shifts |= UInt64(1) << bytes.count
            }
            bytes.append(observation.letter)
        }
        return LetterByte.spelling(bytes, shifts: shifts)
    }
}
