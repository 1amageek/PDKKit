# PDKKit Remaining Tasks

Updated: 2026-07-26

PDKKit is complete for its canonical manifest, standard-view inspection,
rule-deck inventory, corpus, oracle, and evidence-handoff contract.

## Remaining tasks

| ID | Priority | Owner | Task | Exit criteria |
|---|---|---|---|---|
| PDK-1 | P2 | PDKKit | Broaden vendor-specific SPICE, Liberty, mask-view, and rule-deck semantic coverage. | Newly supported constructs produce parser-backed typed observations, cross-view validation, negative fixtures, immutable oracle expectations, and no hash-only or silent-success path. |

## External prerequisites

Provider execution and runtime trust decisions remain outside PDKKit.
Unsupported vendor constructs remain typed blocked results until this optional
semantic envelope is expanded.

## Evidence reviewed

- `README.md`
- `DESIGN.md`
- `INTERFACES.md`
- `IMPLEMENTATION_PLAN.md`
- `MILESTONES.md`
- `GOAL_STATUS.md`
- `Sources` incomplete-implementation marker scan
