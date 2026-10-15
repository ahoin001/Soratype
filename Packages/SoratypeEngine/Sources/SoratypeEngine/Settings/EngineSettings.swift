/// Named locks from the typing brief. Each one has a replay test.
public struct EngineSettings: Sendable, Equatable, Codable {
    public var handoffGraceMilliseconds: Int
    public var handoffGraceEnabled: Bool
    public var backspaceMode: BackspaceMode
    public var queueBoundaryUntilLift: Bool
    public var doubleSpacePeriod: Bool

    public init(
        handoffGraceMilliseconds: Int = EngineSettings.defaultGraceMilliseconds,
        handoffGraceEnabled: Bool = true,
        backspaceMode: BackspaceMode = .removeWordAndSpace,
        queueBoundaryUntilLift: Bool = true,
        doubleSpacePeriod: Bool = true
    ) {
        self.handoffGraceMilliseconds = handoffGraceMilliseconds
        self.handoffGraceEnabled = handoffGraceEnabled
        self.backspaceMode = backspaceMode
        self.queueBoundaryUntilLift = queueBoundaryUntilLift
        self.doubleSpacePeriod = doubleSpacePeriod
    }

    public static let defaultGraceMilliseconds = 75
    public static let doubleSpaceWindowMilliseconds = 550

    public static let `default` = EngineSettings()
}
