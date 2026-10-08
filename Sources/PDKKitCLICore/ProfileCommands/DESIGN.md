# Standalone Profile Commands

## Purpose and Scope

Status: implementation contract. Parent: [PDK CLI Core](../DESIGN.md). No children.
Own candidate authoring, exact planning/admission, retained-claim replay and bounded
operational output. All profile command sources belong in this component directory.
The borrowed-span budget parser, native file acquisition/operational intake and
cooperative output owners are implemented and behaviorally verified. Complete
profile dispatch/composition remains implementation work.

## Responsibilities and Boundaries

Translate explicit command inputs into existing checked lower values. Keep physical
availability separate from exact semantic identity. Compose format-owned grammar
and facts; do not parse include syntax here. Do not perform numerical execution,
qualification, approval, publication to a database or profile repair on admission.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [CLI Core](../DESIGN.md) | parent | Dispatch and terminal exit | Standalone surface | Delivery is part of completion |
| [Profile values](../../PDKCore/Profile/DESIGN.md) | depends on | Checked definitions, plans, claims and budgets | Existing semantic/wire authority | Budget and host paths stay outside identity |
| [Manifest loading](../../PDKDiscovery/ManifestLoading/DESIGN.md) | depends on | Bounded same-read decode and exact load | Captured immutable inputs | Legacy JSONDecoder is not the bounded boundary |
| [Candidates](../../PDKDiscovery/CandidateDiscovery/DESIGN.md) | depends on | Explicit-root bounded candidate discovery | Optional manifest candidate search | Candidates require explicit selection |
| [Capture](../../PDKSourceCapture/LocalCapture/DESIGN.md) | depends on | Candidate discovery and exact capture | Root-capability acquisition | No cwd/environment or symlink fallback |
| [Admission](../../PDKProfileAdmission/Admission/DESIGN.md) | depends on | Checked selection and admission | Required source closure/facts | CLI keeps the shared accountant open through output |
| [SPICE adapter](../../PDKSpiceProfileInspection/DESIGN.md) | depends on | Real grammar and cooperative work | Active dependencies and source facts | Discovery requires a grammar-owned discovery entrypoint |

## Architecture

```text
fixed bounded budget bootstrap
  -> one invocation accountant + reserved terminal/output completion capacity
  -> bounded operational intake + explicit roots/bindings
       propose: candidate acquisition -> grammar traversal -> draft definition
       plan: exact definition + exact manifest -> pure selection
       admit: exact bindings -> checked source/fact closure -> admitted claim
       replay: retained claim + exact definition -> re-admit -> full claim comparison
  -> reserved bounded encoding -> owned output -> fallible delivery -> close
```

## Contracts and Invariants

### Inputs and command scopes

All commands require `--budget` and explicit root/source availability. Relative
paths are checked `ArtifactRelativePath`; roots are `PDKProfileAuthorizedRoot`.
Use a CLI-owned operational availability document for existing exact bindings,
root bindings and `PDKProfileSourceBinding` values. This document has strict schema
1, required fields, checked construction and bounded decoding. Its URLs, per-source
capture policy and runtime bindings never enter Core selection identity.

The native command surface is:

```text
profile <propose|plan|admit|replay> --input-root <absolute directory> --input-root-id <id> --budget <relative path> --availability <relative path> --availability-sha256 <hex> --availability-bytes <UInt64>
propose additionally: --authoring <relative path> --authoring-sha256 <hex> --authoring-bytes <UInt64>
```

Input root/ID and budget-path setup belong to the bounded bootstrap exception;
other option conversions/copies wait for the one profile accountant. Unknown and
duplicate options fail. The raw argument count is bounded at 20 from six common
and three propose flag/value pairs plus the two command words; it adds no new
semantic limit. Operational full descriptors are fixed by
`PDKProfileCLIAvailability.artifactDescriptor` (input / pdk.profile-availability /
JSON) and `PDKProfileCLIAuthoring.artifactDescriptor` (input / pdk.profile-authoring /
JSON). Expected SHA-256 and byte counts come from explicit arguments, not decoded
operational JSON. Document total capture capacity derives from that exact count;
pages/work/duration derive from the selected invocation limits and existing native
page policy. Bootstrap uses the selected policy's single-page bound. No cwd,
environment root or default identity substitutes for these inputs.

