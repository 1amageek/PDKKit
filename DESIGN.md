# PDKKit Design

## Purpose and Scope

Canonical process-design-kit discovery, identity and validation contracts.

The package now includes a local deterministic implementation of these
contracts, a retained corpus evaluator, standard-view inspection, immutable
oracle comparison and a local assessment evidence handoff.
The implementation is intentionally manifest-driven: the manifest is the typed
semantic index, while standard-format files remain immutable artifacts whose
bytes are verified by digest and size.
Parent: [LSI](../DESIGN.md). The affected child is
[PDKStandardViews](Sources/PDKStandardViews/DESIGN.md), alongside the independently
buildable [PDKSourceCapture](Sources/PDKSourceCapture/DESIGN.md) admission module.
Manifest validation is owned by [PDKValidation](Sources/PDKValidation/DESIGN.md).

## Responsibilities and Boundaries

This package owns the schemas and engine protocols listed in its public products. It must remain usable without UI state and without the Xcircuite runtime.

## Non-responsibilities

- Running DRC, LVS, PEX or simulation
- Declaring a tool qualified
- Mutating design data

## Architecture

```text
Swift/Foundation
       ↓
CircuiteFoundation artifact intent, identity and integrity
       ↓
PDKKit protocols and typed result schemas
                 ↓
PDKStandardViews parser-backed implementations
                 ↓
DesignFlowKernel stage execution (injected protocol)
                 ↓
Xcircuite concrete .xcircuite persistence
```

Backends may depend on lower-level data packages. This package must never import `Xcircuite` or `circuit-studio`.

## Contracts and Invariants

Kernel availability, corpus validation, oracle correlation, local evidence
handoff, process-scoped qualification and release approval are distinct states.
The package reports capability and evidence; ToolQualification and Xcircuite
apply process and flow policy.

## Artifact requirements

All outputs are immutable run artifacts with format, digest, producer metadata and the input design/PDK revision needed to reproduce the result.

PDKKit validation emits a `PDKCapabilityReport` plus immutable artifacts and
execution provenance. No local validation result is treated as foundry
qualification; ToolQualification consumes the evidence and owns trust state.

[PDKCore](Sources/PDKCore/DESIGN.md) owns manifest/asset values, identity projections
and asset declaration checks. View composition and status contracts are owned by
[PDKStandardViews](Sources/PDKStandardViews/DESIGN.md) and
[PDKValidation](Sources/PDKValidation/DESIGN.md).

`PDKAssetReference` is the PDK-owned artifact intent. Its
`artifactLocator()` projection uses `CircuiteFoundation.ArtifactLocator`.
`LocalPDKAssetResolver` materializes that intent through
`LocalArtifactReferencer`, producing a streaming SHA-256 and an immutable
`ArtifactReference`. PDK requests and results use CircuiteFoundation artifact
types directly, and each execution protocol refines `Engine` with its domain
request and result types.

Manifest validation and standard-view, rule-deck and oracle admission use
[PDKSourceCapture](Sources/PDKSourceCapture/DESIGN.md). Semantic readers consume
its verified immutable bytes. Canonical `ArtifactReference` values are retained
in standard-view IR, rule-deck payloads and oracle comparison payloads. Earlier
identity discovery remains separate and is not covered by capture budgets.

Corpus and oracle reports retain the selected PDK manifest digest so
ToolQualification can evaluate their scope together with independent process
evidence and human approval.

When a format-specific semantic parser or reference oracle is unavailable,
the validator emits a structured `blocked` result. It does not infer
cross-view correctness from file existence alone.

The corpus evaluator preserves this distinction by treating an expected
blocked case as a passing corpus case only when the declared blocker is
reproduced. This is test evidence, not qualification evidence.

The selected LEF/GDSII/OASIS adapters depend on `swift-mask-data` only in the
`PDKStandardViews` target. LEF physical declarations are retained as the
standard-owned `LEFDocument`, alongside PDK-owned identity, validation and
inventory facts. [StandardInspection](Sources/PDKStandardViews/StandardInspection/DESIGN.md)
owns complete observed layer names, including actual geometry references; engine
source mapping uses this inventory without synthesizing declarations. This replaces the names-only physical projection: duplicating
cell/pin/via/rule fields in a second PDK schema would create another independent
loss boundary. PDKCore and portable domain manifests do not gain this dependency.
SPICE and Liberty retain their existing PDK-owned inspection schemas.

The artifact digest and byte count used by the semantic parser must agree with
the actual in-memory bytes parsed, not only an earlier read of the source path.
Inspection remains distinct from engine capability and process qualification.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [LSI](../DESIGN.md) | Parent | Exact process evidence | Platform composition | Inventory does not establish production closure |
| [PDKCore](Sources/PDKCore/DESIGN.md) | Child | Manifest and asset identity | Declaration checks and resolution | Resolution does not authenticate declarations |
| [PDKStandardViews](Sources/PDKStandardViews/DESIGN.md) | Child | Retained standard semantics | Inspection boundary | Unsupported grammar fails explicitly |
| [PDKValidation](Sources/PDKValidation/DESIGN.md) | Child | Manifest and composed validation | Validation results | Admission does not imply qualification |
| [PDKSourceCapture](Sources/PDKSourceCapture/DESIGN.md) | Child | Bounded exact owned parser input | Manifest/view/rule-deck admission | Successful cleanup is part of source admission; captures do not imply a closed PDK graph |
| [LEF](../swift-mask-data/Sources/LEF/DESIGN.md) | Depends on | LEFDocument and typed errors | Standard physical schema ownership | Consumers must resolve process names and capability |

## Verification and Change Impact

PDKStandardViewTests verifies actual inspection, source identity, retained
physical fields, serialization and parser failures. PDK validation/corpus and
external-provider tests verify composition. Physical engines must separately
prove placement, pin access, routing and extraction against the retained view.

For the identity-composition correction, native verification includes the full
106-test package, seven real CLI cases and four real Xcircuite public-API stage
executions with immutable artifact verification and ledger retention. The changed
PDK objects were verified under a temporary consumer override, which was removed.
The large Xcircuite test product did not execute within its build timeouts; this
evidence covers the four API paths, not that complete test product.
