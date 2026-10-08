import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKSourceCapture

enum BoundCaptureMutation: Sendable {
    case replace
    case remove
    case refuse(PDKSourceCaptureError)
}
