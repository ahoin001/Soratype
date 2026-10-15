/// Travel that turns a touch into a stroke, and the space-bar gesture gates.
public enum GestureThresholds {
    public static let beyondKey: Double = 8
    public static let sideways: Double = 16
    public static let anyDirection: Double = 36
    public static let spaceTravel: Double = 10
    public static let spaceHoldMilliseconds = 500
    public static let pinMilliseconds = 180
    public static let restMilliseconds = 500
    public static let slipMilliseconds = 60
    public static let cornerDotLimit = 0.45
}
