# Standard Inspection

## Purpose and Scope

Own `LocalPDKStandardViewInspector` and `PDKStandardViewIR`.
Parent: [PDKStandardViews](../DESIGN.md). No children.

## Responsibilities and Boundaries

Bind parsed facts to the exact bytes read. Preserve LEF physical declarations
using the standard-owned schema. Report parser or integrity failures without
publishing a successful inspection.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | Parent | Inspection results | Public host boundary | Engine support and process qualification remain independent |
| [LEF](../../../../swift-mask-data/Sources/LEF/DESIGN.md) | Depends on | Reader and LEFDocument | Preserve cell/pin/via/site/rule values | Unsupported or unretained grammar must remain explicit |
| [CircuiteFoundation](../../../../CircuiteFoundation/DESIGN.md) | Depends on | ArtifactReference, digest, integrity | Canonical content identity | Compare the parsed buffer to the retained reference |
| [PDKSourceCapture](../../PDKSourceCapture/DESIGN.md) | Depends on | Exact bounded owned bytes | Shared admission before parsing | Identity discovery precedes capture; capture does not bound parser allocations |

## Architecture

```mermaid
flowchart LR
  Expected[Optional authoritative source reference] --> Reference[Selected source reference]
  Locator -->|Only without expected reference| Reference
  Locator --> Capture[Bounded capture and cleanup]
  Reference --> Capture --> Bytes[Immutable verified buffer]
  Bytes --> Parser --> IR[Retained standard document and PDK facts]
```

## Contracts and Invariants

An explicitly expected reference is checked against the input descriptor and used
for capture without rediscovering content identity. Without that expectation the
standalone inspector discovers current content. The parsed buffer's digest and
size match the retained reference. A LEF view
retains both axes, physical cell/pin/via/site declarations and supported rules;
inventory fields derive from the same document. Non-LEF formats have no LEF
document. No extra PDK physical schema redefines standard field semantics.

For LEF, `layerNames` is the sorted unique inventory of explicit layer names
observed in that document: top-level LAYER declarations, macro PIN PORT and OBS
layer references, and local VIA layer records. A reference does not declare a
layer rule; `lefDocument.layers` retains the separate source declarations without
augmentation. An external VIA name supplies no layer inventory. The inspector
does not resolve external masters or infer layer names from via naming conventions.

GDSII and OASIS readers use the same fallible Mask IR projection. Its physical
layer inventory includes explicit boundary, path and text layers. A typed
`IRVia` names a master and route layer but does not supply its physical cut and
enclosure layers. This inspector has no master-resolution input contract; it
therefore refuses such a placement with `PDKMaskProjectionError.unboundViaMaster`
instead of treating the route layer as a complete physical inventory. The public
execution boundary returns a blocked result with
`pdk.standard-view.via-master-unbound` and no inspection. This does not add a
DEF inspection format or a geometry expansion schema.

## Failure, Concurrency, and Constraints

Execution state is local to the call. The injected clock is Sendable and owns its
own synchronization. Invalid input, changed content and parser failure emit
structured failure results. No successful partial document is published when the
codec reports an unsupported statement.
Unbound via projection is an insufficient-semantics blocker; ordinary malformed
codec input remains a parse failure. Source artifact identity is retained when
the projection cannot produce an inspection.
The current codec intentionally rejects unmodeled global controls, layer
properties and masked polygons. These failures describe grammar coverage and do
not permit a consumer to substitute weaker physical rules.

## Verification and Change Impact

Tests exercise local and manifest inspection, JSON round trips, asymmetric
physical grid values and typed parser failure. Removing an incomplete marker
requires successful retained semantics and explicit failure-path evidence;
retention does not establish downstream native physical closure.
[PDKReferencedLEFLayerTests](../../../Tests/PDKKitTests/PDKReferencedLEFLayerTests.swift)
owns actual macro-only PORT mapping, complete observed layer inventory, retained
document/content identity and absent/external-via-only layer refusal through the
public inspection and manifest binding APIs.
Actual GDSII/OASIS fixture execution retains exact source identity and round-trips
the inspection result. The production projection's internal test boundary also
admits real `IRVia` values and verifies typed refusal, preventing an incomplete
route-layer inventory from appearing successful. Mask schema changes require
this shared projection and its public execution callers to be rechecked.

### Profile inspection boundary

Structural inspection and profile admission are different scopes. Until the
[grammar-owned SPICE adapter](../../PDKSpiceProfileInspection/DESIGN.md) is adopted,
a handwritten SPICE inspector explicitly blocks include/inc, external-library
and conditional directives it cannot resolve; no conditional branch is classified
inactive without its grammar owner. Its default branch cannot silently ignore
these directives and emit completed semantic evidence. Any retained limited
parser remains marked incomplete with its production path/removal condition.
Migration removes it as an alternate grammar authority when the CoreSpice adapter
provides the supported facts; metadata names alone do not satisfy graph closure.

LEF/GDSII/OASIS continue to use standard-owned documents. Profile fact adapters
retain full references and explicit mapping/unsupported loss, never a second
physical schema. Each required format must provide cooperative resource accounting
and bounded decode before being selected for the whole-invocation profile scope.
An opaque/unbounded codec cannot advertise that capability merely because its
input bytes fit a limit. Rule-deck or script dependencies require an owning
backend's explicit closure evidence; unknown dynamic includes cannot be asserted
leaf-only by a manifest flag. Numerical rule execution remains Engine-owned.
