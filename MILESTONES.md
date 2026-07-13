# PDKKit Milestones

PDKKit is a typed PDK contract and validation library inside the larger LSI
semiconductor design platform. The milestone list is intentionally larger than
the current local implementation. A passing manifest test is not physical
design qualification.

```mermaid
flowchart LR
  M0[Baseline and contracts] --> M1[Manifest and immutable references]
  M1 --> M2[Semantic coverage validation]
  M2 --> M3[Retained PDK corpus]
  M3 --> M4a[M4a LEF/GDSII/OASIS]
  M4a --> M4b[M4b SPICE/Liberty]
  M4b --> M5[Immutable oracle correlation]
  M5 --> M6[Local qualification gate]
  M6 --> M6b[Process-scoped qualification]
  M6b --> M7[Xcircuite trust gate and resume]
  M7 --> M8[Release-profile eligibility]
```

## Milestone matrix

| ID | Deliverable | Status | Proof required to close |
|---|---|---|---|
| M0 | Protocol-first package products, typed requests/results, deterministic CLI | Complete | `swift build`, contract tests, CLI output tests |
| M1 | Versioned manifest, migration, immutable manifest/asset references and SHA-256 checks | Complete | migration tests, positive and tampered-asset tests |
| M2 | Layer/device/corner/cross-view coverage and blocked unavailable semantics | Complete at manifest-contract level | validator findings and negative-path fixtures |
| M3 | Retained corpus suite schema, deterministic case evaluator and machine-readable corpus report | Complete for contract evidence | corpus fixture, positive/blocked cases, deterministic report tests |
| M4 | Standard-view semantic adapters across the declared PDK views | Complete for the supported canonical semantics | Complete vendor-specific language coverage remains a separate gate |
| M4a | Parser-backed LEF, GDSII and OASIS canonical inspection plus manifest binding | Complete for selected mask views | parser tests, malformed-input findings, manifest binding and CLI evidence |
| M4b | SPICE and Liberty detailed numeric inspection and manifest binding | Complete for the supported canonical numeric subset | Complete vendor-specific language coverage remains open |
| M5 | Immutable reference-oracle comparison and mismatch classification | Complete for local detailed oracle contract | manifest-bound expectation, numeric field mismatch blocker, CLI and regression fixture |
| M6 | Local qualification gate from corpus + oracle evidence | Complete for `oracleCorrelated` handoff | digest-bound corpus/oracle reports and explicit non-qualification limitation |
| M6b | Process-scoped ToolQualification evidence and trust-gate promotion | Independent qualification artifact contract implemented; actual process evidence not claimed | independent qualified tool descriptor, fresh evidence and matching PDK scope |
| M7 | Xcircuite runtime execution, immutable stage artifacts, human review and resume | PDK adapter/runtime slice complete | clean headless PDK integration build, scope mismatch block and resume test |
| M8 | Release-profile eligibility and approval record | Release qualification contract implemented outside PDKKit; external approval open | all required gates, approval artifact and reproducible run |

## Current implementation focus: M4b coverage/M6b/M8 evidence handoff

M3 turned isolated smoke tests into a retained, auditable set of expected
outcomes. M4-M6 now extend that evidence through canonical standard-view
inspection, immutable oracle comparison and an explicit local gate. The
pipeline preserves the distinction between:

- `valid`: the local contract is satisfied;
- `blocked`: an unavailable or unsafe prerequisite prevents a pass;
- `failed`: the input could not be interpreted or the validator failed.

The local gate may produce `oracleCorrelated` only when the selected PDK digest,
retained corpus report and oracle comparison all agree. It does not promote
`processQualified`; that remains owned by independent ToolQualification and
human approval.

The M6b contract now binds ToolQualification evidence to the requested
implementation, binary digest, algorithm version, process profile, deck
digest, PDK ID and PDK digest. `ToolProcessQualificationEvidence` records
independence, evidence lineage, qualification status and expiry. ReleaseEngine
re-reads that typed artifact from a declared `productionApproval` reference and
fails closed on parse, freshness, identity or scope mismatch. The workspace
fixture demonstrates the contract boundary; it is not independent foundry
evidence and does not close process qualification.

M4b now emits typed SPICE model parameters with engineering-suffix
normalization, subcircuit terminals and parameter declarations, Liberty cells,
timing arcs, timing table indices/values and unit declarations. The semantic
gate fails closed for unsupported expressions, missing SPICE termination,
non-numeric Liberty values, inconsistent table dimensions and missing timing
units. This closes the supported numeric subset; it does not imply complete
coverage of all vendor extensions.

## Exit gates and ownership

| Gate | Owner | Required artifact |
|---|---|---|
| Manifest/asset integrity | PDKKit | immutable references and validation envelope |
| Format semantics | PDKKit adapter or approved external tool | canonical view report |
| Oracle correlation | PDKKit, then ToolQualification/Xcircuite | immutable comparison result and mismatch evidence |
| Process qualification | ToolQualification | independent process-scoped qualification record and evidence lineage |
| Release eligibility | ReleaseEngine/Xcircuite | retained release result, approval record and reproducible run |
| Human approval/resume | Xcircuite/DesignFlowKernel | run ledger, diff, approval and resume artifacts |

The package remains `unverified` until the external gates are attached.
