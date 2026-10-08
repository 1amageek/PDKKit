import PDKCore

public protocol PDKProfileOutputEncoding: Sendable {
    func reserveCompletion(resources: any PDKAdmissionResourceAccounting,
                           policy: PDKProfileOutputCompletionPolicy)
        throws(PDKProfileOutputError) -> PDKProfileOutputCompletion
    func prepare<Value: Encodable>(_ envelope: Value, completion: PDKProfileOutputCompletion)
        throws(PDKProfileOutputError) -> PDKPreparedProfileOutput
}
