public struct DecodeCosts: Sendable, Equatable {
    public var sigmaXInKeyWidths: Double
    public var sigmaYInKeyHeights: Double
    public var doubleLetter: Double
    public var skipAnchor: Double
    public var skipCenteredCrossing: Double
    public var skipGraze: Double
    /// The most a word pays for ignoring pass-through keys, however many there are.
    public var crossingSkipCap: Double
    public var skipRest: Double
    public var skipSlip: Double
    public var skipBudgetPerThumb: Int
    public var frequencyWeight: Double
    public var habitCap: Double
    public var pairBonus: Double
    public var weakScore: Double
    public var unsureMargin: Double
    public var aimedMargin: Double
    public var crossCostCap: Double
    public var crossCostPerSecond: Double
    public var beamWidths: [Int]
    public var budgetMilliseconds: Int
    public var previewIntervalMilliseconds: Int
    public var stickyLeaderMilliseconds: Int
    public var swapCost: Double
    public var omissionCost: Double
    public var apostropheCost: Double
    public var neighborCost: Double

    public init(
        sigmaXInKeyWidths: Double = 0.55,
        sigmaYInKeyHeights: Double = 0.40,
        doubleLetter: Double = 0.25,
        skipAnchor: Double = 3.2,
        skipCenteredCrossing: Double = 0.4,
        skipGraze: Double = 0.35,
        crossingSkipCap: Double = 1.0,
        skipRest: Double = 0.2,
        skipSlip: Double = 0.05,
        skipBudgetPerThumb: Int = 2,
        frequencyWeight: Double = 0.22,
        habitCap: Double = 0.45,
        pairBonus: Double = 0.45,
        weakScore: Double = -6,
        unsureMargin: Double = 0.35,
        aimedMargin: Double = 1.0,
        crossCostCap: Double = 1.6,
        crossCostPerSecond: Double = 2.4,
        beamWidths: [Int] = [4, 12, 28],
        budgetMilliseconds: Int = 12,
        previewIntervalMilliseconds: Int = 32,
        stickyLeaderMilliseconds: Int = 80,
        swapCost: Double = 0.9,
        omissionCost: Double = 1.0,
        apostropheCost: Double = 0.55,
        neighborCost: Double = 1.2
    ) {
        self.sigmaXInKeyWidths = sigmaXInKeyWidths
        self.sigmaYInKeyHeights = sigmaYInKeyHeights
        self.doubleLetter = doubleLetter
        self.skipAnchor = skipAnchor
        self.skipCenteredCrossing = skipCenteredCrossing
        self.skipGraze = skipGraze
        self.crossingSkipCap = crossingSkipCap
        self.skipRest = skipRest
        self.skipSlip = skipSlip
        self.skipBudgetPerThumb = skipBudgetPerThumb
        self.frequencyWeight = frequencyWeight
        self.habitCap = habitCap
        self.pairBonus = pairBonus
        self.weakScore = weakScore
        self.unsureMargin = unsureMargin
        self.aimedMargin = aimedMargin
        self.crossCostCap = crossCostCap
        self.crossCostPerSecond = crossCostPerSecond
        self.beamWidths = beamWidths
        self.budgetMilliseconds = budgetMilliseconds
        self.previewIntervalMilliseconds = previewIntervalMilliseconds
        self.stickyLeaderMilliseconds = stickyLeaderMilliseconds
        self.swapCost = swapCost
        self.omissionCost = omissionCost
        self.apostropheCost = apostropheCost
        self.neighborCost = neighborCost
    }

    public static let standard = DecodeCosts()

    public func skipCost(_ observation: Observation) -> Double? {
        switch observation.kind {
        case .pin:
            nil
        case .anchor, .tap:
            skipAnchor
        case .crossing:
            observation.centered ? skipCenteredCrossing : skipGraze
        case .rest:
            skipRest
        case .slip:
            skipSlip
        }
    }

    public func countsTowardBudget(_ observation: Observation) -> Bool {
        switch observation.kind {
        case .rest, .slip, .crossing: false
        case .anchor, .tap, .pin: true
        }
    }
}
