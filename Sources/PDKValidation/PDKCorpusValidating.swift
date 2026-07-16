import Foundation
import CircuiteFoundation

public protocol PDKCorpusValidating: Engine
where Request == PDKCorpusValidationRequest, Output == PDKCorpusValidationResult {}
