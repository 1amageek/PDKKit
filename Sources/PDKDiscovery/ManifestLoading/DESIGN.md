# PDK Manifest Loading

## Purpose and Scope

Implemented local manifest loading; dependent Xcircuite migration is tracked in
PROGRESS.md. Parent:
[PDKDiscovery](../DESIGN.md). No children. Own consistent construction of a
manifest plus its reference at the existing public API/CLI/flow entrypoints.

| Fixed scope | Decision |
|---|---|
| Required outcome | Metadata and published identity derive from the same admitted bytes |
| Changed responsibility | Manifest loading and identity construction, including duplicate value identity |
| Preserved invariants | Exact reference propagation, typed failure/cancellation, successful cleanup before publication, independent domain packages |
| Completion evidence | Counterexample refusal, real file/API/CLI behavior, exact Xcircuite input binding, affected caller builds |
| Separate work | Corner/view selection closure, transitive model includes, complete parsing/resource budgets, Engine migration and process qualification |

## Responsibilities and Boundaries

Use the existing native PDKDiscovery target and a component directory. Do not add
a package, facade, snapshot store or lock service. Core owns value identity;
SourceCapture owns exact byte admission; this component owns decoding those bytes
and associating process/version with their identity. Database and workspace
resolution remain external.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKDiscovery](../DESIGN.md) | Parent | Candidate loading | Product and enumeration composition | No semantic validation claim |
| [Identity](../../PDKCore/Identity/DESIGN.md) | Depends on | Single-source reference values | Immutable claims and descriptor policy | Claims are not capture receipts |
| [PDKSourceCapture](../../PDKSourceCapture/DESIGN.md) | Depends on | PDKLocalSourceCapturing, CapturedPDKSource | Admitted immutable bytes and cleanup | No unknown-identity read API is assumed |
| [CircuiteFoundation](../../../../CircuiteFoundation/DESIGN.md) | Depends on | ArtifactReferencing and content identity | Fixed public reference discovery | No private API or upstream change |
| [Workspace architecture](../../../../DESIGN_WORKSPACE_ARCHITECTURE.md) | Coordinates with | Exact input resolution | Xcircuite supplies fixed reference and availability | A path cannot replace an existing identity |
| [Database architecture](../../../../DESIGN_DATABASE_ARCHITECTURE.md) | Coordinates with | Exact revision/content dependency lock | Existing identity persistence | No duplicate lock implementation |

## Architecture

```text
discover(locator)                    loadExact(reference, locator)
       |                                      |
ArtifactReferencing                           |
       |                                      |
normalize new kind/format; retain role         |
       +---------------+----------------------+
                       v
            PDKLocalSourceCapturing
            exact bytes + completed cleanup
                       v
       internal checked PDKLoadedManifest construction
       bounded codec copy -> decode -> process/version -> PDKReference
                       v
       caller receives manifest and reference from the same bytes
```

## Contracts and Invariants

Public API, with one primary type per file in this component:

```swift
public protocol PDKManifestLoading: Sendable {
    func discover(
        at locator: ArtifactLocator,
        relativeTo root: URL?,
        captureBudget: ArtifactAccessBudget
    ) async throws(PDKManifestLoadingError) -> PDKLoadedManifest

    func loadExact(
        reference: ArtifactReference,
        at locator: ArtifactLocator,
        relativeTo root: URL?,
        captureBudget: ArtifactAccessBudget
    ) async throws(PDKManifestLoadingError) -> PDKLoadedManifest
}

public struct PDKLoadedManifest: Sendable {
    public let manifest: PDKManifest
    public let reference: PDKReference
}
```

`LocalPDKManifestLoader` implements the protocol, injecting existing
`any ArtifactReferencing` and `any PDKLocalSourceCapturing`. Constructor dependencies
are Sendable and immutable. Neither a generic nor an extension-only method is
needed for existential dispatch.

`PDKLoadedManifest` has no public arbitrary initializer or Codable conformance.
Its internal checked construction accepts a successful `CapturedPDKSource`,
locator and codec-copy bound, decodes that capture, and derives metadata from the
decoded manifest. The same captured reference is retained. This fixed construction
algorithm is not an overridable protocol requirement. The value retains the
decoded manifest/reference, not the byte buffer or open resource.

