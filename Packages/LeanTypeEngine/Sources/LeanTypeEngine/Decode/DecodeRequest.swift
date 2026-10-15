public struct LearningSnapshot: Sendable, Equatable {
    public var habits: [String: Double]
    public var pairs: [String: Double]
    public var blocked: Set<String>
    public var rejections: [String: String]
    public var prototypes: [String: Double]
    public var personal: [String: Int]

    public init(
        habits: [String: Double] = [:],
        pairs: [String: Double] = [:],
        blocked: Set<String> = [],
        rejections: [String: String] = [:],
        prototypes: [String: Double] = [:],
        personal: [String: Int] = [:]
    ) {
        self.habits = habits
        self.pairs = pairs
        self.blocked = blocked
        self.rejections = rejections
        self.prototypes = prototypes
        self.personal = personal
    }

    public static let empty = LearningSnapshot()
}

public struct DecodeRequest: Sendable {
    public var observations: [Observation]
    public var centers: KeyCenters
    public var costs: DecodeCosts
    public var learning: LearningSnapshot
    public var lexicon: any Lexicon
    public var previousWord: String?
    public var budgetMilliseconds: Int

    public init(
        observations: [Observation],
        centers: KeyCenters,
        costs: DecodeCosts = .standard,
        learning: LearningSnapshot = .empty,
        lexicon: any Lexicon,
        previousWord: String? = nil,
        budgetMilliseconds: Int = 12
    ) {
        self.observations = observations
        self.centers = centers
        self.costs = costs
        self.learning = learning
        self.lexicon = lexicon
        self.previousWord = previousWord
        self.budgetMilliseconds = budgetMilliseconds
    }
}