| Command | Required semantic input | Completion result |
|---|---|---|
| `profile propose` | Explicit profile ID, required corner IDs, ordered search routes, inspection policy, checked `PDKViewRequirement` values; selected manifest availability; candidate source bindings | Draft `PDKProfileDefinition` and candidate source evidence, never admission |
| `profile plan` | Exact definition binding; exact manifest availability; shared resources | Checked `PDKProfilePlan`, selection scope only |
| `profile admit` | Existing `PDKProfileAdmissionRequest` values, inspector registry and shared resources | Checked admitted profile claim, exact evidence and execution observations |
| `profile replay` | Exact retained `PDKProfileClaim` binding plus definition/manifest/source availability and chosen operational budget | Re-admitted profile whose entire checked claim equals the retained claim |

Propose needs an authoring input because `PDKProfileDefinition` requires exact
references before construction. A candidate source entry contains only source
key, optional asset ID, explicit `ArtifactDescriptor`, logical routes and the
corresponding existing source availability bindings. It carries no fabricated
reference. Its minimal checked request also carries the explicit profile inputs
listed above; process ID/version and manifest reference come from the same captured
selected manifest. The CLI owns this authoring schema 1; the current Core profile
definition schema and required fields are owned by
[Profile values](../../PDKCore/Profile/DESIGN.md#encoding-v1-and-public-boundary).
The first native SPICE command scope fixes root preprocessing inputs to the empty
environment. Propose obtains the CoreSpice-owned empty-entry fingerprint under the
selected semantic policy and supplies the required `initialPreprocessingIdentity`
when constructing the draft. This scope adds no caller parameter environment or
corner override. Every route is explicitly authorized; duplicate/conflicting source-key,
asset, descriptor or route bindings are rejected before source acquisition.

Candidate bytes use `PDKLocalSourceDiscovering` and the same accountant. If manifest
search is requested, `PDKBoundedDiscovering` supplies candidates, and the caller must
select one explicitly; first candidate ordering is not selection authority.
SPICE discovery uses the same CoreSpice parser with a discovery-mode provider over
the approved candidate routes. Newly observed child identities and ordered active
edges appear only in the draft output; unknown/escaping/ambiguous routes fail.
Construct the existing checked definition only after this candidate graph is
complete. Adopting it is an explicit later input to plan/admit, never an automatic
retry after exact dependency drift. No complete exact seed definition is required.

Plan captures/bounded-decodes the exact definition and loads its own exact
`manifestReference` with `PDKBoundedManifestLoading.loadExact`. Pass the retained
decoded definition, loaded manifest/reference and same accountant to
`PDKProfilePlanningRequest`. It checks declared selection, not source grammar or
dependency closure. Admit reloads its own exact definition and manifest through
the checked admitting API. Any additional read/decode required by CLI intake is
charged to the same counters; a path re-read is never used to authenticate earlier
bytes. Reuse immutable captures where the lower public boundary supports it.

Replay bounded-decodes the retained claim, takes its exact `definitionReference`,
reopens only explicit availability and re-admits using that reference. Compare all
claim fields and recomputed semantic identity under the same accounting owner.
Changing a source, corner, section, descriptor, policy or edge blocks replay.
Relocating identical bytes under explicit roots preserves semantic identity.
Decoding or matching a serialized digest alone cannot complete replay.

### Budget bootstrap and invocation ownership

The sole pre-budget exception is the selected budget configuration. CLI composition
owns an immutable bootstrap policy chosen before configuration input is read.
Its allowed bounds are positive finite UInt64 byte counts representable by the
host buffer capacity; overflow and an unrepresentable capacity are rejected.
Choose the default from the verified maximum current schema/dimension vocabulary,
full UInt64 decimal widths and an explicit finite whitespace allowance. A 16,384-byte
default is permissible only after that sizing fixture and oversize-refusal behavior
are verified; it is a host policy default, not a universal correctness constant or
Core semantic field. Enforce the selected bound before the single immutable input
buffer read. Its grammar accepts only the existing `PDKAdmissionBudget` schema,
known finite field/dimension vocabulary and checked UInt64 values. No arbitrary
string collection, generic unbounded decoder or whole-file allocation participates.
Reject extra bytes, duplicate/unknown keys, unsupported schema/accounting version,
overflow and incomplete/nonpositive limits. Record bootstrap byte/work/storage
observations separately in operational evidence. This exception does not admit
profile, manifest, availability, authoring, claim or source data. The fixed limit
is CLI configuration policy, not a foundry source ceiling. A policy change requires
the sizing, capacity-boundary and oversize-refusal proofs to be rerun against the
complete current dimension vocabulary.

The schema-1 budget wire uses `limits` as an alternating array of dimension string
and UInt64 value, not a JSON object. The fixed current vocabulary contains 21
dimensions. Require each exactly once before checked Core construction; the
standard Dictionary decoder's last-value-wins behavior is not the bootstrap
contract. Root fields are `schemaVersion`, `accountingVersion`, `limits` and
`maximumElapsedNanoseconds`, each required once. Accept field/dimension permutation,
JSON whitespace and ASCII `\uXXXX` escapes for the known vocabulary; reject all
other keys, duplicate dimensions, odd arrays, negative/fractional/exponent/overflow
numbers and trailing payloads.

The independent `PDKBudgetBootstrapDecoding` requirement takes a borrowed
`Span<UInt8>` and checked `PDKBudgetBootstrapPolicy`, returning a checked budget
and bootstrap observations. The native cursor retains no span or pointer and
constructs only fixed-vocabulary key scratch and the bounded 21-entry limit table.
This entry owns typed parsing, not file acquisition or full CLI completion; the
later bounded file reader retains its immutable input owner. Observations report input
bytes, scanned work and managed dimension-entry capacity, not process RSS.
The standard 16,384-byte policy admits the verified maximum 2,524-byte fully
ASCII-escaped wire plus at most 13,860 bytes of JSON whitespace. Its sizing test
uses all current dimensions and UInt64 widths and refuses one extra byte. Custom
positive host-representable policies apply the same complete grammar and refuse
oversized spans before parsing or key/limit storage construction.

After bootstrap, create one `LocalPDKAdmissionResources` at one monotonic start.
All variable command argument copying, operational/config intake, discovery,
capture, decode, selection, grammar, comparison, encoding and delivery share it.
Arguments originally provided by the process are caller-owned input; copied
arrays/strings are charged. Budget configuration observations remain separate and
never reset or refill this invocation. Reserve bounded terminal diagnostics before
payload work. No stage creates another accountant or restarts the elapsed clock.

The shared-accountant admitting entrypoint must be a protocol requirement accepting
the existing request plus `PDKAdmissionResourceAccounting`. It does not close an
external owner. Existing `admit(request)` may create/close its own native owner for
standalone library use. CLI is the owner of `close()` after terminal delivery.
The trusted external owner's configured limits/accounting version must correspond
to `request.budget`, as required by the lower
[Admission contract](../../PDKProfileAdmission/Admission/DESIGN.md). CLI passes the
same checked budget to both owner construction and request construction. The shared
entrypoint cannot silently ignore a conflicting request budget or reset counters.
Native operational observations use the read-only
[admission-owned snapshot contract](../../PDKProfileAdmission/Admission/DESIGN.md#native-invocation-observations).
CLI consumes that evidence without changing admission authority.

### Bounded output and evidence

Profile output has a CLI-owned schema 1 with command, scope, terminal status/reason,
completed phase, exact input/evidence references, command-specific definition/plan/
claim, inspection policy and operational budget observations. Paths and bootstrap
observations remain operational fields. Domain failures preserve typed phase,
requirement/corner/source/edge and expected/observed identities when available.
Static terminal failure remains visible when variable diagnostics are exhausted.

Encoding cooperates with the same accountant. Reserve concrete output capacity
before growth; charge traversals, escaping, numeric formatting and any temporary
copy. Retain immutable input owners while encoding their borrowed values. Use
current checked value codecs through a cooperative writer/encoder; ordinary
JSONEncoder followed by measuring the result is not pre-admission. Encoding itself
does not change Core canonical identity or wire schemas.

Before reporting observations, finish variable payload encoding and reserve all
bounded suffix/delivery capacity. The envelope identifies the observation boundary
as prepared-output; it covers that capacity, not a fictitious post-write timestamp.
Perform the final deadline/cancellation check after actual delivery. A sink failure
or late completion returns nonzero and supplies bounded failure evidence. If an
artifact sink is selected, close/flush succeeds before its immutable reference is
reported; partial artifacts are incomplete and cannot carry completed status.
Readers accept a successful stdout envelope only together with process exit 0;
an envelope written before a late delivery/deadline failure is provisional and
cannot be retained as completed admission evidence. In-process collectors require
the returned checked delivery outcome and retained owner instead of process exit.

## Runtime Flows

### Command Composition and Legacy Dispatch

`PDKProfileCommandExecuting.execute(arguments:argumentStart:standardOutput:standardError:)`
is the public asynchronous composition boundary. It consumes the existing argument
array at the explicit start index and returns `PDKProfileCommandResult`. The native
implementation injects input loading, capture/discovery, audited decoding, manifest
loading, candidate discovery, admission, clock, encoding and delivery through their
public protocols. Its fixed registry composes the existing native SPICE and JSON
inspectors under the requested inspection policy.

`PDKKitCLI.run` selects profile dispatch before any legacy argument-array copy and
uses native Span-based POSIX output sinks. The executable passes the original
`CommandLine.arguments` and explicit start index. Bootstrap or option failure before
accountant construction writes only a finite static failure through checked sink
byte counts and finish; no variable error formatting occurs at that boundary.
Reserved terminal bytes remain available after exhaustion and always produce a
nonzero result, without a successful admission or delivery check.

The immutable command result retains its owned output, typed failure, decoded
operational inputs, bootstrap source and resource leases. The command accountant
closes only after terminal delivery has been determined. The legacy `invoke` route
uses an in-memory receipt sink that acknowledges borrowed bytes without copying;
its profile invocation result retains the command result and leaves legacy output
strings empty. Consumers borrow the owned profile output. Existing non-profile
invocation values and equality remain unchanged; profile equality compares immutable
invocation-owner identity, not semantic claim equality.

### Cooperative Encoding and Delivery Owner

`PDKProfileOutputEncoding` owns `reserveCompletion(resources:policy:)` followed by
`prepare(_:completion:)`. Completion reserves the fixed terminal failure envelope
before payload work; retaining the completion keeps it available after payload
failure. Preparation runs the existing trusted cooperative `Encodable` witnesses
through a native bounded Encoder, then writes their current JSON schema into owned
bytes. Keyed/unkeyed/single-value containers, exact integers, finite floating-point
values and UTF-8 escaping preserve the current wire semantics. Key order is witness
order, not canonical identity. Invalid container use, nonfinite numbers and codec
errors fail explicitly. Codec-supplied input values/strings remain caller-owned;
Resource failures remain sticky, including nonthrowing container operations.
new encoder nodes, container/path capacity, numeric scratch, output capacity and
traversal/copy/escaping work are admitted before allocation or work. Native allocator
rounding and receipt bookkeeping remain implementation overhead, not an RSS claim.
Native floating-point numeric scratch is bounded at 32 bytes: finite IEEE Float64
uses at most 17 significant digits and 24 characters including sign, decimal point
and exponent; integer decimal conversion uses at most 20 characters.

Preparation accepts a keyed envelope whose `operationalObservations` field is absent.
It reserves a second complete destination buffer, body-copy work, finite suffix
capacity/work and numeric scratch before returning immutable prepared bytes.
`PDKPreparedProfileOutput.complete(observations:)` consumes an exactly-once token
under Mutex, then uses those reservations to copy the envelope and add the one
fixed `operationalObservations` field. Prepared copies cannot create independent
buffers under one reservation. Output bytes are never shared mutably. This field
accepts only `PDKProfileOutputObservations(snapshot:bootstrap:)` and contains
`boundary: prepared-output`, the admission-owned snapshot and separate parser
bootstrap counters (`inputByteCount`, `scannedWorkUnitCount`,
`dimensionEntryCapacity`). Separate prebudget acquisition observations belong to
the command envelope body. Its fixed native vocabulary includes every current dimension,
limits, cumulative totals or live current/peak, accounting version, closed/deadline
flags and checked elapsed/max-elapsed UInt64 nanoseconds. An unrepresentable elapsed
sample fails explicitly. The standard completion policy derives its finite bound
from current fixed ASCII vocabulary and full UInt64 decimal widths; positive
host-representable custom bounds must fit the same maximum representation. No
reservation is made after this prepared boundary. Snapshot is evidence of prepared
capacity; it is not a successful delivery or final deadline check.

`PDKOwnedProfileOutput` lends a Span and shares immutable storage/receipts until its
last copy is released. `PDKProfileOutputSink` owns fallible `write` returning an
actual byte count and `finish`; sink implementations own flush/close semantics.
`NativePDKProfileOutputSink` supports Darwin descriptors. Before each scoped Span
write it requires successful per-descriptor `F_SETNOSIGPIPE` configuration; a closed
pipe or configuration/write failure returns typed `writeFailed`. This does not
change process-wide signal handling. The non-Darwin branch immediately refuses
with `writeFailed` and an `INCOMPLETE_IMPLEMENTATION` marker until a verified
SIGPIPE-safe descriptor writer exists. No Linux runtime support is claimed.
`PDKProfileOutputDelivering.deliver(_:to:)` rejects short/invalid writes,
requires finish, then performs the original output-held accountant's final check.
The delivered value retains the output owner and establishes this delivery only;
the command owner determines exit status and closes its accountant. A failed or
late write cannot yield a delivered value or completed artifact. Resource failures
retain their original typed cause; sink and codec failures remain typed without
unbounded error-string formatting. Static terminal output is already reserved and
can be lent to the sink even after exhaustion; it never claims successful admission.
Generic encoding/delivery never closes or creates another accountant.

| State | Owner / isolation | Mutation | Release |
|---|---|---|---|
| Encoder tree, paths and writer | One synchronous call / exclusive local state | Checked witness/container methods | Encoding end or failure |
| Prepared completion token | Completion owner / Mutex | Exactly-once take; no callback under lock | Failed completion or final output owner |
| Output bytes and receipts | Immutable Sendable owner | None after freeze | Last prepared/owned/delivered copy |
| Sink progress | Injected sink | Actual write and finish outside accountant locks | Sink-owned finish contract |

`PDKProfileOutputTests` owns exact Core-codec roundtrips, escaping/numeric fidelity,
preallocation refusal, cumulative work across fields, prepared-boundary no-reserve,
suffix maximum sizing, copy/final-owner release, duplicate completion refusal and
short/failed/late/cancelled delivery. Evidence is native host only. CLI dispatch,
actual stdout routing and complete command-envelope policy remain composing work.

```text
bootstrap -> resources -> input -> selected command -> payload encoding
    -> snapshot + bounded suffix -> delivery -> final check -> terminal exit
failure/cancel -> await owned cleanup -> bounded terminal diagnostic -> nonzero exit
```

## State, Ownership, and Lifecycle

### Operational intake realization

`PDKProfileCLIInputLoading` owns three protocol requirements. `loadBudget` takes
one checked authorized root, relative path, bootstrap policy and finite
`ArtifactAccessBudget`; it returns `PDKLoadedBudgetBootstrap`. The acquisition's
total byte limit equals the bootstrap policy. It uses the public secure
root discovery operation and awaits shutdown before parsing/publication. Its
retained observed source and separate acquisition/parse observations never enter
the later profile accountant. No budget file establishes another profile deadline.
Both page and total acquisition limits must equal the selected bootstrap bound;
an incompatible policy is rejected before root open. Foundation's fixed
`SourceDiscoveryReader` caps data pages at 1,048,576 bytes, so this native file leaf
explicitly refuses larger policies as unsupported single-page acquisition before
I/O. The independent Span parser retains its host-representable policy contract.
The standard 16KiB file scope owns one immutable data page and lends a zero-copy
contiguous borrow. Bootstrap owned capacity includes that payload and the exact
page/retention slots; read/hash/page/work and current/peak capacity observations
are separate. Native `openat` path-name scratch is observed as temporary capacity;
the single-page borrow adds no temporary input copy. The reader's resource-control
state is one fixed Mutex-protected record. Reservation handles release at their
last copy; no resources callback runs under its lock.
The native composition default reuses `PDKSourceCapturePolicy.defaultBudget`'s
public work and duration limits (currently 4,100 units and 30,000,000,000
nanoseconds), with page/total bytes equal to the selected bootstrap bound and
maximum page count 1. An explicitly injected checked override remains finite,
positive and single-page. This host acquisition selection is an operational
policy owner/rule, not a Core semantic constant. Changes recheck the standard real
read, pre-read oversize/capability refusal and executable boundary evidence.
`loadAvailability` and `loadAuthoring` take an exact document binding, its explicit
authorized root and the existing invocation accountant. They capture exact bytes
and use `NativePDKBoundedDocumentDecoder.decodeAudited`; the returned
`PDKDecodedDocument` retains all decode/checked-construction backing.

The availability schema has exactly `schemaVersion`, `roots`, `definition`,
`manifest`, `sources`, `claim`, and `inspectionPolicyIdentity`. Definition and
claim are required nullable keys; manifest is nonnull. Command composition owns
which nullable binding a command requires. Roots carry `rootID` and absolute
`directoryPath`. Exact bindings carry `reference`, `rootID`, `relativePath` and
`budget`; source bindings additionally carry `sourceKey` and `logicalRoute` and
do not carry another reference. Relative paths are arrays of checked segments.
Each access budget carries the five existing ArtifactAccessBudget fields, without
a new semantic budget or synthesized defaults. Nested operational records also
carry schemaVersion 1 and require every declared field.

Authoring schema has exactly `schemaVersion`, `profileID`, `requiredCornerIDs`,
`requirements`, `orderedSearchRoutes`, `inspectionPolicyIdentity` and
`candidateSources`. A candidate carries `sourceKey`, required nullable `assetID`,
`descriptor`, `logicalRoutes` and `bindings`. Bindings use the source-binding wire
above; all aliases for a candidate identify the same explicit physical root/path
and policy. Candidate and root IDs/routes are preflighted with cooperative work
before invocation use. Catalog selection, corner/context entry selection and
draft construction belong to command/format composition, not operational intake.

Intake rejects unknown/missing/duplicate fields, obsolete schemas, duplicate root
or source/route identities, contradictory descriptor/binding aliases, unknown root
IDs, nonabsolute roots, invalid relative paths and nonfinite source policies.
Constructor loops, comparisons and Foundation conversion capacities are admitted
through the decoder's accounting context before execution. Source/decoded owners
must be retained while their raw fields are borrowed. Static bookkeeping and
native allocator/URL implementation overhead do not constitute an RSS guarantee.

Decoded operational inputs, candidate documents, captures, plans and admitted
profiles retain their original charged owners until output release. New output
capacity is a separate owner, not a raw String escaping its receipts. Copies retain
the same receipt; actual new backing is separately admitted. All tasks are joined
before encoding; no AsyncStream or background writer is required. Native counter
state stays in its existing Mutex, and traversal state stays in its lower actors.

## Failure, Concurrency, and Constraints

Required format/accounting capability absent from a registry is blocked. Propose
also blocks until CoreSpice provides grammar-owned discovery with checked candidate
acquisition; its exact-only intake cannot be repurposed by suppressing expected-edge
checks. Bounded operational decode and output support are prerequisites for profile
CLI success. Unsupported capability is explicit and never falls back to legacy
JSON/file helpers. Cleanup and output failures preserve the primary cause.

## Verification and Change Impact

The dedicated profile CLI owner verifies real propose -> explicit adoption -> plan
-> admit -> replay using supported SPICE and non-SPICE fixtures. Falsifications
include new/extra/missing/changed dependencies, false selected sections/PVT,
unsupported required fact/grammar, manifest/definition/claim drift, root relocation,
unknown operational schema, oversized bootstrap, cumulative exhaustion spanning
intake and output, output pre-allocation refusal, retained-output last-copy lifetime,
cancel/cleanup failure and failed/short terminal writes. The actual executable runs
with timeouts and nonzero method execution. Inventory tests remain separate.
Lower evidence is reused until its assumptions change; no numerical/foundry,
WASM/Embedded or qualification claim follows from these host command proofs.

[`BudgetBootstrapTests`](../../../Tests/PDKBudgetBootstrapTests/BudgetBootstrapTests.swift)
owns the standalone typed bootstrap parser proof: real Core codec wire, UInt64
maxima, field/dimension permutation, fully escaped current vocabulary and selected
capacity boundary, duplicate/unknown/incomplete inputs, numeric/version refusal,
nonpositive limits and cancellation. Native Swift 6.4 scope covers 9 distinct
methods (initial 8-method product plus the targeted final 2-method correction).
These methods prove no budget-file read, sink delivery or complete profile command.
