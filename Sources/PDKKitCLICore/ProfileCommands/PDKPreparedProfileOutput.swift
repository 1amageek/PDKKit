import PDKCore
import Synchronization

/// Frozen payload plus a single-use fully reserved destination; copies cannot double-spend capacity.
public struct PDKPreparedProfileOutput: Sendable {
    private let owner: Owner
    internal init(payload: PDKOwnedProfileOutput, completion: PDKProfileOutputCompletion,
                  destination: PDKAdmissionReservation, capacity: Int, hasPayloadFields: Bool) {
        owner = Owner(payload: payload, completion: completion, destination: destination,
                      capacity: capacity, hasPayloadFields: hasPayloadFields)
    }
    public func complete(observations: PDKProfileOutputObservations)
        throws(PDKProfileOutputError) -> PDKOwnedProfileOutput {
        let receipt = try owner.take()
        do {
            try owner.completion.owner.resources.check()
            var bytes: [UInt8] = []
            bytes.reserveCapacity(owner.capacity)
            owner.payload.withBytes { payload in
                for index in 0..<(payload.count - 1) { bytes.append(payload[index]) }
            }
            try observations.write(hasPayloadFields: owner.hasPayloadFields) { byte in
                guard bytes.count < owner.capacity else { throw PDKProfileOutputError.suffixCapacityExceeded }
                bytes.append(byte)
            }
            return PDKOwnedProfileOutput(bytes: bytes, resources: owner.completion.owner.resources,
                                        reservations: [receipt])
        } catch { throw .preserving(error) }
    }

    private final class Owner: Sendable {
        let payload: PDKOwnedProfileOutput
        let completion: PDKProfileOutputCompletion
        let capacity: Int
        let hasPayloadFields: Bool
        let destination: Mutex<PDKAdmissionReservation?>
        init(payload: PDKOwnedProfileOutput, completion: PDKProfileOutputCompletion,
             destination: PDKAdmissionReservation, capacity: Int, hasPayloadFields: Bool) {
            self.payload = payload; self.completion = completion; self.capacity = capacity
            self.hasPayloadFields = hasPayloadFields; self.destination = Mutex(destination)
        }
        func take() throws(PDKProfileOutputError) -> PDKAdmissionReservation {
            try destination.withLock { (destination) throws(PDKProfileOutputError) in
                guard let receipt = destination else { throw .completionAlreadyUsed }
                destination = nil
                return receipt
            }
        }
    }
}
