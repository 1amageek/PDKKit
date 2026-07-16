import Foundation
import CircuiteFoundation

public protocol PDKRuleDeckInspecting: Engine
where Request == PDKRuleDeckInspectionRequest, Output == PDKRuleDeckInspectionResult {}
