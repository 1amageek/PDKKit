# PDK Profile Values

## Purpose and Scope

Status: proposed specification; no declarations in this document are implemented.
Parent: [PDKCore](../DESIGN.md). No children. Own immutable, location-independent
profile declarations, input selection, dependency graph and consumption claims.
Use existing PDK and CircuiteFoundation values rather than a second technology IR.

## Responsibilities and Boundaries

This component owns what is required and what exact content is selected. It owns
neither acquisition, parsing, executable capability, database storage nor trust.
New source files belong in this directory, one primary type per file. PDKCore's
existing host dependencies are unchanged; this specification makes no new
portable, WASM or Embedded capability claim.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKCore](../DESIGN.md) | parent | Existing manifest, asset and corner types | Value composition | Existing mutable values are copied into immutable profile storage |
| [Identity](../Identity/DESIGN.md) | depends on | PDKReference, ArtifactReference | Full exact identity | ArtifactID does not replace descriptor equality |
| [Profile admission](../../PDKProfileAdmission/DESIGN.md) | used by | Profile definition and claim | Behavioral admission | A decoded claim is not admitted evidence |
| [Database integration](../../../../PDKDesignDatabaseIntegration/DESIGN.md) | used by | Location-independent claims | Canonical retention | Does not introduce another dependency lock |

## Architecture

```text
PDKManifest + exact PDKReference + explicit requirements
    -> PDKProfileDefinition -> PDKProfilePlan
         -> admission -> PDKProfileClaim
             -> stage-specific PDKConsumerRequirement -> PDKConsumptionClaim
Availability maps remain outside all content/selection identities.
```

## Contracts and Invariants

The following names describe proposed Swift types. All stored properties are
`let`; values are `Sendable`. Wire values use checked decoding, explicit schemas
and typed construction errors. Admission-only values have a different owner.

| Proposed type | Required meaning |
|---|---|
| `PDKProfileDefinition` | Stable profile ID; exact manifest reference; explicit process/version; required corner IDs; required view bindings; exact expected source table; ordered source-search authority; dependency records; inspection policy identity |
| `PDKViewRequirement` | Stable requirement ID; purpose ID; existing PDKViewKind/PDKAssetRole; explicit asset IDs; corner IDs; explicit selected section where applicable; demanded source-fact coverage |
| `PDKProfilePlan` | Pure selection outcome, manifest identity and requirements; selected roots and their full expected references; no admission or qualification flag |
| `PDKSourceDependency` | Parent source key and full reference; physical statement position; directive kind; selected child key/reference; section and preprocessing-context identity; lexical occurrence order |
| `PDKProfileClaim` | Current schema; exact definition and manifest references; copied selected PVT; requirement-to-asset/section mapping; full expected source closure and edges; semantic selection digest |
| `PDKConsumerRequirement` | A stage's explicit subset of admitted requirement IDs, corner IDs and operation-specific selection/configuration identity |
| `PDKConsumptionClaim` | Stage requirement identity; parent profile identity; expected projection; actual sources, sections and preprocessing context; domain evidence reference |
| `PDKAdmissionBudget` | Positive finite caller-owned limits and their accounting version; defined by [admission](../../PDKProfileAdmission/DESIGN.md#failure-concurrency-and-constraints), outside semantic identity |

PDKCore also owns the proposed PDKAdmissionCost, PDKAdmissionReservation and
PDKAdmissionResourceAccounting boundary types/requirements. Implementation and
budget policy remain admission-owned. Lower SourceCapture/Discovery use this
protocol without importing the higher admission module. A reservation retains
an accountant-owned exactly-once release handle; it is not a serialized
authorization/evidence token. Accountants are trusted injected resource owners.

PV-01: Requirement IDs and asset IDs are nonempty and unique in their declared
scope. A requirement names its selected assets explicitly. A singular view has
exactly one matching asset per requested corner; declared multi-source views
retain their explicit order. File enumeration order and a first matching role
never choose a view. Alternatives require an explicit selection in the definition.

PV-02: A selected corner has a nonempty process name, finite positive voltage in
volts and finite temperature above absolute zero in Celsius. Reuse
`PDKCornerDefinition`/`PDKPVTCondition`; convert to domain units at the owning
domain boundary. Retain the declared values exactly, without fuzzy name matching,
PVT interpolation or nearest-corner selection. Production profiles explicitly
declare the required typical/slow/fast set; ordinary profiles may request another
explicit set and do not claim production coverage.

PV-03: A required corner-scoped view must be named by the corner's view mapping,
belong to its assetIDs, and be declared by the asset and corresponding cross-view
mapping for the same corner. An unscoped shared view must be explicitly declared
shared. Empty corner bindings cannot satisfy corner-scoped requirements. A model
and its SPICE view may refer to one source without creating two byte authorities.

PV-04: The source key is a stable definition-local identity, not an absolute path.
The definition's source table carries full exact references for roots and include
targets, plus root-relative logical resolution routes. A dependency records both
identity and contextual selection. Several keys/descriptors may share one content
buffer, but their roles, requirement bindings and edge occurrences remain distinct.
The definition may reference explicit external library catalogs by exact content
and, when applicable, the existing exact database dependency lock. No mutable
`latest` or undeclared search-path dependency is accepted.

PV-05: Profile identity is domain-separated, versioned canonical encoding of
the exact definition/manifest references, explicit requirements, PVT, selected
full source references, dependency edges and inspection-policy identity. Sets
are ordered by stable keys; lexical edges and ordered model precedence are not
sorted away. Encoding uses existing content digest services, framed UTF-8 strings
and full references. Finite numeric PVT values use a specified canonical binary
representation with negative zero normalized; duplicate keys and nonfinite
numbers are rejected. Golden byte vectors fix encoding version 1 before runtime
adoption. Moving identical files to another admitted root preserves identity;
editing manifest bytes, selection, an included source or precedence changes it.

PV-06: `PDKProfileClaim` is serializable data, never a bearer capability or a proof
of admission. Deserialization validates structure, canonical form and recomputed
identity. It cannot produce an `AdmittedPDKProfile`. A producer, run result,
resource budget, toolchain, host path or current availability is not included in
the semantic selection digest. Full execution/profile qualification identities
remain with their existing system owners.

## State, Ownership, and Lifecycle

Values retain immutable snapshots and exact references, not open resources or
borrowed pointers. Availability is supplied separately through the existing
ArtifactLocator/ArtifactAvailability and root-capability vocabulary. A copied
manifest or mutable source table cannot change an already constructed plan/claim.

## Failure, Concurrency, and Constraints

Typed construction failures distinguish invalid IDs, unsupported schema,
invalid PVT, missing/ambiguous selection, conflicting references and noncanonical
encoding. Unknown required fields do not become legacy defaults. Pure value
checks allocate only within the invoking admission budget when used at a runtime
boundary; Codable alone establishes no parser-resource guarantee.

## Verification and Change Impact

Planned owner: `PDKProfileValueTests`, a dedicated test target using PDKCore and
CircuiteFoundation without mask codecs or Engine targets. Behavioral cases fix
PV-01..06: ambiguous/missing views, empty corner binding, same-process/different
PVT, ordered precedence, source aliasing, root relocation, included-source drift,
schema rejection and canonical byte vectors. Source files and target declarations
are added only during implementation. Changes affect admission, consumer intake
and canonical retention together.