| Invariant | Guarantee |
|---|---|
| Metadata and identity describe one byte sequence | Decode only the successful capture; never decode `contentsOf:` before or after discovery |
| Upstream identity remains authoritative | Exact mode never calls a referencer or retries in discovered mode; returned manifest reference equals the supplied full reference |
| Discovery is not authentication | Discover current identity, capture exactly that identity, then decode; later readers still verify the returned claim |
| No race is repaired by accepting another generation | Bytes differing from the selected reference produce capture failure; caller decides whether to issue a new operation |
| Parsing and acquisition remain separate | No asset resolution or manifest-wide semantic validation inside the loader; malformed JSON/schema and unusable process/version fail explicitly |
| Cleanup precedes publication | Reuse capture's terminal-page/session/root guarantees; no loaded result after cleanup failure |

Two I/O passes in discovered mode are intentional with the fixed Foundation API:
identity discovery followed by exact capture. Both may hash bytes. Consistency
comes from decoding the capture whose digest was independently checked, not from
assuming that the path stayed unchanged. Exact mode skips identity discovery.

## Runtime Flows

1. Validate manifest locator descriptor and explicit root requirements.
2. In discovered mode, obtain a reference through the injected existing referencer
   and normalize only its newly created PDK kind/format descriptor once, preserving
   the locator role. Do not parse that path.
3. In exact mode, validate and retain the supplied reference unchanged. Generic
   `technology` and qualified `pdk.technology` descriptors follow Core policy.
   Retain producer-defined roles, including a stage output consumed as an input.
4. Capture the selected exact reference under `captureBudget`.
5. Construct the loaded manifest from captured bytes; reject decode or reference
   construction failure.
6. Release temporary bytes after construction and return the loaded value.

The CLI `inspect` output takes both its displayed manifest and digest from this
value. Local discovery and corpus use discovered mode. The four PDK Xcircuite
stage executors use exact mode with `manifestBinding.reference`, retaining its
identity in the request and provenance. Physical flow's template rebinding must
load the replacement exactly and compare process/version with the requested
template, rejecting a mismatch rather than carrying old metadata forward.

Existing validation/view/rule readers already capture exact manifests. Preserve
their admission and binding algorithms; adapt value construction/wire decoding
without replacing successful capture with a claim-only check.

## State, Ownership, and Lifecycle

One operation owns discovery, capture and the bounded Data conversion. Capture
owns handles and asynchronous cleanup. The loader keeps no shared mutable state;
no actor, Mutex, target-specific raw storage or unchecked Sendable is introduced.
`PDKLoadedManifest` stores value snapshots; later mutations of copies cannot alter
the originally constructed pair. Public `PDKReference` serialization carries a
claim and does not recreate a loaded/captured evidence object.

## Failure, Concurrency, and Constraints

`PDKManifestLoadingError` distinguishes invalid input, discovery failure,
source capture failure (retaining the existing typed error), manifest decode
failure and reference-construction failure. Source capture retains primary and
cleanup errors together. Preserve cancellation classification, including a thrown
CancellationError from injected discovery; stop enclosing discovery/corpus work.
The loader does not translate failure into an empty manifest or default metadata.

`captureBudget` applies to exact admission and the explicit codec copy bound;
retain the current SourceCapture default-selection policy at composition roots.
Peak retained source memory includes capture storage plus that Data copy and
decoded values. No new unmeasured zero-copy or speed claim is made.

Prior identity discovery uses the fixed public `ArtifactReferencing` contract,
which has no budget parameter. Directory enumeration, prior discovery duration
and JSON decoder allocations are not bounded by `captureBudget`. Consequently
this sprint must not claim a fully bounded PDK startup path. Closing those resource
contracts is the separate resource work already identified, not a new hidden
timeout or an assumed unknown-reference capability in Foundation.

## Verification and Change Impact

Pre-migration observations retained as regression requirements:

| Current path | Evidence |
|---|---|
| Builder decodes one read, then independently references the path | `8e1faf2:Sources/PDKCore/PDKManifestReferenceBuilder.swift` (removed) |
| CLI inspect repeats decode/hash split | [PDKKitInspectCommand](../../PDKKitCLICore/PDKKitInspectCommand.swift) |
| Resolved asset can hold divergent digest representations | [PDKResolvedAsset](../../PDKCore/Identity/PDKResolvedAsset.swift) |
| Xcircuite resolves an identity, then rebuilds through a path | [PDK validation stage](../../../../Xcircuite/Sources/Xcircuite/PDKValidationFlowStageExecutor.swift) |
| Database already stores exact source identities | [PDKDatabaseProcessState](../../../../PDKDesignDatabaseIntegration/Sources/PDKDesignDatabaseSchema/PDKDatabaseProcessState.swift) |

