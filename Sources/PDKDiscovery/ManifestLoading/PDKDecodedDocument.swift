import PDKCore
import CircuiteFoundation

/// Retain this handle for the invocation-managed value lifetime, including copied handles.
/// Detached value or subvalue copies transfer storage responsibility to the caller.
public struct PDKDecodedDocument<Value: Sendable>: Sendable {
    public let value: Value
    /// The exact input identity on source-based decoding; nil on raw-byte decoding, which grants no source authority.
    public let sourceReference: ArtifactReference?
    private let reservations: [PDKAdmissionReservation]

    internal init(value: Value, reservations: consuming [PDKAdmissionReservation], sourceReference: ArtifactReference? = nil) {
        self.value = value
        self.reservations = reservations
        self.sourceReference = sourceReference
    }

    internal func binding(to reference: ArtifactReference) -> Self {
        Self(value: value, reservations: reservations, sourceReference: reference)
    }
}
