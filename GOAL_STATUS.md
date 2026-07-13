# PDKKit Goal Status

## Current state

**M0-M6 local evidence contracts, M4c external envelope parity, the PDK-specific M7 integration slice and the cross-package M6b/M8 release contracts are implemented. The North Star platform goal is not complete. Foundry/process qualification is intentionally not claimed.**

| Maturity gate | Status | Evidence |
|---|---|---|
| Responsibility boundary | Complete | README.md and DESIGN.md |
| Public package products | Complete | Package.swift, PDKCore/Discovery/Validation/Kit/CLI products; contract version 2 |
| Shared Xcircuite request/result contract | Complete | Codable, Hashable, Sendable requests and result payloads |
| Contract build | Passed | `swift build` |
| Contract test | Passed | 46 PDKKit Swift Testing cases across 6 suites; external envelope parity, source-reference binding, standalone rule-deck inspector, corpus retention, schema compatibility and CLI evidence included |
| Domain implementation | M4-M6 local evidence complete | Manifest migration, digesting, asset resolution, parser-backed cross-view semantic validation, standard-view IR, oracle comparison and qualification gate |
| CLI implementation | Complete for local evidence | `pdkkit inspect`, `discover`, `validate`, `corpus`, `inspect-view`, `inspect-rule-deck`, `oracle`, `qualify` |
| Standard-view semantics | Supported detailed M4a/M4b subset complete | LEF/GDSII/OASIS structure plus numeric SPICE model parameters, subcircuits, Liberty cells/timing tables/units; unsupported constructs block execution |
| External backend parity | M4c contract complete for envelope and input-reference binding | Shared JSON result envelopes, fail-closed schema/run/asset/format/source-reference/digest checks and manifest-binding regression tests; external process qualification remains open |
| Fixture corpus | M3/M4/M2b contract-complete | Retained valid, blocked and failed corpus cases plus manifest-bound LEF/SPICE/Liberty/rule-deck checks |
| Oracle correlation | Complete for immutable local detailed oracle | Manifest-digest-bound expectation, numeric model/table fields, mismatch blocker and CLI evidence |
| Local qualification gate | Complete for `oracleCorrelated` handoff | Matching corpus/oracle reports required; `processQualified` is never emitted |
| Process qualification | Contract implemented; not claimed | Requires an independent, fresh process-scoped ToolQualification evidence record with PDK scope |
| ToolQualification trust scope | Implemented as a generic and PDK-aware contract | Implementation, binary, algorithm, process, deck, PDK ID and PDK digest must match; fixture evidence is not foundry qualification |
| Xcircuite stage adapter | Passed for the PDK slice | Six PDK FlowStageExecutor adapters, runtime-spec round-trip and immutable envelope persistence |
| End-to-end flow evidence | Passed for PDK and release adapter slices | PDK selected test: 6; release adapter test: 5; approval/resume and runtime round-trip covered |
| Release readiness | Contract implemented, blocked by evidence | No foundry-specific corpus/oracle/approval is present |

## Function status

| Function | Contract | Implementation | Validation corpus | Qualification |
|---|---|---|---|---|
| Manifest schema and migration | Implemented | Current schema plus legacy key/path migration | Retained fixture | Not qualified |
| Local discovery | Implemented | Deterministic recursive local discovery | Retained fixture | Not qualified |
| Asset resolution and hashing | Implemented | Root-bounded resolution, SHA-256 and byte-count checks | Positive/negative tests | Not qualified |
| Layer and device semantics | Implemented | Typed layers, purposes, terminals and extraction recognition | Retained fixture | Not qualified |
| Corner model | Implemented | PVT plus RC/EM/reliability references and view mappings | Retained fixture | Not qualified |
| Cross-view validation | Implemented | Manifest mapping coverage plus parser-backed LEF/GDSII/OASIS/SPICE/Liberty `standardViewResults` and protocol-first rule-deck inspection in `ruleDeckResults` | Valid, comment-filtered and semantic-blocked fixtures | Not qualified |
| Qualification scope export | Implemented | Capability report and unverified qualification scope | Retained fixture | Not qualified |

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
local qualification gate
      ↓
process-scoped ToolQualification
      ↓
Xcircuite integration and repair loop
      ↓
release-profile eligibility
```

## Completion definition

The package goal is complete only when every P0 function has a concrete backend, structured failure behavior, retained corpus, reference correlation where an oracle exists, process-scoped qualification where required, a deterministic CLI and a passing Xcircuite headless integration test.

## Current blockers

- Complete vendor-specific model/timing language coverage remains a separate
  gate; unsupported expressions, incomplete tables, absent mappings and oracle
  mismatches are blocked rather than passed.
- The manifest validation path now runs every declared standard-view mapping
  through the same parser-backed inspector used by `inspect-view`; its result
  collection is evidence, not process qualification.
- Rule-deck assets now require mapped layer evidence and retain statement and
  integrity results; absent rule-deck semantics are blocked.
- Rule-deck inspection is now an independent protocol-first adapter with a
  standalone CLI and per-layer evidence. The adapter is intentionally limited
  to integrity, statement and mapping evidence; vendor-specific geometric rule
  semantics remain an external/native qualification gate.
- `PDKValidationRequest` is schema version 2. Legacy version 1 requests remain
  decodable and default the new semantic checks to enabled.
- Corpus schema version 2 retains rule-deck check outcomes in each case result;
  version 1 suites remain accepted with an empty rule-deck check collection.
- LEF/GDSII/OASIS inspection is backed by the workspace `swift-mask-data`
  parser. SPICE and Liberty detailed numeric model/timing facts are inspected
  by PDKKit-owned text adapters; complete vendor-specific semantic coverage is
  still open.
- No external-tool adapter has been selected or qualified for a foundry process.
- External standard-view and rule-deck envelope adapters are implemented, but
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
