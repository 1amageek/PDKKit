import Foundation
@_exported import PDKCore
@_exported import PDKDiscovery
@_exported import PDKValidation
@_exported import PDKStandardViews

public enum PDKKitAPI {
    public static let contractVersion = 2
    public static let manifestSchemaVersion = PDKManifest.currentSchemaVersion
    public static let discoveryStageID = "pdk.discover"
    public static let validationStageID = "pdk.validate"
    public static let corpusValidationStageID = "pdk.validate-corpus"
    public static let standardViewInspectionStageID = "pdk.inspect-standard-view"
    public static let ruleDeckInspectionStageID = "pdk.inspect-rule-deck"
    public static let oracleComparisonStageID = "pdk.compare-oracle"
    public static let qualificationStageID = "pdk.qualify"
}
