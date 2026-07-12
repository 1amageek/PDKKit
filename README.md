# PDKKit

Canonical process-design-kit discovery, identity, asset integrity and validation contracts.

## Status

The local contract layer is executable for deterministic manifest-driven discovery,
validation, retained corpus evaluation and parser-backed standard-view
inspection, immutable oracle comparison and a local qualification gate. The
PDK stage slice is also executable through Xcircuite with immutable artifacts,
scope-bound tool evidence, human approval and resume coverage. The larger
platform goal remains open: full model/timing semantics, independent
process-scoped tool qualification and release approval are separate evidence
gates owned across PDKKit, ToolQualification and Xcircuite.

## Products

| Product | Responsibility |
|---|---|
| `PDKCore` | PDK identity and immutable manifest reference |
| `PDKDiscovery` | Deterministic local PDK discovery without qualification claims |
| `PDKValidation` | Manifest, input, asset, digest, cross-view, retained corpus and local qualification gate |
| `PDKStandardViews` | Canonical standard-view inspection, manifest binding and immutable oracle comparison |
| `PDKKit` | Umbrella API and public contract version |
| `PDKKitCLICore` / `pdkkit` | Deterministic JSON inspection, discovery, validation, corpus, oracle and qualification CLI |

## Contract

Every executing product uses:

- a `Codable`, `Hashable`, `Sendable` request conforming to `XcircuiteEngineRequest`;
- `XcircuiteEngineResultEnvelope<Payload>` for status, diagnostics, artifacts and execution metadata;
- protocol-first dependency injection;
- immutable `XcircuiteFileReference` inputs and outputs;
- explicit blocked, failed and cancelled states.

## Xcircuite integration

Xcircuite resolves a PDKReference before constructing downstream stage requests. Every physical or electrical stage records the same PDK digest.

The library does not depend on the Xcircuite runtime. Xcircuite owns the adapter to `DesignFlowKernel.FlowStageExecutor`, artifact persistence, qualification gates, repair loops and human approval.

The Xcircuite package provides discovery, validation, retained-corpus,
standard-view, oracle and qualification `FlowStageExecutor` adapters. The
agent-facing `XcircuiteFlowStageExecutorSpec` can encode and construct all six
PDK stages. Each adapter persists the complete engine envelope as an immutable
run artifact and maps completed, blocked, failed and cancelled states to flow
gates. Qualification evidence is accepted only when the ToolQualification
scope matches the requested implementation, binary, algorithm, process and
deck; the integration test also covers human approval followed by resume.

Relative artifact references are resolved against an explicit project root and
cannot escape it. Adapters pass the project root into PDKKit, so a persisted
run remains reproducible even when its inputs are stored as project-relative
references.

## Manifest contract

`PDKManifest` is the canonical process-scoped source of truth. It contains:

- process identity and version;
- immutable asset references and optional expected SHA-256/byte count;
- manufacturing layer and purpose semantics;
- device terminals and extraction recognition;
- PVT, RC, electromigration and reliability corner mappings;
- cross-view mappings for layer map, LEF/GDSII/OASIS, SPICE and Liberty views.

Schema version zero is migrated to the current schema, including legacy
`process`, `pdkVersion` and file-path fields. Unsupported or malformed schemas
produce typed errors.

Raw asset presence is not treated as semantic proof. Missing mappings, missing
assets, digest mismatches and unavailable semantics produce structured blocked
diagnostics instead of a false pass.

`PDKCorpusSuite` and `LocalPDKCorpusValidator` retain expected valid, blocked
and failed cases. Corpus success is evidence of the declared local validator
and failed cases, including manifest-bound standard-view checks. Corpus success
is evidence of the declared local validator contract only; it does not promote
the qualification state.

`PDKOracleExpectation` binds canonical standard-view facts to a manifest
digest. `LocalPDKOracleComparator` returns structured field mismatches, and
`PDKQualificationGate` promotes only a matching local corpus plus oracle pair
to `oracleCorrelated`. It never emits `processQualified`.

## CLI

```bash
swift run pdkkit inspect --manifest <path> --pretty
swift run pdkkit discover --root <path> [--root <path> ...] --process-id <id>
swift run pdkkit validate --manifest <path> --required-role layerMap --pretty
swift run pdkkit corpus --suite <path> --root <path> --pretty
swift run pdkkit inspect-view --manifest <path> --asset-id <id> --format <lef|gdsii|oasis|spice|liberty> --pretty
swift run pdkkit oracle --manifest <path> --oracle <path> --pretty
swift run pdkkit qualify --manifest <path> --corpus <report.json> --oracle <report.json> --pretty
```

The CLI writes deterministic sorted-key JSON to stdout. Domain blockers use
exit code `2`; argument, read and decode errors use exit code `1` and a single
structured diagnostic object on stderr.

## Build

```bash
swift build
```

## Test

```bash
perl -e 'alarm shift; exec @ARGV' 30 swift test
perl -e 'alarm shift; exec @ARGV' 30 xcodebuild -quiet test -scheme PDKKit-Package -destination 'platform=macOS'
```

The repository's current verification result is 27 tests in 5 Swift Testing
suites plus a successful Xcode package test. The Xcircuite PDK integration
slice passes 6 tests in 1 suite with `xcodebuild`. The Xcode command may print
environment-specific IDE warnings while still returning success.

## Evidence boundary

```text
Manifest + standard views
          |
          v
Local inspection -> retained corpus -> immutable oracle comparison
                                             |
                                             v
                                      oracleCorrelated
```

`oracleCorrelated` is the highest state this package emits. A process-scoped
`processQualified` result requires independent ToolQualification evidence and
release approval outside this package. This boundary is intentional: a local
parser or retained fixture cannot establish manufacturing-process trust by
itself.

See `MILESTONES.md`, `CAPABILITY_REPORT.md`, `DESIGN.md`, `INTERFACES.md` and
`IMPLEMENTATION_PLAN.md` for the implementation boundary and qualification
limitations.