The retained native public-API probe reproduced mixed process/digest generations
using a same-size, same-inode write with a restored fixed mtime, and contradictory
resolved-asset projections. Its first attempt detected a timestamp precision
change and correctly failed discovery; a fixed integral timestamp made the
metadata-preserving counterexample deterministic. See
[probe](../../../../.verification/runs/pdk-reference-design/probe.py) and
[successful execution](../../../../.verification/runs/pdk-source-foundation/reference-design-counterexamples-stable-time.json).
This proves current counterexamples; it does not verify the proposed implementation.

Behavioral proof ownership:

| Owner | Falsifiable evidence |
|---|---|
| Identity value tests | Reject obsolete/contradictory wire fields; preserve descriptor and single stored identity |
| ManifestLoading tests | Real SHA/file success; deterministic replacement between discovery and capture fails; deletion after capture still yields its original metadata/reference |
| Exact-mode tests | A counting referencer receives zero calls; same-length replacement fails; generic supplied technology descriptor and producer role remain unchanged |
| Loading failure tests | Malformed JSON, missing file, symlink/root escape, byte-limit rejection, cancellation and paired cleanup failure publish no loaded result |
| CLI/discovery/corpus | Inspect manifest/digest agreement; process filtering uses captured metadata; cancellation terminates subsequent cases |
| Xcircuite | Four actual PDK stage paths retain the pre-resolved reference and provenance; replaced input is rejected; physical template rebind rejects process/version change |
| Database integration | Existing input-role schema sources retain unchanged full references; canonical dependency identity remains location-independent. Loading a producer output does not automatically publish it into the input-only PDK database schema |

Implement in three serial sprints: value representation and focused value proof;
loader plus PDK API/CLI callers and focused loading proof; exact Xcircuite handoff
and cumulative integration proof. Each implementation sprint owns review, tests
and its coherent commit. They share mutable API/source prerequisites and are not
a parallel implementation group. Tests use bounded commands and existing fixed
native dependency/toolchain configuration; use lower target/probe evidence before
one affected-package and task integration pass. No repeated large build attempt
without new evidence. Native evidence does not establish WASM/Embedded behavior.

Remove `PDKManifestReferenceBuilder` rather than retain a deprecated alternate
path. Add the SourceCapture dependency to Discovery, Discovery to corpus's
Validation target where needed, and direct Discovery imports/dependencies to
Xcircuite callers. CLI already depends on Discovery. Core gains no upward edge;
StandardViews needs no Discovery edge for its existing exact read path.

Wire migration owns explicit envelopes: Discovery 1 -> 2, Validation 3 -> 4,
ManifestView 3 -> 4, RuleDeck 2 -> 3, Oracle 1 -> 2 and PhysicalDesignRequest / PhysicalDesignRunManifest 6 -> 7.
StandardViewInspectionRequest remains 4 because it carries no PDKReference.
Only new versions of changed envelopes and identity values are accepted;
fixtures, external providers, CLI output and Xcircuite persisted request readers
must migrate together. Corpus schema and manifest document schema do not change.
The implementation updates INTERFACES and owner design links rather than
leave the old projection or builder as an alternate authority.

The approved adoption scope updates every revision-based consumer in the
Xcircuite dependency closure in dependency order. Package manifests retain
exact immutable revisions; temporary source overrides are verification aids
and are removed before ordinary graph resolution. Consumer domain behavior
and qualification ownership remain unchanged.

### Cooperative document decoding

The independent bounded decoder is selected explicitly; the existing ordinary
manifest-loader codec path remains unchanged until its owner migration. A source
capture budget alone does not imply this decoder was used.

`PDKBoundedDocumentDecoding` accepts verified `CapturedPDKSource` and the caller's
single invocation accounting owner. `NativePDKBoundedDocumentDecoder` lends the
capture's `Span` to a synchronous parser, without a Data copy or JSONDecoder.
`PDKDecodedDocument<Value>` retains decoder-owned value capacity and the exact
full `sourceReference`, including its descriptor, on all three public source-based
operations. The reference does not retain the captured byte buffer. Internal raw
Span tests may produce an unbound value with a nil reference; production loaders
reject nil or mismatched references before metadata publication. The wrapper's
initializer and binding operation are internal, so an external injected provider
cannot reconstruct a wrapper with arbitrary metadata and a replacement binding.
Loaded/admitted composition retains the capture and this handle for their separate
invocation-managed lifetimes; copying the handle shares the same reservations. A caller detaching freely copyable Core
values or subvalues takes responsibility for their storage lifetime. Such copies
are outside invocation-managed retained ownership.

