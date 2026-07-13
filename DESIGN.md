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
PDKKit protocols and result schemas
                 ↓
PDKStandardViews parser-backed adapters
                 ↓
Xcircuite stage adapters
                 ↓
DesignFlowKernel and .xcircuite artifacts
```

Backends may depend on lower-level data packages. This package must never import `Xcircuite` or `circuit-studio`.

## Trust model

Kernel availability, corpus validation, oracle correlation, local evidence
handoff, process-scoped qualification and release approval are distinct states.
The package reports capability and evidence; ToolQualification and Xcircuite
apply process and flow policy.

## Artifact requirements

All outputs are immutable run artifacts with format, digest, producer metadata and the input design/PDK revision needed to reproduce the result.

PDKKit validation emits a `PDKCapabilityReport` and
`PDKQualificationScope`. Both retain process ID, version and PDK digest. The
qualification state starts at `unverified`; no local validation result is
treated as foundry qualification.

`PDKAssetReference` is the PDK-owned artifact intent. Its
`artifactLocator()` projection uses `CircuiteFoundation.ArtifactLocator`.
`LocalPDKAssetResolver` materializes that intent through
`LocalArtifactReferencer`, producing a streaming SHA-256 and an immutable
`ArtifactReference` before it creates the retained Xcircuite compatibility
reference. The compatibility reference remains in the execution envelope
until the envelope migration is completed; it is not the integrity authority.

`PDKQualificationGate` may emit `oracleCorrelated` only when the retained
corpus and immutable oracle reports are both valid and share the selected PDK
manifest digest. It never emits `processQualified`; that state requires
independent process evidence and human approval.

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
