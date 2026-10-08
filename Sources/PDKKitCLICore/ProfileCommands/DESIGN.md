# Standalone Profile Commands

## Purpose and Scope

Status: implementation contract. Parent: [PDK CLI Core](../DESIGN.md). No children.
Own candidate authoring, exact planning/admission, retained-claim replay and bounded
operational output. All profile command sources belong in this component directory.
The borrowed-span budget parser is implemented and behaviorally verified. File
acquisition and complete profile dispatch/output remain later implementation work.

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
Core semantic field. Enforce the selected bound before each read into one bounded
owned buffer. Its grammar accepts only the existing `PDKAdmissionBudget` schema,
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
later bounded file reader owns its one input buffer. Observations report input
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
Native accounting exposes a read-only fixed-size observation snapshot with each
cumulative total, live current/peak, limits, accounting version and elapsed sample;
observations do not authorize new work or change admission decisions.

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

```text
bootstrap -> resources -> input -> selected command -> payload encoding
    -> snapshot + bounded suffix -> delivery -> final check -> terminal exit
failure/cancel -> await owned cleanup -> bounded terminal diagnostic -> nonzero exit
```

## State, Ownership, and Lifecycle

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
