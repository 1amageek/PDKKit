# PDKKit Design

## Purpose

Canonical process-design-kit discovery, identity and validation contracts.

The package now includes a local deterministic implementation of these
contracts, a retained corpus evaluator, standard-view inspection, immutable
oracle comparison and a local qualification handoff.
The implementation is intentionally manifest-driven: the manifest is the typed
semantic index, while standard-format files remain immutable artifacts whose
bytes are verified by digest and size.

## Responsibility boundary

This package owns the schemas and engine protocols listed in its public products. It must remain usable without UI state and without the Xcircuite runtime.

## Non-responsibilities

- Running DRC, LVS, PEX or simulation
- Declaring a tool qualified
- Mutating design data

## Dependency direction

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

## Trust model

Kernel availability, corpus validation, oracle correlation, local evidence
handoff, process-scoped qualification and release approval are distinct states.
The package reports capability and evidence; ToolQualification and Xcircuite
apply process and flow policy.

## Artifact requirements

All outputs are immutable run artifacts with format, digest, producer metadata and the input design/PDK revision needed to reproduce the result.

PDKKit validation emits a `PDKCapabilityReport` plus immutable artifacts and
execution provenance. No local validation result is treated as foundry
qualification; ToolQualification consumes the evidence and owns trust state.

`PDKAssetReference` is the PDK-owned artifact intent. Its
`artifactLocator()` projection uses `CircuiteFoundation.ArtifactLocator`.
`LocalPDKAssetResolver` materializes that intent through
`LocalArtifactReferencer`, producing a streaming SHA-256 and an immutable
`ArtifactReference`. PDK requests and results use CircuiteFoundation artifact
types directly, and each execution protocol refines `Engine` with its domain
request and result types.

The same boundary applies to standard-view, rule-deck and oracle artifact
reads. Local inspectors verify declared artifacts
through `LocalArtifactVerifier`, and canonical `ArtifactReference` values are
retained in standard-view IR, rule-deck payloads and oracle comparison
payloads. Old PDK-owned content-hash helpers have been removed; all artifact
identity and integrity work uses CircuiteFoundation directly.

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
`PDKStandardViews` target. Public payloads contain PDKKit-owned canonical IR,
so downstream agents do not depend on parser-specific types. SPICE and Liberty
remain separate M4b adapters.
