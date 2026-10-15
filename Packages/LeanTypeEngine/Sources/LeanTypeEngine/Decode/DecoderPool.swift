public enum DecoderPool {
    @concurrent
    public static func match(_ request: DecodeRequest) async -> DecodeResult {
        AlignmentPathMatcher.match(request)
    }
}
