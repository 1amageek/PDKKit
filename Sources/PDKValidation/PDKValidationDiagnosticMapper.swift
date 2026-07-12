import Foundation
import PDKCore
import XcircuitePackage

public enum PDKValidationDiagnosticMapper {
    public static func map(_ finding: PDKValidationFinding) -> XcircuiteEngineDiagnostic {
        XcircuiteEngineDiagnostic(
            severity: finding.severity == .info || finding.severity == .warning ? finding.severity.engineSeverity : .error,
            code: finding.code,
            message: finding.message,
            entity: finding.entity,
            suggestedActions: finding.suggestedActions
        )
    }
}

private extension PDKFindingSeverity {
    var engineSeverity: XcircuiteEngineDiagnosticSeverity {
        switch self {
        case .info: .info
        case .warning: .warning
        case .error, .blocker: .error
        }
    }
}
