# PDKKit Goal Status

## Current state

**M0-M6 local evidence contracts, the PDK-specific M7 integration slice and the cross-package M6b/M8 release contracts are implemented. The North Star platform goal is not complete. Foundry/process qualification is intentionally not claimed.**

| Maturity gate | Status | Evidence |
|---|---|---|
| Responsibility boundary | Complete | README.md and DESIGN.md |
| Public package products | Complete | Package.swift, PDKCore/Discovery/Validation/Kit/CLI products |
| Shared Xcircuite request/result contract | Complete | Codable, Hashable, Sendable requests and result payloads |
| Contract build | Passed | `swift build` |
| Contract test | Passed | 27 PDKKit Swift Testing cases across 5 suites |
| Domain implementation | M4-M6 local evidence complete | Manifest migration, digesting, asset resolution, semantic validation, standard-view IR, oracle comparison and qualification gate |
| CLI implementation | Complete for local evidence | `pdkkit inspect`, `discover`, `validate`, `corpus`, `inspect-view`, `oracle`, `qualify` |
| Standard-view semantics | Structural M4a/M4b complete | LEF/GDSII/OASIS/SPICE/Liberty parser-backed structural IR, corner binding and manifest binding; deep model/timing semantics remain open |
| Fixture corpus | M3/M4 contract-complete | Retained valid, blocked and failed corpus cases plus manifest-bound LEF/SPICE/Liberty checks |
| Oracle correlation | Complete for immutable local structural oracle | Manifest-digest-bound expectation, comparison payload, mismatch blocker and CLI evidence |
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
| Cross-view validation | Implemented | Manifest mapping coverage and unavailable-semantics blockers | Retained fixture | Not qualified |
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

- Deep format-specific model/timing semantics remain a separate gate; absent
  mappings and oracle mismatches are blocked rather than passed.
- LEF/GDSII/OASIS inspection is backed by the workspace `swift-mask-data`
  parser. SPICE and Liberty structural/model/timing facts are now inspected by
  PDKKit-owned text adapters; full semantic depth is still open.
- No external-tool adapter has been selected or qualified for a foundry process.
- The retained corpus is a deterministic contract fixture, not foundry evidence.
- Independent process-specific qualification and release approval remain
  external evidence gates even though their typed contracts now exist.
- Full process qualification and release-profile eligibility still require
  independent process-scoped evidence, foundry/reference artifacts and an
  explicit human approval record. The PDK-specific headless integration gate
  is green, but that evidence must not be generalized to all platform stages.

This file must be updated by implementation agents whenever a maturity gate changes. A source file or type name alone is never evidence of implementation or qualification.
