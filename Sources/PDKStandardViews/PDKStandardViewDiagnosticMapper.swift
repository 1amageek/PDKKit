import Foundation
import PDKCore
import CircuiteFoundation

public enum PDKStandardViewDiagnosticMapper {
    public static func map(_ finding: PDKValidationFinding) -> DesignDiagnostic {
        DesignDiagnostic(
            severity: finding.severity == .info || finding.severity == .warning ? .warning : .error,
            code: finding.code,
            message: finding.message,
            entity: finding.entity,
            suggestedActions: finding.suggestedActions
        )
    }
}