```text
CapturedPDKSource.withBytes
    -> iterative JSON syntax scan + flat arena
        -> component-owned Decoder
            -> existing checked PDKCore Decodable constructors
                -> PDKDecodedDocument + retained owned reservations
```

| Resource | Admission boundary and lifetime |
|---|---|
| parserWork | Before byte scan, string/number conversion, duplicate comparisons and Decoder lookup; checked Core constructors receive the same accountant through `PDKAdmissionDecodingContext.accountingKey` |
| decodedElements | Before each JSON value and object key enters the arena |
| scalarBytes | Before string output growth and number token materialization; cumulative across documents |
| decodeNesting | Before pushing each object/array frame; released only after close or failure unwind |
| temporaryBytes | Before string scratch, arena/frame/container growth, key lookup projections, coding paths and reservation bookkeeping; retained until decode finishes |
| liveOwnedBytes | Before root value, parser-owned immutable String backing and type-aware Array/Dictionary decode growth; returned owner retains these reservations |

The flat arena uses node indices rather than recursively owned JSON values.
Its parser frame stack is iterative, so malicious unused fields cannot consume
an unbounded native recursion stack. Source pointers remain within the capture's
synchronous closure, are byte-bound and never escape into nodes or returned values.
There is no manual allocation, rebinding or cross-task pointer sharing.

String nodes admit their immutable backing once as owned storage; returned
values share that backing without a second owned charge. The handle conservatively
retains string capacity for ignored fields as well as selected values. Syntax-node
and transient typed-value slots remain separate temporary capacity.

Collection pre-admission derives element/key/value sizes from `MemoryLayout`.
The fixed Swift 6.4.0 shipped module interface confirms geometric Array growth,
power-of-two hash buckets and the 3/4 maximum hash load. Capacity includes old
and replacement backing at growth. These are admitted storage capacities rather
than exact process RSS: runtime object headers, allocator rounding and framework
overhead remain separately measured by the host's representative inventory.
A toolchain/collection implementation change requires rechecking these formulas.

Duplicate decoded keys, malformed delimiters/escapes, invalid UTF-8 and Unicode
surrogates, invalid numbers and numeric overflow fail with typed errors. Resource
exhaustion, cancellation and deadline failures retain the original typed resource
error. Syntax and Decoder operations check the shared deadline/cancellation before
work boundaries and publication. Definition/claim constructors remain the semantic
authority; their concrete validation/canonical allocations and loops opt into the
same accounting contract rather than being inferred from syntax preflight.

All shared decode accounting state uses `Mutex<State>` on the native path. Only
short local receipt bookkeeping and capacity growth execute inside that lock;
upstream charge/reserve/check callbacks execute outside it. There is no platform-specific
raw-state branch or weak ownership.

| Scope | Storage / isolation | Read and mutation | Release |
|---|---|---|---|
| Invocation budget | Caller-supplied accountant | Public charge/reserve/check | Caller lifecycle |
| Decode receipts | Mutex<State> | Synchronous append/takeOwned | Temporary receipts at decode end; owned receipts with returned handle |
| Syntax arena and frames | Task-local arrays | Iterative scanner; immutable Decoder reads | Decode end, including failure |
| Captured bytes | Capture-owned immutable buffer | Borrowed byte span | Capture's existing owner |

[PDKBoundedDecodingTests](../../../Tests/PDKBoundedDecodingTests) owns actual checked
manifest/definition/claim round trips, exact capture after deletion, hostile-depth
syntax, duplicate/UTF-8/number refusals, cumulative limits, live capacity unwind,
last-handle release and typed cancellation. Loader/source/discovery composition
retains its existing integration test ownership. No WASM/Embedded execution claim
is made by this host component.

### Audited typed decoding specialization

