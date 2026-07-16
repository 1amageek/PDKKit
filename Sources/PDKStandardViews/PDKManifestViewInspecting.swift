import Foundation
import CircuiteFoundation

public protocol PDKManifestViewInspecting: Engine
where Request == PDKManifestViewInspectionRequest, Output == PDKManifestViewInspectionResult {}
