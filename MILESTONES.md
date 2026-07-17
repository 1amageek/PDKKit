# PDKKit Milestones

PDKKit is a typed PDK contract and validation library inside the larger LSI
semiconductor design platform. All milestones owned by this package are
closed. The matrix records the evidence boundary between PDKKit-owned
contracts and runtime evidence consumed from the surrounding platform. A
passing manifest test is not physical design qualification.

```mermaid
flowchart LR
  M0[Baseline and contracts] --> M1[Manifest and immutable references]
  M1 --> M2[Semantic coverage validation]
  M2 --> M2b[Rule-deck protocol and schema evolution]
  M2b --> M3[Retained PDK corpus]
  M3 --> M4a[M4a LEF/GDSII/OASIS]
  M4a --> M4b[M4b SPICE/Liberty]
  M4b --> M4c[M4c external typed-result parity]
  M4c --> M5[Immutable oracle correlation]
  M5 --> M6[Local qualification gate]
  M6 --> M6b[Process-scoped qualification]
  M6b --> M7[Xcircuite trust gate and resume]
  M7 --> M8[Release-profile eligibility]
```

## Milestone matrix

| ID | Deliverable | Status | Proof required to close |
|---|---|---|---|
| M0 | Protocol-first package products, typed requests/results, deterministic CLI | Complete | `swift build`, contract tests, CLI output tests |
| M1 | Current manifest schema, CircuiteFoundation-backed immutable manifest/asset references and SHA-256 checks | Complete | current-schema tests, obsolete-schema rejection, positive and tampered-asset tests |
| M2 | Layer/device/corner/cross-view coverage and blocked unavailable semantics | Complete at manifest, parser-backed declared-view and rule-deck layer level | validator findings, standard-view/rule-deck results and negative-path fixtures |
| M2b | Protocol-first rule-deck inspection, per-layer evidence and validation request schema evolution | Complete for text integrity, statements and mapped-layer evidence | standalone request/payload, CLI, comment-filtered negative test, obsolete-schema rejection |
| M3 | Retained corpus suite schema, deterministic case evaluator and machine-readable corpus report | Complete for contract evidence; schema v2 retains rule-deck checks | corpus fixture, positive/blocked cases, standard-view/rule-deck result artifacts and deterministic report tests |
| M4 | Standard-view semantic adapters across the declared PDK views | Complete for the PDKKit-owned canonical semantics and fail-closed validation integration | Parser-backed canonical IR, typed blockers and retained regression evidence |
| M4a | Parser-backed LEF, GDSII and OASIS canonical inspection plus manifest binding | Complete for the PDKKit-owned canonical mask contract | parser tests, malformed-input findings, manifest binding and CLI evidence |
| M4b | SPICE and Liberty detailed numeric inspection and manifest binding | Complete for the PDKKit-owned numeric contract | Unsupported expressions and malformed dimensions are typed blocked results |
| M4c | Native/local and external backend typed-result parity with fail-closed trust-boundary validation | Contract complete; provider process execution is intentionally outside PDKKit | External result contract tests, schema/run/asset/format/source-reference/digest and canonical artifact mismatch blockers |
| M5 | Immutable reference-oracle comparison and mismatch classification | Complete for local detailed oracle contract | manifest-bound expectation, numeric field mismatch blocker, CLI and regression fixture |
| M6 | Local qualification gate from corpus + oracle evidence | Complete for `oracleCorrelated` handoff | digest-bound corpus/oracle reports and explicit non-qualification limitation |
| M6b | Process-scoped ToolQualification evidence and trust-gate promotion | PDKKit scope export and fail-closed handoff complete | PDKKit emits no false qualification; external evidence is consumed by the owning package |
| M7 | DesignFlowKernel runtime execution, immutable stage artifacts, human review and resume | Direct protocol integration complete; persistence owned by Xcircuite | clean headless PDK integration build, scope mismatch block and resume test |
| M8 | Release-profile eligibility and approval record | PDKKit handoff contract complete and fail-closed | PDKKit does not fabricate approval; owning release package consumes the typed artifacts |

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

M4c adds `ExternalPDKStandardViewInspector` and
`ExternalPDKRuleDeckInspector`. Both consume the same typed domain result
schema used by local implementations and reject
schema, run, asset, format, source-reference or PDK-digest mismatches as
structured blockers.
Malformed JSON, provider failures and invalid completed payloads remain
structured failures. These inspectors define the integration boundary only;
they do not claim that an external process has been discovered, executed,
qualified or approved.

The validation path now invokes those same manifest-bound inspectors for every
declared LEF, GDSII/OASIS, SPICE and Liberty mapping. The resulting
`standardViewResults` are retained in the validation payload, so a manifest
validation pass cannot silently omit a mapped parser failure or semantic
blocker.

Rule-deck assets are handled as a separate text-semantic implementation. A mapped deck
must be readable UTF-8 text with at least one statement and evidence for every
mapped manufacturing layer; otherwise `ruleDeckResults` reports a typed blocker.

M2b now exposes that implementation independently as `PDKRuleDeckInspecting`. The
result retains the immutable source reference, statement count and per-layer
matched-token/statement-index evidence. `pdkkit inspect-rule-deck` and
manifest validation consume the same implementation. Validation request schema
version 2 carries the standard-view and rule-deck controls; older request
schemas are rejected explicitly.

This milestone does not claim support for vendor-specific geometric rule
grammar. Such semantics require a native or external backend with its own
process-scoped qualification evidence.

The retained corpus also carries `ruleDeckChecks` and per-case
`ruleDeckResults`, so a corpus report no longer reduces rule-deck evidence to a
top-level pass/fail. Corpus suite schema version 2 is the only accepted corpus
schema; older suites are rejected rather than interpreted with missing
rule-deck evidence.

## Exit gates and ownership

| Gate | Owner | Required artifact |
|---|---|---|
| Manifest/asset integrity | PDKKit | immutable references and validation result |
| Format semantics | PDKKit implementation or approved external tool | canonical view report |
| Oracle correlation | PDKKit, then ToolQualification/Xcircuite | immutable comparison result and mismatch evidence |
| Process qualification | ToolQualification | independent process-scoped qualification record and evidence lineage |
| Release eligibility | ReleaseEngine/Xcircuite | retained release result, approval record and reproducible run |
| Human approval/resume | Xcircuite/DesignFlowKernel | run ledger, diff, approval and resume artifacts |

The package can report `unverified` when external evidence is absent. This is a
runtime evidence state, not an unimplemented PDKKit capability; PDKKit exports
the typed scope, preserves provenance and blocks unsafe promotion.
