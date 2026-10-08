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

### Bounded candidate discovery specification

Status: proposed, distinct from implemented exact capture. A proposed
`PDKLocalSourceDiscovering` requirement takes explicit root-relative source intent
and budget and returns a checked CapturedPDKSource from the same immutable observed
bytes. Its adapter uses the new public Foundation discovery contract linked above.
It performs no independent pathname rehash and no private-API/filesystem bypass.
Any required copy and full-buffer verification are charged to invocation resources.
The discovered capture is candidate input, not an approved profile definition.
Exact profile execution uses supplied expected references and never invokes this
discovered mode as recovery. Fixed Foundation 26.812.0 cannot satisfy this new mode;
until an adopted version does, required bounded discovery fails explicitly.

Profile callers supply explicit authorization roots rather than relying on the
legacy absolute-locator parent-root selection. The authorizing root is retained
only in resolution evidence; it is not semantic identity. Await root termination
before returning successfully. Source buffers transfer their live reservations
to the returned owner rather than becoming uncharged retained storage.

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
