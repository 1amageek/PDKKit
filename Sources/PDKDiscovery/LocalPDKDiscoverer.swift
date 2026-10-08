import Foundation
import PDKCore
import CircuiteFoundation
import CircuiteFoundationFoundation
import PDKSourceCapture

public struct LocalPDKDiscoverer: PDKDiscovering {
    private let clock: any PDKDiscoveryExecutionClock
    private let manifestLoader: any PDKManifestLoading

    public init(
        clock: any PDKDiscoveryExecutionClock = SystemPDKDiscoveryExecutionClock(),
        manifestLoader: any PDKManifestLoading = LocalPDKManifestLoader()
    ) {
        self.clock = clock
        self.manifestLoader = manifestLoader
    }

    public func execute(
        _ request: PDKDiscoveryRequest
    ) async throws -> PDKDiscoveryResult {
        let startedAt = clock.now()
        var diagnostics: [DesignDiagnostic] = []
        var candidates: [PDKReference] = []
        var inspectedPaths: [String] = []
        let schemaIsCurrent = request.schemaVersion == PDKDiscoveryRequest.currentSchemaVersion
        let paths = schemaIsCurrent ? discoverManifestPaths(request: request, diagnostics: &diagnostics) : []
        inspectedPaths = paths.map(\.path).sorted()

        var cancelled = false
        for url in paths {
            do {
                let locator = ArtifactLocator(location: try ArtifactLocation(fileURL: url), role: .input, kind: .technology, format: .json)
                let reference = try await manifestLoader.discover(at: locator, relativeTo: nil, captureBudget: PDKSourceCapturePolicy.defaultBudget).reference
                if let requiredProcessID = request.requiredProcessID,
                   reference.processID != requiredProcessID {
                    continue
                }
                candidates.append(reference)
            } catch let error as PDKManifestLoadingError where error.isCancellation {
                cancelled = true
                break
            } catch {
                diagnostics.append(DesignDiagnostic(
                    severity: .warning,
                    code: "pdk.discovery.invalid-manifest",
                    message: "Candidate manifest could not be decoded: \(error)",
                    entity: url.path,
                    suggestedActions: ["inspect_manifest_json", "run_pdkkit_inspect"]
                ))
            }
        }

        candidates.sort {
            if $0.processID != $1.processID { return $0.processID < $1.processID }
            if $0.version != $1.version { return $0.version < $1.version }
            return $0.manifestLocator.path < $1.manifestLocator.path
        }

        let status: PDKExecutionStatus
        if !schemaIsCurrent {
            diagnostics.append(DesignDiagnostic(severity: .error, code: "pdk.discovery.request-schema-unsupported",
                message: "Unsupported request schema version.", entity: "schemaVersion", suggestedActions: ["migrate_request_schema"]))
            status = .blocked
        } else if cancelled {
            diagnostics.append(DesignDiagnostic(severity: .warning, code: "pdk.discovery.cancelled", message: "Manifest discovery was cancelled."))
            status = .cancelled
        } else if request.searchRoots.isEmpty {
            diagnostics.append(DesignDiagnostic(
                severity: .error,
                code: "pdk.discovery.search-roots-missing",
                message: "At least one local PDK search root is required.",
                entity: "searchRoots",
                suggestedActions: ["provide_pdk_search_root"]
            ))
            status = .blocked
        } else if candidates.isEmpty {
            diagnostics.append(DesignDiagnostic(
                severity: .error,
                code: request.requiredProcessID == nil
                    ? "pdk.discovery.no-candidates"
                    : "pdk.discovery.required-process-not-found",
                message: request.requiredProcessID == nil
                    ? "No readable PDK manifest was found in the search roots."
                    : "No readable PDK manifest matched the required process ID.",
                entity: request.requiredProcessID,
                suggestedActions: ["check_search_root", "inspect_manifest_json"]
            ))
            status = .blocked
        } else {
            status = .completed
        }

        let completedAt = clock.now()
        let provenance = try PDKExecutionProvenance.make(
            engineID: "PDKDiscovery",
            implementationID: "LocalPDKDiscoverer",
            implementationVersion: "1",
            startedAt: startedAt,
            completedAt: completedAt
        )
        return try PDKDiscoveryResult(
            schemaVersion: PDKDiscoveryRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: diagnostics,
            artifacts: candidates.map(\.manifest),
            provenance: provenance,
            payload: PDKDiscoveryPayload(
                candidates: candidates,
                inspectedManifestPaths: inspectedPaths
            )
        )
    }

    private func discoverManifestPaths(
        request: PDKDiscoveryRequest,
        diagnostics: inout [DesignDiagnostic]
    ) -> [URL] {
        var urls: [URL] = []
        let fileManager = FileManager.default
        for rootPath in request.searchRoots {
            let rootURL = URL(filePath: rootPath).standardizedFileURL
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
                diagnostics.append(DesignDiagnostic(
                    severity: .warning,
                    code: "pdk.discovery.search-root-missing",
                    message: "Search root does not exist.",
                    entity: rootPath,
                    suggestedActions: ["create_or_correct_search_root"]
                ))
                continue
            }
            if !isDirectory.boolValue {
                if request.manifestFileNames.contains(rootURL.lastPathComponent) {
                    urls.append(rootURL)
                }
                continue
            }
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                diagnostics.append(DesignDiagnostic(
                    severity: .warning,
                    code: "pdk.discovery.search-root-unreadable",
                    message: "Search root could not be enumerated.",
                    entity: rootPath,
                    suggestedActions: ["check_directory_permissions"]
                ))
                continue
            }
            for case let url as URL in enumerator {
                guard request.manifestFileNames.contains(url.lastPathComponent) else { continue }
                do {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                } catch {
                    diagnostics.append(DesignDiagnostic(
                        severity: .warning,
                        code: "pdk.discovery.entry-unreadable",
                        message: "Manifest candidate metadata could not be read: \(error.localizedDescription)",
                        entity: url.path,
                        suggestedActions: ["check_directory_permissions"]
                    ))
                    continue
                }
                urls.append(url.standardizedFileURL)
            }
        }
        return Array(Set(urls)).sorted { $0.path < $1.path }
    }
}
