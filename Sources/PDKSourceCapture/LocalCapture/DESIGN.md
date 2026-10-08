# Local Capture

## Purpose and Scope

Parent: [PDK Source Capture](../DESIGN.md). No children. Own local root-capability
construction and its lifetime around Capture.

## Responsibilities and Boundaries

Resolve explicit local availability, open the secure root through the fixed
CircuiteFoundationFileSystem public API, invoke Capture, and await root shutdown.
Do not implement a second filesystem backend or parser.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | Parent | Source service | Module composition | Host-only adapter |
| [Capture](../Capture/DESIGN.md) | Depends on | Exact bounded bytes | Checked result | Do not reopen the source after capture |
| [Foundation](../../../../CircuiteFoundation/DESIGN.md) | Depends on | ArtifactRootCapability | Secure local filesystem | Match availability root and close owned roots |
| [Bounded source discovery](../../../../CircuiteFoundation/Sources/CircuiteFoundationFileSystem/SourceDiscovery/DESIGN.md) | planned depends on | ArtifactSourceDiscovering | Candidate input observation | Requires new public Foundation version |

## Architecture

```text
expected reference + locator + explicit root + budget
    -> Foundation root capability
    -> Capture
    -> session termination -> root termination -> return
```

## Contracts and Invariants

Location does not change content identity. Root escape and symlink traversal fail
through Foundation's public contract. The root and session have one owning
invocation; no reader uses Data(contentsOf:) after capture.

### Invocation-bounded exact and candidate capture

`PDKBoundedLocalSourceCapturing` owns exact execution; `PDKLocalSourceDiscovering`
owns unknown-identity candidate input. Both require caller-supplied root URL/root
ID and an already checked `ArtifactRelativePath`. Neither derives authorization
from an absolute file's parent. Their concrete service uses a small injected
`PDKSourceRootOpening` / `PDKSourceDiscoveryRoot` lifecycle boundary; the default
constructs Foundation's `ArtifactRootCapability` and calls controlled `discover`.
No legacy referencer, unchecked read session or direct filesystem read participates.

The root-FD and concurrent-acquisition extents are reserved before construction.
Root shutdown is awaited for both success and failure; late cancellation/deadline
refuses publication after cleanup. Exact mode provides the expected descriptor to
discovery and checks the full returned descriptor/count/digest reference before
copying. Candidate mode returns observed input and does not prove profile admission.
Returned pages are borrowed individually, with a complete owned-copy reservation
before allocation, and the capture hashes that identical copied storage.

The injected root lifecycle exists to exercise success, primary failure, close
failure and cancellation during close without weakening the concrete default's
secure root ownership. A shutdown error remains a cleanup failure and never
publishes a capture. Root teardown is mandatory even when accounting is terminal.

## State, Ownership, and Lifecycle

Backend actors own descriptors and ordered shutdown. The adapter retains the
root until all session cleanup completes and awaits root termination on success
and failure. No global mutable state is used.

## Verification and Change Impact

[PDKSourceCaptureTests](../../../Tests/PDKSourceCaptureTests) uses isolated real
temporary roots, same-length tampering, missing files, symlinks and post-capture
mutation/removal. Consumer tests prove decoding uses captured bytes.

Caller-selected roots are explicit capture boundaries. PDK reader
`projectRootPath` is only the existing base for workspace-relative locators;
absolute locators select their own parent root unless a caller explicitly supplies
an authorization root. The local adapter never changes the canonical descriptor
from locator metadata.

### Controlled Candidate Enumeration

`PDKLocalSourceEnumerating.enumerate(intent:rootURL:resources:)` accepts Foundation's
checked `ArtifactDirectoryInventoryIntent`, calls the same owned root's controlled
`enumerate`, and awaits shutdown before returning the inventory. Root/open/concurrency
and work reservations use the same bridge as capture. Foundation owns traversal,
entry names, typed limits, immutable result storage and last-copy retention; Discovery
owns candidate filtering. This path uses no FileManager inventory or public bridge
leakage. Tests exercise real entry-quota refusal and copied-entry owner lifetime.
