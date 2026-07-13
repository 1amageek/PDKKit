# PDKKit Implementation Plan

## Status

The implementation order below is complete through the supported detailed
standard-view numeric semantics, local oracle, qualification-evidence and
PDK-specific runtime integration gates. Complete vendor-specific language
coverage, independent process qualification and release-profile approval remain
open.

## Order

1. Manifest schema and digest validation
2. Discovery providers
3. Cross-view consistency validation
4. Retained PDK corpus contract and deterministic evaluator
5. M4a parser-backed LEF/GDSII/OASIS inspection and manifest binding
6. M4b SPICE/Liberty detailed numeric inspection and manifest binding
7. Immutable reference-oracle correlation
8. Local qualification gate and evidence handoff
9. Process-scoped ToolQualification integration
10. Xcircuite runtime, review and resume evidence

## Implemented slices

- Manifest schema migration and typed process/layer/device/corner semantics.
- Deterministic local discovery and reference digest construction.
- Root-bounded asset resolution, SHA-256 and byte-count verification.
- Cross-view mapping coverage and structured blocked diagnostics.
- Deterministic JSON CLI with inspect/discover/validate/corpus commands.
- Retained positive fixture, isolated negative-path fixture and request/payload round-trip tests.
- Retained corpus suite with valid and blocked expected outcomes, expected finding codes, root-bounded paths, deterministic results and `pdkkit corpus` CLI.
- M4a standard-view contract with canonical LEF/GDSII/OASIS IR, immutable input verification, malformed parser failures, manifest cross-view binding and `pdkkit inspect-view`.
- M4b detailed SPICE/Liberty inspection with numeric model parameters,
  engineering-suffix normalization, subcircuits, cells, timing arcs, timing
  table dimensions/values and unit declarations plus manifest binding and
  unsupported-semantics regression cases.
- M5 immutable manifest-digest-bound oracle expectations, canonical field comparison, structured mismatch blockers and `pdkkit oracle`.
- M6 `PDKQualificationGate` and `pdkkit qualify`, which require matching retained corpus and oracle evidence and stop at `oracleCorrelated`.
- M7 six PDK FlowStageExecutor adapters with immutable stage-envelope
  persistence, agent-facing Codable runtime specs, project-root-bounded artifact
  references, ToolQualification scope enforcement, human approval and resume
  regression coverage.
- Xcircuite discovery/validation/corpus/standard-view/oracle/qualification
  adapters and persistence tests.

## Completion gates

- Public APIs remain protocol-first and Sendable.
- Every unsupported semantic produces a structured blocked result.
- Native and external backends produce the same result schema.
- No UI type enters a public contract.
- No result claims foundry qualification without process-scoped oracle evidence.
- Xcircuite can execute, persist, review and resume the PDK stage without
  circuit-studio.

## M3 evidence gate

`PDKCorpusValidationPayload.isValid` is true only when every declared case
matches its expected outcome and required finding codes. A successful corpus
run still reports the PDK as `unverified` and cannot be used as process
qualification by itself.

## M4a/M4b evidence gate

`PDKManifestViewInspectionPayload.isValid` is true only when the selected
workspace parser produces usable supported detailed semantics and the manifest
mapping matches the observed layers/devices. Unsupported expressions, incomplete
tables, inconsistent dimensions and missing timing units are blocked. This gate
does not claim complete vendor-specific language coverage, reference-oracle
correlation or foundry qualification.

## M5/M6 evidence gate

`PDKOracleComparisonPayload.isValid` is true only when every declared
canonical field matches the selected immutable expectation. The qualification
gate additionally requires a passing retained corpus case bound to the same
manifest digest. It returns `oracleCorrelated` as a local evidence handoff and
never claims `processQualified`.

## M6b/M7 evidence gate

The ToolQualification evidence contract is valid only when its complete scope
matches the requested implementation ID, binary digest, algorithm version,
process profile ID and deck digest. Xcircuite applies this requirement before
running the PDK qualification stage. A mismatched scope is blocked, while a
matching scope still requires human approval before a resumed run may continue.
The PDK-specific xcodebuild regression covers all six adapters and persists
the resulting envelopes; the fixture is contract evidence, not foundry
qualification.

## Evidence gate

`PDKCapabilityReport.qualificationState` remains `unverified` until a
process-scoped corpus, reference-oracle correlation and ToolQualification
record are attached. This package reports evidence and limitations; it never
promotes a PDK to foundry-qualified by itself.
