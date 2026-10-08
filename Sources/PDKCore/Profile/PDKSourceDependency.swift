import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKSourceDependency: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let parentSourceKey: String
    public let parentReference: ArtifactReference
    public let statementByteOffset: UInt64
    public let statementOrdinal: UInt64
    public let directiveKind: String
    public let literalRoute: String
    public let childSourceKey: String
    public let childReference: ArtifactReference
    public let selectedSection: String?
    public let preprocessingIdentity: String
    public let lexicalOrder: UInt64
    public init(parentSourceKey: String, parentReference: ArtifactReference, statementByteOffset: UInt64, statementOrdinal: UInt64, directiveKind: String, literalRoute: String, childSourceKey: String, childReference: ArtifactReference, selectedSection: String?, preprocessingIdentity: String, lexicalOrder: UInt64) throws(PDKProfileValueError) {
        for id in [parentSourceKey, childSourceKey, directiveKind, preprocessingIdentity] { try PDKProfileWire.id(id) }
        try PDKProfileWire.literalRoute(literalRoute)
        try PDKProfileWire.reference(parentReference, id: parentSourceKey)
        try PDKProfileWire.reference(childReference, id: childSourceKey)
        if let selectedSection { try PDKProfileWire.id(selectedSection) }
        self.parentSourceKey = parentSourceKey
        self.parentReference = parentReference
        self.statementByteOffset = statementByteOffset
        self.statementOrdinal = statementOrdinal
        self.directiveKind = directiveKind
        self.literalRoute = literalRoute
        self.childSourceKey = childSourceKey
        self.childReference = childReference
        self.selectedSection = selectedSection
        self.preprocessingIdentity = preprocessingIdentity
        self.lexicalOrder = lexicalOrder
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, parentSourceKey, parentReference, statementByteOffset, statementOrdinal, directiveKind, literalRoute, childSourceKey, childReference, selectedSection, preprocessingIdentity, lexicalOrder }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["parentSourceKey", "parentReference", "statementByteOffset", "statementOrdinal", "directiveKind", "literalRoute", "childSourceKey", "childReference", "selectedSection", "preprocessingIdentity", "lexicalOrder"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            parentSourceKey: c.decode(String.self, forKey: .parentSourceKey),
            parentReference: c.decode(ArtifactReference.self, forKey: .parentReference),
            statementByteOffset: c.decode(UInt64.self, forKey: .statementByteOffset),
            statementOrdinal: c.decode(UInt64.self, forKey: .statementOrdinal),
            directiveKind: c.decode(String.self, forKey: .directiveKind),
            literalRoute: c.decode(String.self, forKey: .literalRoute),
            childSourceKey: c.decode(String.self, forKey: .childSourceKey),
            childReference: c.decode(ArtifactReference.self, forKey: .childReference),
            selectedSection: c.decodeIfPresent(String.self, forKey: .selectedSection),
            preprocessingIdentity: c.decode(String.self, forKey: .preprocessingIdentity),
            lexicalOrder: c.decode(UInt64.self, forKey: .lexicalOrder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(parentSourceKey, forKey: .parentSourceKey)
        try c.encode(parentReference, forKey: .parentReference)
        try c.encode(statementByteOffset, forKey: .statementByteOffset)
        try c.encode(statementOrdinal, forKey: .statementOrdinal)
        try c.encode(directiveKind, forKey: .directiveKind)
        try c.encode(literalRoute, forKey: .literalRoute)
        try c.encode(childSourceKey, forKey: .childSourceKey)
        try c.encode(childReference, forKey: .childReference)
        try c.encode(selectedSection, forKey: .selectedSection)
        try c.encode(preprocessingIdentity, forKey: .preprocessingIdentity)
        try c.encode(lexicalOrder, forKey: .lexicalOrder)
    }
}
