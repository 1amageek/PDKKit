import Foundation
import PDKCore
import CircuiteFoundation

public enum PDKValidationDiagnosticMapper {
    public static func map(_ finding: PDKValidationFinding) -> DesignDiagnostic {
        DesignDiagnostic(
            severity: finding.severity == .info || finding.severity == .warning ? finding.severity.engineSeverity : .error,
            code: finding.code,
            message: finding.message,
            entity: finding.entity,
            suggestedActions: finding.suggestedActions
        )
    }
}

private extension PDKFindingSeverity {
    var engineSeverity: DiagnosticSeverity {
        switch self {
        case .info: .information
        case .warning: .warning
        case .error, .blocker: .error
        }
    }
}
