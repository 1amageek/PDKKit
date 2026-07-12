import Foundation

public struct PDKValidationFinding: Sendable, Hashable, Codable {
    public var severity: PDKFindingSeverity
    public var code: String
    public var message: String
    public var entity: String?
    public var suggestedActions: [String]

    public init(
        severity: PDKFindingSeverity,
        code: String,
        message: String,
        entity: String? = nil,
        suggestedActions: [String] = []
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.entity = entity
        self.suggestedActions = suggestedActions
    }
}
