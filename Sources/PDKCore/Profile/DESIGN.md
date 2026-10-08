# PDK Profile Values

## Purpose and Scope

Status: implemented S3b value and wire boundary; runtime admission remains owned by the admission module.
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

The following types define the checked public value contract. All stored properties are
`let`; values are `Sendable`. Wire values use checked decoding, explicit schemas
and typed construction errors. Admission-only values have a different owner.

| Type | Required meaning |
|---|---|
| `PDKProfileDefinition` | Stable profile ID; exact manifest reference; explicit process/version; required corner IDs; required view bindings; exact expected source table; ordered source-search authority; dependency records; inspection policy identity and separate initial preprocessing identity |
| `PDKViewRequirement` | Stable requirement ID; purpose ID; existing PDKViewKind/PDKAssetRole; explicit asset IDs; corner IDs; explicit selected section where applicable; demanded source-fact coverage |
| `PDKProfilePlan` | Pure selection outcome, manifest identity and requirements; selected roots and their full expected references; no admission or qualification flag |
| `PDKSourceDependency` | Parent source key and full reference; physical statement position; directive kind; selected child key/reference; section and preprocessing-context identity; lexical occurrence order |
| `PDKProfileClaim` | Current schema; exact definition and manifest references; copied selected PVT; requirement-to-asset/section mapping; full expected source closure and edges; semantic selection digest |
| `PDKConsumerRequirement` | A stage's explicit subset of admitted requirement IDs, corner IDs and operation-specific selection/configuration identity |
| `PDKConsumedSource` | Stage-local occurrence ID; exact source/context/corner; optional preceding parent occurrence and its paired full incoming dependency |
| `PDKConsumedMapping` | Occurrence-bound observed kind/name, ordered terminals and independently optional layer number/purpose |
| `PDKConsumptionClaim` | Stage requirement identity; parent profile identity; expected projection; ordered actual source occurrences, corners, selections and observed mappings; domain evidence reference |
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

Owner: `PDKProfileValueTests`, a dedicated test target using PDKCore and
CircuiteFoundation without mask codecs or Engine targets. Behavioral cases fix
PV-01..06: ambiguous/missing views, empty corner binding, same-process/different
PVT, ordered precedence, source aliasing, root relocation, included-source drift,
schema rejection and canonical byte vectors. The dedicated test target depends only on PDKCore and Foundation artifact products. Changes affect admission, consumer intake
and canonical retention together.

## Encoding v1 and Public Boundary

`PDKProfileCoding` / `PDKProfileCodec` own strict current-schema wire encoding.
Profile definition uses `schemaVersion: 2`; other profile declarations retain
schema 1. Consumption source and claim use schema 2 as specified below, and
consumed mapping uses schema 1. Every wire value
requires its exact current schema, every declared field (optional values use explicit
null), and rejects unknown fields. Decode invokes checked
construction. The wire codec performs no bounded parser admission: runtime callers
must supply the admission-owned bounded decode path rather than treating ordinary
JSONDecoder use as resource evidence.

### Initial preprocessing identity

The definition requires a nonempty checked `initialPreprocessingIdentity`,
separate from `inspectionPolicyIdentity`. The latter identifies inspection
semantics; it cannot identify two different initial parameter environments under
the same policy. Selected roots and mandatory-support roots use the declared
initial identity. Dependency edges retain their own actual child-entry identity.
The grammar owner computes identities from the actual initial inputs and checks
the declared identity before parsing. A caller-supplied opaque label cannot replace
that check. This value does not introduce a second expression evaluator or change
parameter/function inheritance.

One initial identity applies to every root in this definition. Corner-specific
initial environments require another explicit contract; no implicit substitution
is provided. The initial identity is committed through the exact definition
reference already present in canonical encoding v1; the v1 framing is unchanged.
Schema 1 definitions and a missing, empty or unknown initial-identity field are
rejected, without deriving a default from inspection policy.

`PDKProfileValueTests` owns checked construction and strict schema-2 round trips.
`PDKProfileAdmissionTests` owns root/support propagation and changed-context
behavior through actual capture and admission. Format adapters own checking the
grammar-computed identity against this declaration.

`PDKProfilePlan` selects the copied manifest through exact `manifestReference`,
process/version, explicit requirement IDs, roles, corner membership and mappings.
Mandatory manifest assets remain selected even when no explicit view requires them.
The plan never authenticates a mutable caller snapshot. `PDKProfileClaim` freezes
the selected transitive closure and recomputes its semantic digest on decode.
`PDKSourcePVTFact` distinguishes complete operating and characterization PVT
facts from `PDKProfileCorner`'s copied manifest declaration; it carries its exact
source and evidence identity and cannot grant admission. `PDKSourceTemperatureFact`
retains operating or model-nominal temperature without inventing missing process
or voltage facts; model nominal temperature cannot satisfy operating PVT.

