# PDK Core

## Purpose and Scope

Own PDK manifest, asset, process/layer/device/corner values, identity projections
and resolver protocols. Parent: [PDKKit](../../DESIGN.md). Planned child:
[Identity](Identity/DESIGN.md), owning the next single-source value representation.

## Responsibilities and Boundaries

Asset values own checks of their declared identity against a supplied immutable
reference. Resolvers own availability and identity discovery. Core does not own
semantic view parsing, source-capture lifecycle, validation aggregation or qualification.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKKit](../../DESIGN.md) | Parent | Manifest and asset values | Package composition | Inspection does not establish qualification |
| [Identity](Identity/DESIGN.md) | Child | Manifest and resolved-asset identity values | Single stored reference authority | Checked immutable schema-2 values; callers must migrate |
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
