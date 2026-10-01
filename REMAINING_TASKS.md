# PDKKit Remaining Tasks

Updated: 2026-10-01

Manifest, discovery, inspection and evidence-handoff slices are implemented.
LEF inventory inspection is not complete executable process semantics.
The active cross-package graph is [LSI PROGRESS.md](../PROGRESS.md).

## Remaining tasks

| ID | Priority | Owner | Task | Exit criteria |
|---|---|---|---|---|
| PDK-1 | P1 | PDKKit | Preserve process-relevant LEF layer, cell/pin, site and via/contact meaning in typed standard-view IR. | Consumers receive exact source-bound numeric/geometry semantics with units, mapping and explicit unsupported/loss diagnostics. |
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