The concrete native convenience `decodeAudited(_:source:accounting:
rejectUnknownFields:validate:)` reuses this syntax/typed decoder, returns a full-source-bound
`PDKDecodedDocument<Value>` and preserves typed resource errors. It is an audited
specialization boundary, not an arbitrary generic whole-allocation guarantee.
`PDKBoundedDocumentDecoding` retains its three non-generic PDK document operations.
The generic type's custom Decodable code, custom CodingKey initialization, derived
storage and collection families other than the reviewed Array/Dictionary paths
are outside the decoder guarantee unless their concrete owner audits/accounts
them. Merely satisfying Decodable or fitting the source byte budget is insufficient.
The validation hook receives the same Decoder synchronously and cannot escape.
It runs before the standard type's decode; its custom allocations and work remain
the specializing owner's responsibility rather than an inferred codec guarantee.

The opt-in strict mode rejects a raw object member that cannot be represented by
the requested CodingKey before decoding that object's typed fields, including
nested objects. Dictionary keys remain data. Existing manifest/definition/claim
operations retain their mode and checks. The strict-key checks and their key/path
storage use the same invocation accounting owner; this introduces no second JSON
parser or standard schema. A specializing owner validates any additional accepted
schema policy through Decoder containers and delegates to the existing standard
type rather than recreating its physical fields.

The [StandardViews ProfileInspection](../../PDKStandardViews/ProfileInspection/DESIGN.md)
specialization owns the reviewed IRTechLibrary family and its strict data-only
policy, mapping projection and constructor/fact accounting. This component owns
decoder storage and receipts only. Source bytes remain separately owned by the
checked input. Detached decoded values retain the existing caller-owned lifetime
contract. Native specialization tests must exercise actual non-PDK typed values,
unknown nested fields, resource failure and last-copy receipts before the new
entry can support a production capability claim.

### Invocation-bounded manifest loading

`PDKBoundedManifestLoading` composes the verified controlled capture/discovery
requirements and `PDKBoundedDocumentDecoding`. The concrete
`LocalPDKBoundedManifestLoader` receives only these protocol capabilities. Both
operations require an explicit root URL/ID, normalized relative path, per-source
access budget and the caller's invocation accountant. Exact loading compares the
complete expected reference before decoding and never invokes discovered mode.

`PDKBoundedLoadedManifest` owns the checked source and decoded document together.
Its checked internal initializer compares the document's complete source reference
with the capture, including descriptor, and refuses absent or foreign bindings.
Copies retain both sets of live reservations. Freely detached manifest/subvalue
copies transfer storage responsibility to the caller. The value proves JSON schema
and metadata/source association; process/view/corner selection remains with
[Profile values](../../PDKCore/Profile/DESIGN.md) and admission.

```text
explicit root + exact reference / candidate descriptor + shared accountant
    -> bounded capture / same-read discovery -> root cleanup completed
        -> bounded document decoder -> full input reference comparison
            -> retained capture + decoded document -> final deadline/cancel check
```

No referencer, pathname reopen, Data conversion or ordinary JSONDecoder participates.
Format/input errors, source errors, decoder errors, resource errors and complete
expected/observed reference disagreements remain typed. Cancellation is preserved,
including paired source cleanup causes. Source comparison work is admitted before
comparison; neither a custom capture nor a custom decoder can substitute a different
input while publishing a successful pair.

The existing `PDKManifestLoading` contract continues to own inventory/caller
compatibility; the profile path explicitly selects the invocation-bounded capability.

### Audited caller-owned byte decoding and manifest validation

This additive path reuses the existing syntax scanner and typed decoder. It
does not reopen a path, copy the input, recapture a source, or introduce another
JSON/schema implementation. The concrete native decoder adds this overload:

```swift
public func decodeAudited<Value: Decodable & Sendable>(
    _ type: Value.Type,
    bytes: borrowing Span<UInt8>,
    accounting: any PDKAdmissionResourceAccounting,
    rejectUnknownFields: Bool,
    validate: (any Decoder) throws -> Void
) throws(PDKControlledDecodeFailure) -> PDKDecodedDocument<Value>
```

The caller retains its original byte owner throughout the synchronous borrow.
The parser's pointer cannot escape; returned strings/collections own their
separately admitted storage. This raw-byte overload always returns
`sourceReference == nil`. Nil grants zero capture, artifact, integrity or origin
authority. A caller such as Timing must keep its own verified input identity and
owner. Existing captured-source operations remain unchanged and retain their
complete source reference. Neither path can manufacture a checked capture.

The existing generic limitations still apply: custom `Decodable`, `CodingKey`,
validation hooks and collection families other than the audited Array/Dictionary
paths must admit their own derived payload and work. The decoder is not a
generic whole-invocation allocation certificate. Detached value/subvalue copies
transfer storage responsibility to their caller; retained document copies share
the original reservations until the last owner disappears.

