import Foundation
import PDKStandardViews

struct BoundRuleResultProvider: PDKExternalRuleDeckResultProviding {
    let data: Data

    func resultData(for request: PDKRuleDeckInspectionRequest) async throws -> Data { data }
}
