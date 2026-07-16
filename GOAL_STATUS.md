# PDKKit Goal Status

## Current state

**All PDKKit-owned evidence gates are complete: M0-M6 local evidence contracts, M4c external typed-result parity, the PDK-specific M7 integration slice and canonical CircuiteFoundation artifact provenance. ToolQualification exclusively owns runtime trust decisions.**

| Maturity gate | Status | Evidence |
|---|---|---|
| Responsibility boundary | Complete | README.md and DESIGN.md |
| Public package products | Complete | Package.swift, PDKCore/Discovery/Validation/Kit/CLI products; contract version 2 |
| Shared engine and evidence contract | Complete | Domain protocols refine `CircuiteFoundation.Engine`; results directly expose artifact, diagnostic and evidence capabilities |
| Contract build | Passed | `swift build` |
| Contract test | Passed | 52 PDKKit Swift Testing cases across 6 suites; Foundation artifact projection, symlink containment, digest binding, external typed-result parity, source-reference binding, corpus retention, schema decoding and CLI evidence included |
| Domain implementation | M4-M6 local evidence complete | Manifest migration, digesting, asset resolution, parser-backed cross-view semantic validation, standard-view IR and oracle comparison |
| CLI implementation | Complete for local evidence | `pdkkit inspect`, `discover`, `validate`, `corpus`, `inspect-view`, `inspect-rule-deck`, `oracle` |
| Standard-view semantics | Complete for the PDKKit-owned canonical contract | LEF/GDSII/OASIS structure plus numeric SPICE model parameters, subcircuits, Liberty cells/timing tables/units; unsupported constructs produce structured blocked results |
| External backend parity | M4c contract complete | Typed JSON domain results, fail-closed schema/run/asset/format/source-reference/digest checks and canonical artifact identity binding; provider execution is outside PDKKit |
| Fixture corpus | M3/M4/M2b contract-complete | Retained valid, blocked and failed corpus cases plus manifest-bound LEF/SPICE/Liberty/rule-deck checks |
| Oracle correlation | Complete for immutable local detailed oracle | Manifest-digest-bound expectation, numeric model/table fields, mismatch blocker and CLI evidence |
| Qualification evidence handoff | Complete | Corpus, oracle, artifact identity and execution provenance are retained for ToolQualification |
| Process qualification ownership | External by design | PDKKit never creates or promotes trust state |
| ToolQualification trust scope | Implemented as a generic and PDK-aware contract | Implementation, binary, algorithm, process, deck, PDK ID and PDK digest must match; fixture evidence is not foundry qualification |
| Flow stage integration | Passed for the PDK slice | Direct DesignFlowKernel protocol integration, runtime-spec round-trip and typed result persistence |
| End-to-end flow evidence | Passed for PDK and release integration slices | PDK selected test: 6; release integration test: 5; approval/resume and runtime round-trip covered |
| Release readiness state | Correctly fail-closed | PDKKit preserves the required evidence boundary; approval artifacts are consumed by the owning release package |

## Function status

| Function | Contract | Implementation | Validation corpus | Qualification |
|---|---|---|---|---|
| Manifest schema and migration | Implemented | Current schema plus legacy key/path migration | Retained fixture | Not qualified |
| Local discovery | Implemented | Deterministic recursive local discovery | Retained fixture | Not qualified |
| Asset resolution and hashing | Implemented | CircuiteFoundation locator/reference/verifier boundary, root-bounded symlink-safe resolution, streaming SHA-256 and byte-count checks | Positive/negative tests | Not qualified |
| Layer and device semantics | Implemented | Typed layers, purposes, terminals and extraction recognition | Retained fixture | Not qualified |
| Corner model | Implemented | PVT plus RC/EM/reliability references and view mappings | Retained fixture | Not qualified |
| Cross-view validation | Implemented | Manifest mapping coverage plus parser-backed LEF/GDSII/OASIS/SPICE/Liberty `standardViewResults` and protocol-first rule-deck inspection in `ruleDeckResults` | Valid, comment-filtered and semantic-blocked fixtures | Not qualified |
| Qualification evidence export | Implemented | Capability report, immutable evidence and execution provenance | Retained fixture | Evaluated by ToolQualification |

## Goal progression

```text
contract scaffold
      ↓
narrow implementation
      ↓
negative-path fixtures
      ↓
corpus validation
      ↓
immutable oracle correlation
      ↓
typed evidence handoff
      ↓
process-scoped ToolQualification
      ↓
Xcircuite integration and repair loop
      ↓
release-profile eligibility
```

## Completion definition

The package goal is complete when every P0 function has a concrete backend,
structured failure behavior, retained corpus, reference correlation where an
oracle exists, immutable evidence handoff, a
deterministic CLI and a passing Xcircuite headless integration test. External
process evidence is consumed as a runtime input and is never fabricated by
PDKKit.

## Runtime evidence states (not PDKKit implementation gaps)

- Unsupported vendor-specific model/timing constructs, incomplete tables,
  absent mappings and oracle mismatches are represented as structured blocked
  results rather than being silently accepted.
- The manifest validation path now runs every declared standard-view mapping
  through the same parser-backed inspector used by `inspect-view`; its result
  collection is evidence, not process qualification.
- Rule-deck assets now require mapped layer evidence and retain statement and
  integrity results; absent rule-deck semantics are blocked.
- Rule-deck inspection is now an independent protocol-first implementation with a
  standalone CLI and per-layer evidence. The adapter is intentionally limited
  to integrity, statement and mapping evidence; vendor-specific geometric rule
  semantics remain an external/native qualification gate.
- `PDKValidationRequest` is schema version 2. Legacy version 1 requests remain
  decodable and default the new semantic checks to enabled.
- Corpus schema version 2 retains rule-deck check outcomes in each case result;
  version 1 suites remain accepted with an empty rule-deck check collection.
- LEF/GDSII/OASIS inspection is backed by the workspace `swift-mask-data`
  parser. SPICE and Liberty detailed numeric model/timing facts are inspected
  by PDKKit-owned text adapters with canonical Foundation artifact provenance.
- No external-tool adapter has been selected or qualified for a foundry process.
- External standard-view and rule-deck typed-result inspectors are implemented, but
  they do not execute external processes or create the independent
  ToolQualification evidence required for a foundry process.
- The retained corpus is a deterministic contract fixture, not foundry evidence.
- Independent process-specific qualification and release approval remain
  external evidence gates even though their typed contracts now exist.
- Full process qualification and release-profile eligibility still require
  independent process-scoped evidence, foundry/reference artifacts and an
  explicit human approval record. The PDK-specific headless integration gate
  is green, but that evidence must not be generalized to all platform stages.

This file must be updated by implementation agents whenever a maturity gate changes. A source file or type name alone is never evidence of implementation or qualification.