The existing concrete native decoder also implements the additive protocol:

```swift
public protocol PDKControlledManifestDecoding: Sendable {
    func decodeAndValidateManifest(
        bytes: borrowing Span<UInt8>,
        accounting: any PDKAdmissionResourceAccounting
    ) throws(PDKControlledDecodeFailure) -> PDKControlledManifest
}
```

`PDKControlledManifest` has no public initializer or Codable conformance. Its
read-only `manifest: PDKManifest` and `validation: PDKManifestValidationReport`
are backed by private `PDKDecodedDocument` owners for decoded and validation
storage. Copies retain both owners. A validation finding is an ordinary domain
result; `isValid == false` does not become decode success-with-defaults, an
artifact identity, process qualification or a source-authentication claim.

```text
caller-owned bytes + SAME PDKAdmissionResourceAccounting
    -> existing iterative JSON / existing PDKCore DTO decoding
    -> PDKCore's SAME manifest rules with controlled construction events
    -> retained decoded payload + retained report/findings
    -> final shared cancellation/deadline check -> immutable owner
```

Core owns DTO normalization and manifest validation accounting under
[PDKCore](../../PDKCore/DESIGN.md#controlled-manifest-construction-and-validation).
This component adapts those construction events to its existing accounting scope
and retains their leases. No Timing/Logic import, new accounting protocol,
neutral reader framework, second ledger or guessed source-byte multiplier is
introduced. Framework-private parsing/collection runtime workspace, allocator
rounding/object headers and process RSS remain outside logical payload claims;
owned DTO/collection/string/finding payload and explicit construction workspace
remain inside them.

`PDKBoundedDecodingTests` owns public raw-span dispatch, unknown nested fields,
exact sourceReference absence, tiny-capacity/huge-array pre-growth refusal,
escaped strings and dictionaries, custom DTO normalization, cumulative work and
cancellation, ordinary decode/validation fact parity, invalid schema and
last-copy release. Existing captured-source identity tests remain unchanged.
Timing/Logic runtime owners separately prove their original-accountant bridges,
custom DTO work, identity propagation and actual consumer execution.
[PDKDiscoveryTests](../../../Tests/PDKDiscoveryTests) owns real-file exact/discovered
loading, tamper refusal, foreign descriptor binding refusal, shared-owner lifetime,
cumulative decode refusal and terminal cancellation. This component has native
proof only; normal graph adoption and profile consumer composition remain separate.

### Controlled failure retention

Only the new raw-byte audited and controlled manifest APIs throw
`PDKControlledDecodeFailure`: a Sendable Error value with read-only
`cause: PDKBoundedDecodeError` and private reservation storage. It has no public
initializer or Codable conformance. Existing captured-source signatures and
legacy failure behavior remain unchanged. The cause preserves the original typed
error; it is not rewritten as a string or a static substitute.

```text
pre-admit failure metadata -> same decode/validation accounting scope
    -> success: reservations move into the returned value owner
    -> failure: existing reservations move into the thrown failure owner
        -> copied failures share reservations -> last copy refunds
```

The failure metadata is admitted before source parsing/materialization. A refusal
before that admission preserves the upstream typed cause exactly. The trusted
accountant/caller owns its already-materialized error backing; there is no
PDK-owned decoded input payload before parsing. Only a new owner-created
unexpected fallback uses a fixed static cause. Failure
transfer moves existing receipt storage without asking the caller to reserve or
check cancellation after failure. Input-derived Strings in a manifest/profile
cause remain admitted while the failure or a copy is retained. Temporary parser
workspace unwinds normally. Detaching `cause` or a String subvalue transfers its
storage responsibility to the caller, as detaching a success DTO does. This is a
managed source-payload lifetime contract, not a claim about Swift Error boxing,
allocator headers, arbitrary caller-owned causes or Foundation-private workspace.
The controlled manifest entry keeps decoded payload and validation in one
retention scope until either final publication or failure transfer.

[ControlledFailureRetentionTests](../../../Tests/PDKBoundedDecodingTests/ControlledFailureRetentionTests.swift)
uses the public raw entry, a long input-derived invalidAssetPath cause and copied
failures to distinguish premature refund from last-copy release. The prior
17-test success receipt predates this failure-boundary correction.
