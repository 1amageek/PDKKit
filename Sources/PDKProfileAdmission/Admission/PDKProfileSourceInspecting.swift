import PDKCore

public protocol PDKProfileSourceInspecting: Sendable {
    func inspect(_ request: PDKProfileSourceInspectionRequest, dependencies: any PDKProfileDependencyResolving,
                 resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileInspectionError) -> PDKProfileSourceFacts
}
