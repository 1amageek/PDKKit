public protocol PDKBudgetBootstrapDecoding: Sendable {
    /// The caller retains the bounded input buffer throughout this synchronous borrow.
    func decode(_ bytes: borrowing Span<UInt8>, policy: PDKBudgetBootstrapPolicy)
        throws(PDKBudgetBootstrapError) -> PDKBudgetBootstrapResult
}
