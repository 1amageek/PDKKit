# PDKKit Implementation Plan

## Status

The implementation order below is complete for every PDKKit-owned contract:
standard-view semantics, external typed-result parity, canonical artifact
provenance, local oracle, qualification-scope handoff and PDK-specific runtime
integration. Unsupported input is represented as a typed blocked result;
provider process execution and independent evidence are runtime inputs owned by
the corresponding platform packages.

## Order

1. Manifest schema and digest validation
2. Discovery providers
3. Cross-view consistency validation
4. Rule-deck protocol and validation request schema evolution
5. Retained PDK corpus contract and deterministic evaluator
6. M4a parser-backed LEF/GDSII/OASIS inspection and manifest binding
7. M4b SPICE/Liberty detailed numeric inspection and manifest binding
8. M4c native/local and external typed-result parity
9. Immutable reference-oracle correlation
10. Local qualification gate and evidence handoff
11. Process-scoped ToolQualification integration
12. DesignFlowKernel runtime integration and Xcircuite review/resume evidence

## Implemented slices

- Manifest schema migration and typed process/layer/device/corner semantics.
- Deterministic local discovery and reference digest construction through the
  CircuiteFoundation artifact boundary.
- Root-bounded, symlink-safe asset resolution with streaming SHA-256 and
  byte-count verification. Foundation `ArtifactLocator` and
  `ArtifactReference` are used directly throughout the public boundary.
- Standard-view, rule-deck, oracle and qualification artifact reads use the
  same Foundation verifier and retain canonical `ArtifactReference`
  provenance.
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
- Rule-deck inspection is now an independent `PDKRuleDeckInspecting` implementation
  with immutable source references, per-layer evidence and
  `pdkkit inspect-rule-deck`; `LocalPDKValidator` injects the same protocol.
- Validation request schema version 2 explicitly carries the standard-view and
  rule-deck controls while preserving version 1 decode defaults.
- Corpus schema version 2 carries `ruleDeckChecks` and per-case
  `ruleDeckResults`; version 1 suites remain readable with an empty collection.
- M5 immutable manifest-digest-bound oracle expectations, canonical field comparison, structured mismatch blockers and `pdkkit oracle`.
- M6 immutable digest-bound corpus and oracle evidence handoff for ToolQualification.
- M7 direct DesignFlowKernel protocol integration with project-root-bounded
  artifact references, ToolQualification scope enforcement, human approval and
  resume regression coverage; concrete `.xcircuite` persistence remains owned
  by Xcircuite.
- M4c external standard-view and rule-deck providers with typed JSON result
  decoding, schema/run/asset/format/digest boundary validation and structured
  contract regression tests. External process execution and qualification are
  owned by DesignFlowKernel/Xcircuite, SignoffToolSupport and ToolQualification.

## Completion gates

- Public APIs remain protocol-first and Sendable.
- Every unsupported semantic produces a structured blocked result.
- Native and external backends produce the same result schema.
- External result inspectors reject trust-boundary mismatches before evidence is
  consumed by manifest binding or downstream stages.
- No UI type enters a public contract.
- No result claims foundry qualification without process-scoped oracle evidence.
- DesignFlowKernel can execute and review the PDK stage through direct typed
  protocols; Xcircuite can persist and resume the stage without
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

An external backend result is accepted only when its typed JSON result decodes with
the request schema version and run ID, its payload identifies the requested
asset, and its completed payload is valid. Standard-view payloads must preserve
the requested format and exact digest-bearing source reference. Rule-deck
payloads must preserve the requested PDK digest and resolved asset reference.
Schema, run, asset, format, source-reference and digest
mismatches are blocked. Provider failures, malformed JSON and invalid completed
payloads are failed with typed findings. This is result and semantic
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
process profile ID and deck digest. ToolQualification applies this requirement
before a flow consumes PDK evidence. A mismatched scope is blocked, while a
matching scope still requires human approval before a resumed run may continue.
The PDK-specific regression covers direct protocol execution and persists
typed stage results; the fixture is contract evidence, not foundry
qualification.

## Evidence gate

PDKKit reports capability, immutable evidence and limitations. A process-scoped
corpus, reference-oracle correlation and ToolQualification record are evaluated
outside this package; PDKKit never promotes a PDK to foundry-qualified.
