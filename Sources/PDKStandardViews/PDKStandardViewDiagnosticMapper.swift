import Foundation
import PDKCore
import XcircuitePackage

public enum PDKStandardViewDiagnosticMapper {
    public static func map(_ finding: PDKValidationFinding) -> XcircuiteEngineDiagnostic {
        XcircuiteEngineDiagnostic(
            severity: finding.severity == .info || finding.severity == .warning ? .warning : .error,
            code: finding.code,
            message: finding.message,
            entity: finding.entity,
            suggestedActions: finding.suggestedActions
        )
    }
}
