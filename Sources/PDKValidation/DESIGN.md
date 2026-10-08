# PDK Validation

## Purpose and Scope

Parent: [PDKKit](../../DESIGN.md). No children in this change. Own manifest
validation and composition of standard-view and rule-deck checks.

## Responsibilities and Boundaries

Own diagnostic/status aggregation and checks against requested process identity,
asset declarations, mappings and corners. Source admission belongs to
PDKSourceCapture; parser semantics belong to PDKStandardViews. Qualification,
tool execution and storage remain outside this module.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKKit](../../DESIGN.md) | Parent | Validation results | Package composition | Validation does not establish process qualification |
| [PDKCore](../PDKCore/DESIGN.md) | Depends on | Asset identity findings and resolver protocol | Authoritative declaration checks | Current availability does not authenticate declarations |
| [PDKSourceCapture](../PDKSourceCapture/DESIGN.md) | Depends on | Exact immutable admitted bytes | Manifest input | Identity materialization and parser allocations have separate owners |
| [PDKStandardViews](../PDKStandardViews/DESIGN.md) | Depends on | Manifest-bound typed evidence | Cross-view and rule checks | Failed/cancelled/blocked checks cannot become completed |
| [Profile admission](../PDKProfileAdmission/DESIGN.md) | planned depends on | Exact profile admission | Required selection and graph closure | Catalog inspection is not profile admission |

## Architecture

```text
expected manifest reference + availability -> source capture -> manifest decode
  -> semantic validation + asset resolution -> view/rule inspectors -> result
```

## Contracts and Invariants

The manifest used for asset selection, process/version checks and semantic
validation must come from the captured bytes matching the request's expected
manifest reference. No later path verification can authenticate an earlier
decoded buffer. Capture failures stop semantic validation before a manifest is
available. Existing validation request/result schemas remain. Asset declaration checks are
owned by PDKCore's asset value. Validation passes each initially resolved reference
as the corresponding view/rule request's expected source and checks the returned
full source reference before incorporating successful evidence. A mismatch or
missing reference is blocked, including from injected implementations. The final
provenance retains the same initial references used by those checks.

```text
initial resolved asset A -> child expected A -> child retained A -> provenance A
                                mismatch -> blocked
```

Failure aggregation is monotonic: failed precedes cancelled, which precedes
blocked, which precedes completed. A returned or thrown cancellation stops the
remaining checks, including the next rule stage. Earlier failures remain visible;
a cancellation is never relabeled as an execution failure.

### Required asset and profile composition specification

Status: proposed correction/migration. Current CLI counterexamples are recorded
in [PROGRESS](../../PROGRESS.md) RA3. Completed identity/capture behavior above
does not yet establish this contract.

VV-01: For inventory validation, effective requiredness is
`asset.required || request.requiredAssetRoles.contains(asset.role)`. Use this same
predicate for identity, resolution/access failure, missing inspection and
diagnostics. A required role must have a declaration; all its declared inventory
assets must meet that requirement. Missing effectively required assets block even
when manifest-required is false. Cancellation stops work, never an optional warning.

VV-02: Distinguish catalog inventory validation, structural view inspection and
exact profile admission in typed results and CLI. PDKCapabilityReport describes
its evaluated inventory scope; a nonempty corner/mapping list cannot advertise
admitted profile availability. Inventory success cannot construct an admitted
profile. Profile requirements cannot be disabled by inspection skip flags.

VV-03: Profile validation composes PDKProfileAdmitting with required view/rule
providers and retains exact claim, inspection policy, budget observations,
diagnostic phase and source evidence. Completed requires every demanded condition.
Existing failed/cancelled/blocked aggregation stays monotonic. Rule-deck text
admission is not executable rule semantics; that capability belongs to its Engine.

VV-04: Profiles declare selected requirements and include manifest-required
support assets. Unused optional assets can remain outside the closure. Consumers
project declared stage requirements rather than executing every file in a large
profile. Names and role counts never replace exact selection.

### CLI and wire migration

Proposed standalone commands:

```text
pdkkit-cli validate --manifest <path> ...
pdkkit-cli profile propose --manifest <path> --requirements <path> --sources <path> --budget <path>
pdkkit-cli profile plan --definition <path> --budget <path>
pdkkit-cli profile admit --definition <path> --budget <path>
```

`validate` reports inventory scope and implements VV-01. `profile propose`
uses explicit authorized source roots/routes and bounded candidate discovery to
emit a draft exact source table/definition. Newly observed includes are candidate
inputs and require explicit definition adoption; this command cannot create
AdmittedPDKProfile or repair an exact-execution mismatch. It uses the same
CoreSpice grammar with discovery-mode acquisition, not an alternate include parser. `profile plan` emits a
non-admitted selection claim; `profile admit` emits a claim/evidence only after
exact closure. Definition-local roots come from explicit availability, outside
semantic identity. Budget files are checked operational policy retained in
execution evidence. No Xcircuite/UI is required. Exit 0 means completed within
the reported scope; exit 2 blocked/failed domain admission; exit 1 invalid
arguments/configuration. Cancellation has a distinct terminal reason and no exit 0.

New profile wire formats start at schema 1. Validation request schema 4 advances
to 5 when scope/profile fields are implemented; result/CLI envelope owners
advance their own schemas at the same time. Migrate callers, fixtures, corpus/
oracle scope and retained readers together. Obsolete/missing scope is rejected
without synthesized identity. Manifest schema 1 and identity schema 2 stay
unchanged unless their owned meaning changes.

## Failure, Concurrency, and Constraints

Invocation-local state has no shared mutation. The capture service and budget
are injected, with the package capture policy as the default. Digest/size mismatch
is blocked; capture cancellation is cancelled; cleanup/budget/access failure is
an explicit blocker with no decoded manifest. Codec conversion is one bounded
copy and is not a zero-copy or parser-resource claim.

## Verification and Change Impact

[PDKSourceAdmissionRegressionTests](../../Tests/PDKKitTests/PDKSourceAdmissionRegressionTests.swift)
and source consumer tests exercise actual capture, post-capture path mutation,
identity refusal, cancellation and cleanup failures. Existing validation, view,
rule, corpus and oracle suites verify result composition. Changes to capture
admission require these callers to be rechecked; qualification remains separate.
