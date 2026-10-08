import Foundation

/// The decoder supplies the invocation accountant; absence denotes standalone, unbudgeted coding.
public enum PDKAdmissionDecodingContext {
    public static let accountingKey: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "PDKKit.admission.resources") else {
            preconditionFailure("The fixed nonempty accounting key must be valid.")
        }
        return key
    }()
}