Canonical encoding v1 uses big-endian UInt64 framing/counts, raw framed UTF-8,
one-byte boolean/optional tags and big-endian IEEE-754 binary64. All finite zeros
encode as positive zero. It begins with framed `PDKKit.Profile.Selection` and
version 1. Artifact references encode algorithm, lowercase digest, byte count,
role, kind and format. Requirements/corners/source-table entries and set-valued
fact kinds sort by stable ID; multi-source asset precedence, search routes, logical routes
and lexical dependency occurrences retain their declared order. No availability
locator, host path, run, budget or qualification field enters the bytes. The
complete 900-byte vector and its independent SHA-256 reside in
`Tests/PDKProfileValueTests/CanonicalGoldenVector.swift`.

Read bytes and hashed bytes have separate cumulative dimensions. Resource dimensions explicitly classify cumulative work versus live capacity.
`PDKAdmissionBudget` requires a positive limit for every dimension plus one positive
elapsed-nanosecond limit. No host policy defaults are imposed. Cost construction
checks accounting version and amount; overflow/limit checks belong to the accountant.
The trusted accountant constructs `PDKAdmissionReservation` with a release action.
Its immutable shared owner invokes that action exactly once at last-copy release;
no explicit release or serialized credential API exists. Production counter state,
deadline/cancellation sampling and overflow-safe reserve remain admission-owned.

Corner view mapping keys remain manifest-defined names. Selection checks asset
membership in the mapping values together with the typed cross-view kind/corner,
asset corner membership and corner asset membership. It does not reinterpret an
open manifest key as a PDKViewKind; stricter domain mappings remain domain-owned.

Dependency `literalRoute` retains parser syntax, including parent-relative `..`
segments. It is not source-table authority. Source `logicalRoutes` and search
routes remain normalized root-relative authority and reject dot/parent segments.
Admission resolves a literal against the selected parent route and ordered search
authority, then checks the resulting declared exact child; actual root escape is
admission-owned. Definition construction checks full parent/child table identity
without equating lexical syntax to a normalized child route.

## Invocation Construction Accounting

Runtime constructors accept an optional `PDKAdmissionResourceAccounting` owner;
standalone calls with no owner establish value semantics only. The bounded decoder
passes its owner through `PDKAdmissionDecodingContext.accountingKey`. An invalid
present context is a typed resource-capability failure, never an unbudgeted fallback.
`PDKProfileValueError.resource` preserves cancellation and resource exhaustion.

Construction checks account actual iteration/comparison work before execution,
including pure selection and contextual-closure loops. Concrete temporary element
capacities use checked `count * MemoryLayout<Element>.stride`; they are capacity
reservations, not exact process RSS claims. Container/runtime overhead retains its
existing measurement owner. Derived Plan/Claim array reservations remain retained
by those immutable values and are excluded from semantic equality, hashing and wire
identity. Existing COW input backing remains charged to its original decoded owner.

Canonical encoding performs an accounting-only sizing traversal before allocating
its framed-byte buffer; every byte of that capacity is reserved before growth.
The canonical buffer retains its reservations through digest completion. Digest
work charges `hashedBytes` and checks before/after bounded chunks. The Foundation
digest API accepts an owned byte array, so a single reserved reusable chunk is
used for cooperative hashing instead of an unaccounted whole-buffer copy.

The decoder's invocation wrapper retains decoded owned backing until the returned
`PDKDecodedDocument`'s final-copy release and temporary constructor handles through
decode completion. Copying a handle does not create another charge. Runtime callers
that construct Plan/Claim directly retain their derived-storage handles through
the value itself; the caller remains owner of input decoded backing.

Checked lookup and duplicate detection use linear arrays or borrowed array ranges,
not hash containers whose bucket capacity cannot be pre-admitted. String comparison
charges a cooperative UTF-8 traversal and comparison work before calling Swift's
canonical-equivalence comparison, preserving existing Unicode value semantics.
Array reservations cover requested element storage (`capacity * stride`), not Swift
allocator granularity or process RSS; reservation-handle bookkeeping and allocator
metadata remain with the invocation's host memory measurement owner. Runtime callers
must retain the enclosing Plan/Claim or decoded document while borrowing its backing.
A plan-derived claim retains the plan's existing receipts for shared nested selection
storage and separately admits its new dependency array. Receipt copies do not recharge.

