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
| [PDKSourceCapture](../PDKSourceCapture/DESIGN.md) | Depends on | Exact immutable admitted bytes | Manifest input | Identity materialization and parser allocations have separate owners |
| [PDKStandardViews](../PDKStandardViews/DESIGN.md) | Depends on | Manifest-bound typed evidence | Cross-view and rule checks | Failed/cancelled/blocked checks cannot become completed |

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
available. Existing request/result schemas and diagnostic categories remain.

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
