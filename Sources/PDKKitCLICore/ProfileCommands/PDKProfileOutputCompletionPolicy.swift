public struct PDKProfileOutputCompletionPolicy: Sendable, Equatable {
    public let maximumSuffixByteCount: Int
    public static var standard: Self {
        Self(checkedMaximumSuffixByteCount: PDKProfileOutputObservations.maximumSuffixByteCount)
    }
    public init(maximumSuffixByteCount: UInt64) throws(PDKProfileOutputError) {
        guard maximumSuffixByteCount <= UInt64(Int.max),
              maximumSuffixByteCount >= UInt64(PDKProfileOutputObservations.maximumSuffixByteCount) else {
            throw .invalidCompletionPolicy
        }
        self.maximumSuffixByteCount = Int(maximumSuffixByteCount)
    }
    private init(checkedMaximumSuffixByteCount: Int) {
        self.maximumSuffixByteCount = checkedMaximumSuffixByteCount
    }
}
