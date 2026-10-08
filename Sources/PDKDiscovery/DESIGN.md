# PDK Discovery

## Purpose and Scope

Own local candidate discovery and manifest loading. Parent:
[PDKKit](../../DESIGN.md). Children: [ManifestLoading](ManifestLoading/DESIGN.md) and
[CandidateDiscovery](CandidateDiscovery/DESIGN.md).
ManifestLoading implements discovered/exact reads. The obsolete Core builder is
removed; metadata is decoded only from successful source capture.

## Responsibilities and Boundaries

Discovery produces candidates, not validation or qualification. Candidate
enumeration owns search roots and process filtering. ManifestLoading owns the
association between decoded metadata and admitted source identity. Validation,
standard semantics, canonical database storage and Engine execution retain their
existing owners.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKKit](../../DESIGN.md) | Parent | Discovery product | Independent library composition | No Xcircuite import |
| [CandidateDiscovery](CandidateDiscovery/DESIGN.md) | Child | PDKBoundedDiscovering | Invocation-bounded candidates | Explicit roots and shared accounting |
| [ManifestLoading](ManifestLoading/DESIGN.md) | Child | PDKManifestLoading | Discovered/exact manifest loading | Exact capture precedes decoding |
| [PDKCore](../PDKCore/DESIGN.md) | Depends on | Manifest and identity values | Candidate metadata | No reverse dependency |
| [PDKSourceCapture](../PDKSourceCapture/DESIGN.md) | Depends on | Exact immutable bytes | Admission before decoding | Its budget does not bound prior discovery |
| [PDKValidation](../PDKValidation/DESIGN.md) | Used by | Manifest loading | Corpus reference construction | Cancellation stops further cases |

## Architecture

```text
LocalPDKBoundedDiscoverer -> controlled inventory + bounded manifest loading
LocalPDKDiscoverer / CLI / corpus / Xcircuite
               -> PDKManifestLoading
                    -> PDKCore values and codec
                    -> PDKSourceCapture
                    -> Foundation reference discovery (discovered mode only)
```

## Contracts and Invariants

`LocalPDKDiscoverer` filters and reports candidates using the child's loaded
metadata and reference. It does not separately decode a candidate path. Inject
`any PDKManifestLoading` instead of the concrete reference builder. Exact mode
does not enter candidate discovery. Discovery failure remains explicit; a
cancelled load stops enumeration rather than becoming an invalid-manifest warning.

## State, Ownership, and Lifecycle

Candidate enumeration and result collection are invocation-local. Loading owns
its temporary bytes and asynchronous cleanup through the child contract. No
global cache or new shared state is introduced.

## Failure, Concurrency, and Constraints

Legacy enumeration retains its existing scope. Bounded discovery composes the
children's whole-invocation contracts. Discovery warnings are not qualification
findings.

### Whole-invocation discovery

[CandidateDiscovery](CandidateDiscovery/DESIGN.md) owns the implemented explicit-root
bounded inventory and selection contract. [ManifestLoading](ManifestLoading/DESIGN.md)
owns invocation-accounted source association and decoding. The legacy discovery API
retains its existing per-source scope; it does not claim these whole-invocation bounds.

## Verification and Change Impact

Child behavioral tests precede discovery/API/CLI composition. The dedicated
`PDKDiscoveryTests` target depends on Discovery, Core and SourceCapture plus their
Foundation dependencies, without mask codecs, Validation or Xcircuite. Build the
Discovery target independently; avoid interpreting a Swift Testing filter as
proof that unrelated test products were not built. Integration must prove process
filtering uses the same metadata bytes as the returned reference.
