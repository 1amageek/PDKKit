import Foundation
import CircuiteFoundation

public protocol PDKOracleComparing: Engine
where Request == PDKOracleRequest, Output == PDKOracleComparisonResult {}
