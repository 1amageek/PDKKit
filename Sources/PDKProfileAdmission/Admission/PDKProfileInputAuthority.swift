import PDKCore
import PDKDiscovery
import PDKSourceCapture

final class PDKProfileInputAuthority: Sendable {
    let definition: PDKDecodedDocument<PDKProfileDefinition>
    let definitionSource: CapturedPDKSource
    let resources: any PDKAdmissionResourceAccounting
    init(definition: PDKDecodedDocument<PDKProfileDefinition>, source: CapturedPDKSource,
         resources: any PDKAdmissionResourceAccounting) {
        self.definition = definition; definitionSource = source; self.resources = resources
    }
}
