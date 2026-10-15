public enum ThumbIdentity {
    public static func thumb(at point: Point, midline: Double) -> Thumb {
        point.x < midline ? .left : .right
    }
}
