# PDKKit Remaining Tasks

Updated: 2026-10-01

Manifest, discovery, inspection and evidence-handoff slices are implemented.
LEF inspection retains typed physical declarations and rejects unretained
grammar; executable process capability still requires native consumer evidence.
The active cross-package graph is [LSI PROGRESS.md](../PROGRESS.md).

## Remaining tasks

| ID | Priority | Owner | Task | Exit criteria |
|---|---|---|---|---|
| PDK-1 | P1 | PDKKit / native consumers | Validate retained standard-owned LEF physical declarations in the required native process profile. | Engines consume exact source-bound layer, cell/pin, site and via/contact semantics with units and mapping; inspection alone does not establish production coverage. |
| PDK-2 | P1 | PDKKit | Close required process-profile coverage across standard views. | Newly supported constructs produce parser-backed typed observations, cross-view validation and behavioral failure evidence; names/counts or hashes cannot prove executable semantics. |

## External prerequisites

Provider execution and runtime trust decisions remain outside PDKKit.
Unsupported constructs remain typed blocked results. Process semantics needed by
the selected native profile are required implementation work, not an optional
qualification asset or provider-execution problem.

## Evidence reviewed

- `README.md`
- `DESIGN.md`
- `INTERFACES.md`
- `IMPLEMENTATION_PLAN.md`
- `MILESTONES.md`
- `GOAL_STATUS.md`
- `Sources` incomplete-implementation marker scan
