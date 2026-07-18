# PDKKit Capability and Limitation Report

## Implemented capabilities

| Capability | Evidence | Result |
|---|---|---|
| Current manifest decode and obsolete-schema rejection | `PDKManifestCodec`, negative schema and obsolete-field tests | Available |
| Immutable PDK identity and manifest digest | `PDKManifestReferenceBuilder`, SHA-256 test | Available |
| Local recursive discovery | `LocalPDKDiscoverer`, discovery test | Available |
| Manifest-relative asset resolution | `LocalPDKAssetResolver`, validation fixture | Available |
| Asset SHA-256 and byte-count integrity | `CircuiteFoundation.LocalArtifactReferencer`/`LocalArtifactVerifier` through asset, standard-view, rule-deck and oracle paths, negative-path tests | Available |
| Layer, device and extraction semantics | Typed `PDKCore` models and validator | Available when declared |
| PVT/RC/EM/reliability corner model | `PDKCornerDefinition` and scope export | Available when declared |
| Cross-view mapping coverage | layer/device/corner coverage checks | Blocked when mappings are absent |
| Manifest-bound cross-view semantic validation | `LocalPDKValidator` invokes the manifest-bound LEF/GDSII/OASIS/SPICE/Liberty inspectors and retains `standardViewResults` | Available for declared mappings; parser failures and semantic blockers fail closed |
| Rule-deck semantic validation | `PDKRuleDeckInspecting`, `LocalPDKRuleDeckInspector`, `PDKRuleDeckInspectionPayload`, `ruleDeckResults` and `pdkkit inspect-rule-deck` | Available for declared text rule decks; grammar limitations and missing layer evidence block |
| Retained corpus evaluation | `PDKCorpusSuite`, `LocalPDKCorpusValidator`, standard-view and rule-deck case results, valid/blocked/failed fixture cases | Available for declared local cases; schema v2 is required |
| Standard-view detailed inspection | `PDKStandardViews`, `swift-mask-data` readers, SPICE/Liberty text adapters, canonical IR and manifest binding | Available for supported mask structure, numeric SPICE model parameters, Liberty timing tables and units |
| External backend result parity | `PDKExternalStandardViewResultProviding`, `PDKExternalRuleDeckResultProviding`, external inspectors and contract tests | Available for typed domain results, digest-bearing source-reference binding and canonical artifact identity binding; provider process execution is outside PDKKit |
| Immutable oracle comparison | `PDKOracleExpectation`, `LocalPDKOracleComparator`, mismatch payload | Available for declared canonical facts |
| Qualification evidence handoff | Digest-bound corpus, oracle and execution provenance artifacts | Available for ToolQualification consumption |
| Deterministic JSON API surface | `pdkkit inspect/discover/validate/corpus/inspect-view/inspect-rule-deck/oracle` | Available |
| Flow stage execution | Direct DesignFlowKernel protocol integration, immutable typed results, agent-facing runtime specs and approval/resume flow | Available for the PDK integration slice; concrete `.xcircuite` persistence is owned by Xcircuite |

## Explicit limitations

- This package does not run DRC, LVS, PEX or simulation.
- External backend inspectors validate a typed result contract but do not start
  external tools, discover binaries, persist process logs or establish
  process-scoped qualification. Those responsibilities remain with
  DesignFlowKernel/Xcircuite, SignoffToolSupport and ToolQualification.
- This package does not replace format-specific LEF, GDSII/OASIS, SPICE or
  Liberty parsers. A raw file without a typed mapping is insufficient evidence
  and blocks validation.
- LEF/GDSII/OASIS inspection reuses the workspace `swift-mask-data` readers;
  SPICE/Liberty adapters retain canonical model parameters, subcircuits, cells,
  timing arcs, timing table indices/values and unit declarations. Unsupported
  expressions, incomplete tables and dimension mismatches are blocked. The
  PDKKit-owned parser contract is complete and fails closed for unsupported
  vendor extensions; execution of those extensions requires a backend-specific
  provider contract.
- The retained oracle is a local immutable detailed expectation. It is not a
  foundry reference tool, and no process-specific qualification is included.
- The retained corpus is a contract corpus. It does not contain foundry
  process evidence and does not parse every standard-format view.
- ToolQualification exclusively owns process-scoped trust and qualification
  decisions; PDKKit publishes evidence without a local qualification state.
- ToolQualification scope matching is enforced at the Xcircuite trust gate for
  the PDK slice. The workspace also defines an independent
  `ToolProcessQualificationEvidence` artifact and a ReleaseEngine fail-closed
  consumer. The checked-in fixture provides contract evidence only; it does
  not establish an independent process qualification.

## Evidence flow

```mermaid
flowchart LR
  Manifest["PDK manifest"] --> Decode["Decode current schema"]
  Decode --> Hash["Manifest + asset hashes"]
  Hash --> Semantics["Typed semantics"]
  Semantics --> Coverage["Cross-view coverage"]
  Coverage -->|complete| Scope["Capability report\nunverified scope"]
  Coverage -->|missing semantics| Blocked["Structured blocked result"]
  Scope --> Corpus["Retained corpus report"]
  Scope --> Oracle["Immutable oracle comparison"]
  Corpus --> Assessment["Local corpus assessment"]
  Oracle --> Assessment
  Assessment --> Evidence["oracleCorrelated evidence handoff"]
  Evidence --> External["ToolQualification process gate"]
```
