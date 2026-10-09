# PDKKit Implementation Plan

## Status

Implemented slices cover manifest/discovery, standard-view inspection, typed
result parity, artifact provenance and evidence handoff. They do not establish
complete executable process semantics. The public LEF view now retains the
standard-owned typed physical document with source identity. Native consumption
and required process-profile coverage remain in
[the system task](../PROGRESS.md), before process-constrained native closure.
Provider process execution, independent trust and human approval retain their
existing owners.

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
10. Local corpus assessment and oracle-correlation evidence handoff
11. Process-scoped ToolQualification integration
12. DesignFlowKernel runtime integration and Xcircuite review/resume evidence

## Implemented slices

- Current manifest schema and typed process/layer/device/corner semantics.
- Deterministic local discovery and reference digest construction through the
  CircuiteFoundation artifact boundary.
- Root-bounded, symlink-safe asset resolution with streaming SHA-256 and
  byte-count verification. Foundation `ArtifactLocator` and
  `ArtifactReference` are used directly throughout the public boundary.
- Production-profile validation controls that require immutable identity for
  required assets and require every locked process corner to be declared.
- Manifest validation, standard-view, rule-deck and oracle evidence admission
  use the independent PDKSourceCapture product and decode only its verified
  immutable bytes. Manifest-bound view composition checks the exact resolved
  source reference before binding. Qualification artifact reads retain their
  separate verifier owner. Identity discovery and parser allocations are not
  covered by source capture budgets.
- Cross-view mapping coverage and structured blocked diagnostics.
- Deterministic JSON CLI with inspect/discover/validate/corpus commands.
- Retained positive fixture, isolated negative-path fixture and request/payload round-trip tests.
- Retained corpus suite with valid and blocked expected outcomes, expected finding codes, root-bounded paths, deterministic results and `pdkkit-cli corpus` CLI.
- M4a standard-view contract with canonical LEF/GDSII/OASIS IR, immutable input verification, malformed parser failures, manifest cross-view binding and `pdkkit-cli inspect-view`.
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
  `pdkkit-cli inspect-rule-deck`; `LocalPDKValidator` injects the same protocol.
- Validation request schema 4 carries asset-identity and corner-locking controls
  and strict schema-2 identity values; obsolete request versions are rejected.
- Corpus schema version 2 carries `ruleDeckChecks` and per-case
  `ruleDeckResults`; older corpus schemas are rejected.
- M5 immutable manifest-digest-bound oracle expectations, canonical field comparison, structured mismatch blockers and `pdkkit-cli oracle`.
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
Until cancellation terminates execution, every declared LEF, GDSII/OASIS, SPICE
and Liberty mapping is executed through
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

## M5/M6 assessment and evidence handoff

`PDKOracleComparisonPayload.isValid` is true only when every declared
canonical field matches the selected immutable expectation. The local corpus
assessment additionally requires a passing retained case bound to the same
manifest digest. It returns `oracleCorrelated` as evidence for external policy
evaluation and never claims `processQualified`.

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

## Source admission reproduction

The source product can be built independently with
`swift build --target PDKSourceCapture`. Focused source tests use
`swift test --filter PDKSourceCaptureTests`; composed admission regressions use
`swift test --filter 'PDKSourceAdmissionRegressionTests|PDKSourceConsumerTests|PDKBoundSourceCaptureTests'`.
Wrap each test command with the repository's timeout policy. These tests execute
real local SHA-256/file access, post-capture path replacement/deletion, same-length
tampering, exact manifest binding, malformed page accounting and cleanup refusal.
They do not qualify process models, DRC decks or WASM/Embedded behavior.

## PN5.6.1 Execution Binding

PDKCore schema-1 execution values and the admission-owned non-overridable matcher
connect strict schema-2 profile consumption to a complete prepared domain graph.
The implementation preserves CP projection framing v1 and compares source
references/descriptors, corners, sections, preprocessing, physical incoming edges,
ordered one-to-one occurrence correspondence and every contributor. Stage-owned
checked capacity/work and last-copy lifetime apply to copied retained observations.

Focused proof uses the existing dedicated `PDKProfileAdmissionTests` product with
`ExecutionBindingTests`, not the package-wide test bundle. It includes real local
capture/admission with a controlled graph provider, strict new wire codecs, direct
and external entries, per-corner entries, mismatches, bounds/cancellation, independent
binding framing and last-copy release. This neutral proof does not authenticate a
domain grammar owner or establish host/numerical/WASM/Embedded execution.
