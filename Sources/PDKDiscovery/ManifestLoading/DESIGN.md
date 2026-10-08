# PDK Manifest Loading

## Purpose and Scope

Next implementation sprint design, not implemented capability. Parent:
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

Proposed public API, with one primary type per file in this component:

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

Proposed `PDKManifestLoadingError` distinguishes invalid input, discovery failure,
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

Current implementation facts, not proposed behavior:

| Current path | Evidence |
|---|---|
| Builder decodes one read, then independently references the path | [PDKManifestReferenceBuilder](../../PDKCore/PDKManifestReferenceBuilder.swift) |
| CLI inspect repeats decode/hash split | [PDKKitInspectCommand](../../PDKKitCLICore/PDKKitInspectCommand.swift) |
| Resolved asset can hold divergent digest representations | [PDKResolvedAsset](../../PDKCore/PDKResolvedAsset.swift) |
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

Planned behavioral proof ownership:

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
ManifestView 3 -> 4, RuleDeck 2 -> 3, Oracle 1 -> 2 and PhysicalDesignRequest 6 -> 7.
StandardViewInspectionRequest remains 4 because it carries no PDKReference.
Only new versions of changed envelopes and identity values are accepted;
fixtures, external providers, CLI output and Xcircuite persisted request readers
must migrate together. Corpus schema and manifest document schema do not change.
The implementation must update INTERFACES and owner design links rather than
leave the old projection or builder as an alternate authority.
