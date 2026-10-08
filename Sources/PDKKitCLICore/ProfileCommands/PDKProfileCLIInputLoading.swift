import CircuiteFoundation
import PDKCore
import PDKDiscovery
import PDKProfileAdmission

public protocol PDKProfileCLIInputLoading: Sendable {
    func loadBudget(root: PDKProfileAuthorizedRoot, relativePath: ArtifactRelativePath,
                    policy: PDKBudgetBootstrapPolicy, accessBudget: ArtifactAccessBudget)
        async throws(PDKProfileCLIInputError) -> PDKLoadedBudgetBootstrap
    func loadAvailability(binding: PDKProfileExactBinding, root: PDKProfileAuthorizedRoot,
                          resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileCLIInputError) -> PDKDecodedDocument<PDKProfileCLIAvailability>
    func loadAuthoring(binding: PDKProfileExactBinding, root: PDKProfileAuthorizedRoot,
                       resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileCLIInputError) -> PDKDecodedDocument<PDKProfileCLIAuthoring>
}
