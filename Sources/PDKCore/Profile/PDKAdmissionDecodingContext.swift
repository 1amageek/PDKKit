import Foundation

/// The decoder supplies the invocation accountant; absence denotes standalone, unbudgeted coding.
public enum PDKAdmissionDecodingContext {
    /// Enabled only by the additive controlled manifest entry; no identity authority.
    package static let controlledManifestKey: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "PDKKit.admission.controlled-manifest") else {
            preconditionFailure("The fixed nonempty manifest key must be valid.")
        }
        return key
    }()

    public static let accountingKey: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "PDKKit.admission.resources") else {
            preconditionFailure("The fixed nonempty accounting key must be valid.")
        }
        return key
    }()
}
