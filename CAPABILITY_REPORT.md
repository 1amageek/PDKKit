# PDKKit Capability and Limitation Report

## Implemented capabilities

| Capability | Evidence | Result |
|---|---|---|
| Versioned manifest decode and legacy migration | `PDKManifestCodec`, migration tests | Available |
| Immutable PDK identity and manifest digest | `PDKManifestReferenceBuilder`, SHA-256 test | Available |
| Local recursive discovery | `LocalPDKDiscoverer`, discovery test | Available |
| Manifest-relative asset resolution | `LocalPDKAssetResolver`, validation fixture | Available |
| Asset SHA-256 and byte-count integrity | `LocalPDKValidator`, negative-path test | Available |
| Layer, device and extraction semantics | Typed `PDKCore` models and validator | Available when declared |
| PVT/RC/EM/reliability corner model | `PDKCornerDefinition` and scope export | Available when declared |
| Cross-view mapping coverage | layer/device/corner coverage checks | Blocked when mappings are absent |
| Retained corpus evaluation | `PDKCorpusSuite`, `LocalPDKCorpusValidator`, valid/blocked/failed fixture cases | Available for declared local cases |
| Standard-view structural inspection | `PDKStandardViews`, `swift-mask-data` readers, SPICE/Liberty text adapters, canonical IR and manifest binding | Available for declared structural facts |
| Immutable oracle comparison | `PDKOracleExpectation`, `LocalPDKOracleComparator`, mismatch payload | Available for declared canonical facts |
| Local qualification gate | `PDKQualificationGate`, digest-bound corpus + oracle evidence | Available for `oracleCorrelated` handoff |
| Qualification artifact evaluator | `PDKQualificationRequest`, `LocalPDKQualificationEvaluator` | Available for immutable payload/envelope artifacts |
| Deterministic JSON API surface | `pdkkit inspect/discover/validate/corpus/inspect-view/oracle/qualify` | Available |
| Xcircuite stage execution | six PDK adapters, immutable envelopes, agent-facing runtime specs and approval/resume flow | Available for the PDK integration slice; full platform release flow remains open |

## Explicit limitations

- This package does not run DRC, LVS, PEX or simulation.
- This package does not replace format-specific LEF, GDSII/OASIS, SPICE or
  Liberty parsers. A raw file without a typed mapping is insufficient evidence
  and blocks validation.
- LEF/GDSII/OASIS inspection reuses the workspace `swift-mask-data` readers;
  SPICE/Liberty adapters retain structural model/cell/pin/timing facts. Deep
  model/table semantics remain open.
- The retained oracle is a local immutable structural expectation. It is not a
  foundry reference tool, and no process-specific qualification is included.
- The retained corpus is a contract corpus. It does not contain foundry
  process evidence and does not parse every standard-format view.
- `qualificationState` remains `unverified`; ToolQualification owns promotion
  to a process-scoped qualified state.
- ToolQualification scope matching is enforced at the Xcircuite trust gate for
  the PDK slice. The checked-in fixture provides contract evidence only; it does
  not establish an independent process qualification.

## Evidence flow

```mermaid
flowchart LR
  Manifest["PDK manifest"] --> Decode["Decode / migrate"]
  Decode --> Hash["Manifest + asset hashes"]
  Hash --> Semantics["Typed semantics"]
  Semantics --> Coverage["Cross-view coverage"]
  Coverage -->|complete| Scope["Capability report\nunverified scope"]
  Coverage -->|missing semantics| Blocked["Structured blocked result"]
  Scope --> Corpus["Retained corpus report"]
  Scope --> Oracle["Immutable oracle comparison"]
  Corpus --> Gate["Local qualification gate"]
  Oracle --> Gate
  Gate --> Qualified["oracleCorrelated handoff"]
  Qualified --> External["ToolQualification process gate"]
```
