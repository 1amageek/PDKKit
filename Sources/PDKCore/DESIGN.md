# PDK Core

## Purpose and Scope

Own PDK manifest, asset, process/layer/device/corner values, identity projections
and resolver protocols. Parent: [PDKKit](../../DESIGN.md). Children:
[Identity](Identity/DESIGN.md), owning implemented checked identity values, and
[Profile](Profile/DESIGN.md), owning implemented immutable exact profile values.

## Responsibilities and Boundaries

Asset values own checks of their declared identity against a supplied immutable
reference. Resolvers own availability and identity discovery. Core does not own
semantic view parsing, source-capture lifecycle, validation aggregation or qualification.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKKit](../../DESIGN.md) | Parent | Manifest and asset values | Package composition | Inspection does not establish qualification |
| [Identity](Identity/DESIGN.md) | Child | Manifest and resolved-asset identity values | Single stored reference authority | Checked immutable schema-2 values; callers must migrate |
| [Profile](Profile/DESIGN.md) | Child | Requirements, source graph and consumption claims | Checked immutable selection values | Claims cannot construct admitted runtime values |
| [CircuiteFoundation](../../../CircuiteFoundation/DESIGN.md) | Depends on | ArtifactReference and locator/digest contracts | Canonical content identity and availability | Availability never replaces identity |
| [PDKStandardViews](../PDKStandardViews/DESIGN.md) | Used by | Asset declaration checks | Admission before semantics | Selected references must be retained |
| [PDKValidation](../PDKValidation/DESIGN.md) | Used by | Asset declaration checks and resolver | Initial asset inventory | Downstream results must join this inventory |

## Architecture

```text
manifest asset -> resolver -> immutable reference
       |                           |
       +--> identityFindings <-----+
                    -> typed declaration mismatch findings
```

## Contracts and Invariants

`PDKAssetReference.identityFindings(for:)` checks every supplied SHA-256 and byte
count against the supplied immutable reference, without I/O or identity discovery.
Missing optional declarations impose no identity constraint. Negative counts and
mismatches produce blockers. Matching declarations produce no findings. Resolver
output identifies current availability; it does not authenticate manifest declarations.

## State, Ownership, and Lifecycle

Checks use invocation-local value state; no shared mutable state or resource lifetime
is introduced. The caller owns selection and retention of the checked reference.

## Verification and Change Impact

[PDKIdentityCompositionTests](../../Tests/PDKKitTests/PDKIdentityCompositionTests.swift)
executes declaration mismatch checks through real view admission and composed
validation. View/rule and validation consumers must be rechecked when declaration
checks change. This change establishes host execution evidence only.

## Controlled Manifest Construction and Validation

Manifest schema and existing ordinary `PDKManifestCodec.decode` / `validate`
semantics remain authoritative. The additive controlled entry is owned by
[ManifestLoading](../PDKDiscovery/ManifestLoading/DESIGN.md#audited-caller-owned-byte-decoding-and-manifest-validation).
Core supplies no JSON lexer and gains no dependency on Discovery or Timing.

The existing `PDKAdmissionResourceAccounting` is the sole caller-neutral resource
contract. `reserve` atomically admits live capacity and returns its copyable
exactly-once reservation; `charge` debits cumulative work; `check` preserves the
same invocation cancellation/deadline. No budget is reset for validation.

One shared manifest rule implementation supplies ordinary and controlled
validation. Ordinary mode supplies no accounting action; controlled mode invokes
package-internal construction events before growth or work. Finding codes,
messages, severity, entity values, rule ordering and `isValid` meaning remain the
same. Semantic findings are reported, not silently dropped on a storage refusal.

| Owned payload/work | Required admission |
|---|---|
| DTO arrays/maps/escaped strings | Existing typed decoder and immutable string storage |
| Custom format normalization | DTO's same decoder-context accountant before derived storage |
| Validation projections and identifier Sets | Type-aware array slots and fixed-toolchain hash-table capacity before construction; same String equality semantics |
| Findings and suggested-action arrays | Struct/array slots before append, simultaneous old/new capacity at growth |
| Constructed finding entities/messages | Exact input/literal byte lengths with checked arithmetic before interpolation |
| Validation loops, string comparisons and token checks | Shared work charge/check before each owned operation and bounded scans |
| Retained report and lease bookkeeping | Admitted before construction and retained to last result copy |

The format constructor's ordinary path retains Unicode `lowercased()` behavior.
The controlled path uses the existing cooperative-normalization capability rule:
ASCII normalization has the exact input UTF-8 length, admitted before output
construction. A non-ASCII format returns typed
`PDKAdmissionResourceError.unsupportedBudgetCapability`; it is not invalid schema
and invokes no unaccounted Unicode fallback. This explicit capability limit does
not change the ordinary schema or the required ASCII standard-format profile.
The callable partial branch must carry its owning incomplete-implementation
marker until an exact, cooperatively accounted Unicode mapping is implemented
and parity/admission/cancellation tests qualify that path.

The controlled owner retains decoded DTO and report reservations together.
Copying that owner shares leases. Freely detaching a DTO, finding or String value
retains the existing caller-owned lifetime responsibility and does not imply a
second accounting guarantee. No mutable state crosses an actor boundary;
decode receipt state retains the existing unconditional Mutex, and upstream
callbacks run outside its critical sections.

Verification compares ordinary and controlled manifest values and complete
validation reports, including invalid/duplicate/reference/whitespace cases.
It distinguishes legacy Unicode-format success from explicit controlled
capability refusal, rejects before derived allocation under tight capacities,
and executes cancellation/failure unwind and final copied-owner refunds.
