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
