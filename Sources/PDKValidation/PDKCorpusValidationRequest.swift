import Foundation
import XcircuitePackage

public struct PDKCorpusValidationRequest: XcircuiteEngineRequest {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [XcircuiteFileReference]
    public var suitePath: String
    public var rootPath: String

    public init(
        runID: String,
        suitePath: String,
        rootPath: String,
        inputs: [XcircuiteFileReference] = []
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = inputs
        self.suitePath = suitePath
        self.rootPath = rootPath
    }
}