Bounded descriptor normalization streams ASCII case folding and the existing `pdk.`
prefix rules. Unicode kind normalization requires a cooperative backend not supplied
by the fixed Foundation policy: it returns typed `unsupportedBudgetCapability` rather
than calling an unbounded Unicode transform. Standalone construction preserves the
existing Foundation normalization. SHA-256 declarations with non-ASCII syntax fail
identity comparison and do not become a Unicode normalization capability request.

## Consumption Wire Structure

This component owns structural validation of untrusted consumed-value claims.
[Profile admission](../../PDKProfileAdmission/DESIGN.md) owns deriving an expected
stage projection and comparing actual domain consumption against it. Pure wire
construction can represent an incomplete observed graph and never proves admission,
expected closure completeness or native retained-owner lifetime.

| Value / schema | Required fields and structural meaning |
|---|---|
| `PDKConsumedSource` / 2 | `occurrenceID: UInt64`, `sourceKey`, full `reference`, nullable `cornerID`, nullable `selectedSection`, `preprocessingIdentity`, nullable `parentOccurrenceID`, nullable `incomingDependency` |
| `PDKConsumedMapping` / 1 | `occurrenceID: UInt64`, nonempty `factKind` and `name`, ordered terminals (each ID nonempty; list may be empty), nullable `layerNumber: Int`, nullable `layerPurpose: PDKLayerPurpose` |
| `PDKConsumptionClaim` / 2 | Existing stage/profile/projection/corner/selection/evidence fields plus required `actualSources` occurrence list and required `actualMappings` |

```text
actualSources: occurrence 0 ... N-1
    child occurrence -> preceding parent occurrence + full incoming edge
actualMappings: observed record -> valid occurrence
checked wire claim -> native expected-projection matcher
```

A consumed root has both parent and incoming dependency null; a child has both
present. Source construction checks its incoming edge's full child key/reference,
selected section and preprocessing identity. Claim construction requires occurrence
IDs exactly equal to their zero-based array positions. Each nonroot parent must
precede the child, and the incoming edge's full parent key/reference must match that
parent occurrence. Child corner equals parent corner; every nonnull corner ID must
be present in `actualCorners`. Exact ordered occurrences replace the former unique
source-context rule, preserving repeated nonrecursive includes and independently
corner-scoped roots even when their source/section/preprocessing context matches.
Incoming edge lexical order retains admitted global occurrence identity and may
have gaps after stage projection; it is neither renumbered nor sorted separately.

Mapping occurrence IDs must bind an actual source occurrence. Exact duplicate
mapping records are rejected after comparing occurrence, kind, name, ordered
terminals and observed layer fields. Terminals retain their declared order. Layer
number and purpose are independently optional, and signed layer numbers retain the
exact lower provider observation without inventing physical meaning. This preserves
the [admission provider contract](../../PDKProfileAdmission/Admission/DESIGN.md).
Physical range or field-pair requirements belong to required mapping/domain
semantics. These structural checks do not decide whether a mapping satisfies a
required source condition. The native matcher requires at least one exact observed
candidate per required condition and may accept additional known facts, including
unrelated observations with only one layer field.

Source and claim schema 1 are rejected without legacy defaults; all new nullable
fields are required keys with explicit null encoding. The shared strict-key helper
accepts an explicit expected `schemaVersion` (default 1 for unchanged values), and
changed types pass their own current version. This does not alter profile selection
canonical encoding v1 or any existing profile declaration schema.

Optional construction accounting cooperates before validation loops, lookup and
full reference/context/mapping comparisons using the existing checked work helper.
Array/String inputs remain caller-owned immutable value backing. Codable establishes
strict structure, not bounded parsing; native runtime intake retains its own checked
owners and uses its own bounded admission contract.

Verification owner: `PDKProfileValueTests/ConsumptionValueTests`. Behavioral proofs
reject old schemas and missing required fields, accept repeated contexts/per-corner
sources, reject out-of-order/duplicate occurrences, absent or mismatched parents,
edge reference/context mismatch, missing paired fields, unknown/mismatched corners,
duplicate mappings and mappings bound to unknown occurrences. Checked encode/decode
round trips preserve all new fields, terminal order and independently optional/signed
layer observations, including an unrelated half-layer record. Changes affect native
consumption projection/matching and serialized consumer claims; selection v1 golden
evidence remains unchanged.
