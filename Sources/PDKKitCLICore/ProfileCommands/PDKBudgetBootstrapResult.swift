import PDKCore

/// Fixed-vocabulary parsing observations; these do not describe allocator RSS.
public struct PDKBudgetBootstrapResult: Sendable {
    public let budget: PDKAdmissionBudget
    public let inputByteCount: UInt64
    public let scannedWorkUnitCount: UInt64
    public let dimensionEntryCapacity: Int
    internal init(budget: PDKAdmissionBudget, inputByteCount: UInt64, scannedWorkUnitCount: UInt64,
                  dimensionEntryCapacity: Int) {
        self.budget = budget; self.inputByteCount = inputByteCount
        self.scannedWorkUnitCount = scannedWorkUnitCount; self.dimensionEntryCapacity = dimensionEntryCapacity
    }
}
