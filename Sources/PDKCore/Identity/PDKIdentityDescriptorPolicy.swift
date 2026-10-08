import CircuiteFoundation
import CircuiteFoundationFoundation

/// Checks availability intent without rewriting the content reference.
enum PDKIdentityDescriptorPolicy {
    static func matches(_ locator: ArtifactLocator, reference: ArtifactReference) -> Bool {
        locator.role == reference.descriptor.role
            && locator.format == reference.format
            && normalizedKind(locator.kind) == normalizedKind(reference.kind)
    }

    static func normalizedKind(_ kind: ArtifactKind) -> String {
        let value = kind.rawValue.lowercased()
        return value.hasPrefix("pdk.") ? value : "pdk." + value
    }
}
