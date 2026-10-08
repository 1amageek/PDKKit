# PDK CLI Core

## Purpose and Scope

Parent: [PDKKit](../../DESIGN.md). Child:
[ProfileCommands](ProfileCommands/DESIGN.md). Own standalone command routing,
terminal delivery and explicit command scope. The existing inventory commands are
implemented; the profile command child is an implementation contract, not evidence
that the executable already implements profile admission.

## Responsibilities and Boundaries

Compose local public APIs without Xcircuite, UI or database storage. Preserve the
scope of inspect, discover, validate, corpus, inspect-view, inspect-rule-deck and
oracle. Profile source acquisition, selection and admission retain their lower
owners. CLI output completion includes actual terminal or artifact delivery.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKKit](../../DESIGN.md) | parent | Standalone API/CLI composition | Package owner | No qualification implication |
| [ProfileCommands](ProfileCommands/DESIGN.md) | child | Candidate, plan, admission and replay lifecycle | Profile invocation owner | One accountant through final delivery |
| [Validation](../PDKValidation/DESIGN.md) | depends on | Inventory validation | Existing validate command | Inventory completion is a different scope |
| [Admission](../PDKProfileAdmission/DESIGN.md) | depends on | Checked profile admission | New profile command composition | Wire claims cannot mint admitted values |

## Architecture

```text
executable argv -> command dispatch
    -> existing inventory command -> existing inventory result delivery
    -> ProfileCommands -> owned bounded output -> checked terminal/artifact sink
```

## Contracts and Invariants

Every command reports its evaluated scope. New profile envelopes distinguish
candidate-definition, selection-plan, admitted-profile and replayed-profile;
inventory validation reports inventory. A plan is a `PDKProfilePlan`, not an
admitted selection claim. Only checked admission can supply a profile claim.
Inspection skip flags do not apply to profile commands.

The current `PDKKitCLIJSONCoding` reads with `Data(contentsOf:)` and encodes through
`JSONEncoder`, `String` and a later `Data` conversion. The current invocation
result retains raw Strings and the executable writes without a fallible sink
contract. These paths are inventory behavior and provide no whole-invocation
profile resource or delivery proof. Profile dispatch uses the child-owned bounded
path; a compatibility String projection must retain its charged owner and count
its concrete copies while they coexist.

Exit 0 requires completion of the reported command scope and successful final
delivery. Exit 1 means invalid CLI/configuration or output delivery failure; exit 2
means failed, blocked or cancelled profile execution. Cancellation remains its own
terminal reason. No source, encode, cleanup, output or deadline failure can produce
exit 0. A caller that collects a bounded result in memory still retains its output
owner; `run` verifies the actual stdout write before returning its final exit code.

## State, Ownership, and Lifecycle

Command state is invocation-local. Retained profile output owns its charged bytes
and lower decoded/admitted owners through final-copy release. The executable owns
the terminal sink and closes invocation admission after delivery or terminal
failure. No global cache, background task or target-specific synchronization branch
is added. Sink I/O executes outside accounting locks.

## Failure, Concurrency, and Constraints

The profile child owns bounded failure serialization, including a fixed terminal
diagnostic reserve established before payload work. Delivery failure is reported
through a fixed bounded stderr record when available; failure of both sinks still
returns nonzero. A partially written stdout frame is incomplete evidence and is
never a completed output artifact. Blocking writes require the outer process
timeout; cooperative deadline checks reject late success but do not claim kernel
I/O preemption.

## Verification and Change Impact

Existing [PDKCLITests](../../Tests/PDKKitTests/PDKCLITests.swift) own inventory
compatibility. A dedicated profile CLI test target must exercise the actual command
composition and the real executable with timeout-bounded subprocesses. The child
defines its falsifications. Test sink injection additionally proves short writes,
write failure and refusal before variable output growth. Package/master indexes
and SwiftPM DESIGN exclusions must be updated when this component is adopted.
