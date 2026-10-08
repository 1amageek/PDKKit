/// Original source value; expression text is produced by the bounded grammar owner.
public enum PDKProfileParameterValue: Sendable, Equatable {
    case numeric(Double)
    case numericVector([Double])
    case string(String)
    case boolean(Bool)
    case expression(String)
}
