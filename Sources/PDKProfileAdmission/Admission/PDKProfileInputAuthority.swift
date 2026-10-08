import PDKCore
import PDKDiscovery
import PDKSourceCapture

final class PDKProfileInputAuthority: Sendable {
    let definition: PDKDecodedDocument<PDKProfileDefinition>
    let definitionSource: CapturedPDKSource
    let resources: LocalPDKAdmissionResources
    init(definition: PDKDecodedDocument<PDKProfileDefinition>, source: CapturedPDKSource,
         resources: LocalPDKAdmissionResources) {
        self.definition = definition; definitionSource = source; self.resources = resources
    }
}
