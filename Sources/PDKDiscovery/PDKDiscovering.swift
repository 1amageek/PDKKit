import Foundation
import CircuiteFoundation
import PDKCore

public protocol PDKDiscovering: Engine
where Request == PDKDiscoveryRequest, Output == PDKDiscoveryResult {}
