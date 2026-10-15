public enum SpatialModel {
    public static func cost(_ observation: Observation, costs: DecodeCosts) -> Double {
        let dx = observation.x - observation.keyX
        let dy = observation.y - observation.keyY
        var sigmaX = max(1, costs.sigmaXInKeyWidths * observation.keyWidth)
        var sigmaY = max(1, costs.sigmaYInKeyHeights * observation.keyHeight)
        let speed = (dx * dx + dy * dy).squareRoot()
        if speed > observation.keyWidth * 0.9 {
            sigmaX *= 1.6
        }
        let nx = dx / sigmaX
        let ny = dy / sigmaY
        return (nx * nx + ny * ny) / 2
    }
}
