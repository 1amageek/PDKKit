import PDKCore
import PDKProfileAdmission
import PDKSpiceProfileInspection

struct RefusingSpiceAdapter: PDKProfileSourceInspecting {
    struct Resources: PDKAdmissionResourceAccounting {
        let upstream: any PDKAdmissionResourceAccounting
        func check() throws(PDKAdmissionResourceError) { try upstream.check() }
        func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
            try upstream.check()
            if cost.dimension == .temporaryBytes {
                throw .exhausted(dimension: .temporaryBytes, limit: 0, attempted: 1)
            }
            return try upstream.reserve(cost)
        }
    }
    func inspect(_ request: PDKProfileSourceInspectionRequest, dependencies: any PDKProfileDependencyResolving,
                 resources: any PDKAdmissionResourceAccounting) async throws(PDKProfileInspectionError) -> PDKProfileSourceFacts {
        try await LocalPDKSpiceProfileInspector(policyIdentity: SpiceProfileFixture.policy).inspect(request,
            dependencies: dependencies, resources: Resources(upstream: resources))
    }
}
