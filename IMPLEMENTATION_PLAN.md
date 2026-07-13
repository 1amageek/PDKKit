# PDKKit Implementation Plan

## Status

The implementation order below is complete through the supported detailed
standard-view numeric semantics, external envelope parity, local oracle, qualification-evidence and
PDK-specific runtime integration gates. Complete vendor-specific language
coverage, independent process qualification and release-profile approval remain
open.

## Order

1. Manifest schema and digest validation
2. Discovery providers
3. Cross-view consistency validation
4. Rule-deck adapter contract and validation request schema evolution
5. Retained PDK corpus contract and deterministic evaluator
6. M4a parser-backed LEF/GDSII/OASIS inspection and manifest binding
7. M4b SPICE/Liberty detailed numeric inspection and manifest binding
8. M4c native/local and external result-envelope parity
9. Immutable reference-oracle correlation
10. Local qualification gate and evidence handoff
11. Process-scoped ToolQualification integration
12. Xcircuite runtime, review and resume evidence

## Implemented slices

- Manifest schema migration and typed process/layer/device/corner semantics.
- Deterministic local discovery and reference digest construction through the
  CircuiteFoundation artifact boundary.
- Root-bounded, symlink-safe asset resolution with streaming SHA-256 and
  byte-count verification. Xcircuite file references remain compatibility
  projections for the current execution envelope.
- Cross-view mapping coverage and structured blocked diagnostics.
- Deterministic JSON CLI with inspect/discover/validate/corpus commands.
- Retained positive fixture, isolated negative-path fixture and request/payload round-trip tests.
- Retained corpus suite with valid and blocked expected outcomes, expected finding codes, root-bounded paths, deterministic results and `pdkkit corpus` CLI.
- M4a standard-view contract with canonical LEF/GDSII/OASIS IR, immutable input verification, malformed parser failures, manifest cross-view binding and `pdkkit inspect-view`.
- M4b detailed SPICE/Liberty inspection with numeric model parameters,
  engineering-suffix normalization, subcircuits, cells, timing arcs, timing
  table dimensions/values and unit declarations plus manifest binding and
  unsupported-semantics regression cases.
- Cross-view validation now invokes the same manifest-bound standard-view
  inspectors from `LocalPDKValidator` and persists one typed result per declared
  standard-view mapping.
- Rule-deck assets now use a typed text-semantic result that verifies UTF-8,
  non-empty statements and mapped manufacturing-layer evidence.
- Rule-deck inspection is now an independent `PDKRuleDeckInspecting` adapter
  with immutable source references, per-layer evidence and
  `pdkkit inspect-rule-deck`; `LocalPDKValidator` injects the same protocol.
- Validation request schema version 2 explicitly carries the standard-view and
  rule-deck controls while preserving version 1 decode defaults.
- Corpus schema version 2 carries `ruleDeckChecks` and per-case
  `ruleDeckResults`; version 1 suites remain readable with an empty collection.
- M5 immutable manifest-digest-bound oracle expectations, canonical field comparison, structured mismatch blockers and `pdkkit oracle`.
- M6 `PDKQualificationGate` and `pdkkit qualify`, which require matching retained corpus and oracle evidence and stop at `oracleCorrelated`.
- M7 six PDK FlowStageExecutor adapters with immutable stage-envelope
  persistence, agent-facing Codable runtime specs, project-root-bounded artifact
  references, ToolQualification scope enforcement, human approval and resume
  regression coverage.
- Xcircuite discovery/validation/corpus/standard-view/oracle/qualification
  adapters and persistence tests.
- M4c external standard-view and rule-deck providers with shared JSON envelope
  decoding, schema/run/asset/format/digest boundary validation and structured
  contract regression tests. The adapters intentionally leave external
  process execution and qualification to Xcircuite/SignoffToolSupport and
  ToolQualification.

## Completion gates

- Public APIs remain protocol-first and Sendable.
- Every unsupported semantic produces a structured blocked result.
- Native and external backends produce the same result schema.
- External result adapters reject trust-boundary mismatches before evidence is
  consumed by manifest binding or downstream stages.
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

`PDKValidationPayload.standardViewResults` is deterministic by asset and format.
Every declared LEF, GDSII/OASIS, SPICE and Liberty mapping is executed through
the manifest-bound inspector when `validateStandardViews` is enabled (the
default). A parser failure or semantic blocker changes the validation result to
`failed` or `blocked`; it cannot be omitted by a hash-only manifest pass.
`ruleDeckResults` applies the same fail-closed policy to declared rule decks;
missing mapping, unreadable text, empty statements or missing layer evidence are
structured blockers.

## M4c evidence gate

An external backend result is accepted only when its JSON envelope decodes with
the request schema version and run ID, its payload identifies the requested
asset, and its completed payload is valid. Standard-view payloads must preserve
the requested format and exact digest-bearing source reference. Rule-deck
payloads must preserve the requested PDK digest and resolved asset reference.
Schema, run, asset, format, source-reference and digest
mismatches are blocked. Provider failures, malformed JSON and invalid completed
payloads are failed with typed findings. This is envelope and semantic
integration evidence, not external-tool execution or process qualification.

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
