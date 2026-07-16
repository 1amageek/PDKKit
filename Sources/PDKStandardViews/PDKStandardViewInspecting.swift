import Foundation
import CircuiteFoundation

public protocol PDKStandardViewInspecting: Engine
where Request == PDKStandardViewInspectionRequest, Output == PDKStandardViewInspectionResult {}
