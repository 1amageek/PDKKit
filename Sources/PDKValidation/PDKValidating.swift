import Foundation
import CircuiteFoundation
import PDKCore

public protocol PDKValidating: Engine
where Request == PDKValidationRequest, Output == PDKValidationResult {}
