# PDK Discovery

## Purpose and Scope

Own local candidate discovery and manifest loading. Parent:
[PDKKit](../../DESIGN.md). Child: [ManifestLoading](ManifestLoading/DESIGN.md).
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
| [ManifestLoading](ManifestLoading/DESIGN.md) | Child | PDKManifestLoading | Discovered/exact manifest loading | Exact capture precedes decoding |
| [PDKCore](../PDKCore/DESIGN.md) | Depends on | Manifest and identity values | Candidate metadata | No reverse dependency |
| [PDKSourceCapture](../PDKSourceCapture/DESIGN.md) | Depends on | Exact immutable bytes | Admission before decoding | Its budget does not bound prior discovery |
| [PDKValidation](../PDKValidation/DESIGN.md) | Used by | Manifest loading | Corpus reference construction | Cancellation stops further cases |

## Architecture

```text
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

Existing enumeration limits and full discovery resource bounds are outside the
identity-construction sprint. Per-candidate source admission uses the child's
explicit capture budget. Discovery warnings are not qualification findings.

### Whole-invocation discovery specification

Status: proposed profile migration. Use bounded root enumeration and candidate
source discovery from [LocalCapture](../PDKSourceCapture/LocalCapture/DESIGN.md)
and the shared [admission accounting](../PDKProfileAdmission/DESIGN.md).
Count roots, every visited entry, candidates, source reads, decode elements and
retained candidate bytes before continued work. Do not reset the deadline or
total work for each manifest. Cancellation stops enumeration immediately at the
next cooperative boundary; an incomplete search is not a complete inventory.
Candidates are neither admitted profiles nor process qualification.

Manifest loading adds invocation-accounted decoding: enforce nesting, element,
scalar-byte and work limits before constructing values. Unbounded JSONDecoder
does not prove this contract. Reuse the existing manifest schema and codec
meaning; the bounded decoder is not a second technology schema. Exact loading
continues to verify supplied identity and discovered loading uses the new
same-read capture instead of the old unbudgeted reference-then-capture path.
Existing ManifestLoading behavior remains implemented until this migration;
no resource claim is inferred from its per-capture default.

## Verification and Change Impact

Child behavioral tests precede discovery/API/CLI composition. The dedicated
`PDKDiscoveryTests` target depends on Discovery, Core and SourceCapture plus their
Foundation dependencies, without mask codecs, Validation or Xcircuite. Build the
Discovery target independently; avoid interpreting a Swift Testing filter as
proof that unrelated test products were not built. Integration must prove process
filtering uses the same metadata bytes as the returned reference.
