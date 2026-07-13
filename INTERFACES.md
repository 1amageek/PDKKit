# PDKKit Interface Contract

## Common shape

```swift
public protocol DomainExecuting: Sendable {
    func execute(
        _ request: DomainRequest
    ) async throws -> XcircuiteEngineResultEnvelope<DomainPayload>
}
```

Requests carry a schema version, run ID and typed compatibility envelope
references. PDKCore resolves those inputs through the corresponding
CircuiteFoundation `ArtifactReference` before consuming bytes. Payloads
contain domain metrics only. Diagnostics and artifacts belong to the shared
envelope.

## Products

### PDKCore

PDK identity and immutable manifest reference.

### PDKDiscovery

Local PDK discovery without validation claims.

### PDKValidation

Completeness and semantic validation.

### PDKStandardViews

Parser-backed canonical inspection for LEF, GDSII, OASIS, SPICE, Liberty and
rule-deck assets, including the supported detailed numeric semantics.

### PDKKit

Umbrella API.

### Concrete local implementations

| Type | Contract |
|---|---|
| `PDKManifestCodec` | Decode, migrate and encode versioned manifests |
| `PDKManifestReferenceBuilder` | Build an immutable manifest reference with SHA-256 and byte count |
| `LocalPDKAssetResolver` | Resolve manifest-relative assets within the manifest root and hash bytes |
| `PDKManifestValidator` | Validate typed identity, layer, device, corner and mapping semantics |
| `LocalPDKDiscoverer` | Discover candidate manifests without qualification claims |
| `LocalPDKValidator` | Verify inputs, manifest identity, assets, hashes, parser-backed cross-view semantics and coverage |
| `PDKCorpusSuiteValidator` | Validate retained corpus suite shape and safe relative manifest paths |
| `LocalPDKCorpusValidator` | Execute deterministic valid/blocked/failed corpus cases over `PDKValidating` |
| `LocalPDKStandardViewInspector` | Parse standard views into canonical detailed IR with input integrity checks |
| `PDKManifestViewBindingValidator` | Compare canonical view facts with manifest layer/device mappings |
| `LocalPDKManifestViewInspector` | Resolve a manifest asset, inspect it and return binding evidence |
| `PDKRuleDeckInspecting` | Inspect a manifest-bound rule-deck asset through a typed request/payload contract |
| `LocalPDKRuleDeckInspector` | Verify rule-deck integrity, executable statements and mapped-layer evidence |
| `PDKExternalStandardViewResultProviding` | Supply a JSON-encoded shared result envelope from an external standard-view backend |
| `PDKExternalRuleDeckResultProviding` | Supply a JSON-encoded shared result envelope from an external rule-deck backend |
| `ExternalPDKStandardViewInspector` | Decode and fail closed on external standard-view envelope contract mismatches |
| `ExternalPDKRuleDeckInspector` | Decode and fail closed on external rule-deck envelope, asset and PDK-digest mismatches |
| `LocalPDKOracleComparator` | Compare manifest-bound canonical facts against digest-bound immutable expectations |
| `PDKQualificationGate` | Require matching retained corpus and oracle evidence for `oracleCorrelated` |
| `LocalPDKQualificationEvaluator` | Load immutable corpus/oracle payload artifacts and return a qualification envelope |

`PDKValidationPayload` exposes findings, resolved immutable references, a
`standardViewResults` collection, a `PDKQualificationScope` and a
`PDKCapabilityReport`. Each standard-view result retains its format, execution
status, parser-backed payload and PDK digest. Both reports retain the PDK digest
and explicitly preserve the `unverified` qualification state.
Each `PDKResolvedAsset` also exposes `foundationArtifactReference()`, the
canonical immutable identity used by downstream boundary code.
`ruleDeckResults` retains rule-deck text integrity, mapped layer coverage,
statement counts, per-layer token/statement evidence and typed findings. The
same payload is returned by `inspect-rule-deck` and embedded in manifest
validation results.

`PDKCorpusValidationRequest` points to a suite and a bounded corpus root.
`PDKCorpusValidationPayload` contains one result per case, expected and
observed outcomes, finding codes, missing expected codes and corpus
limitations. Each case can retain standard-view and rule-deck check results.
Expected negative cases are successful corpus cases when the validator
reproduces the declared blocked or failed outcome. Corpus schema version 2
adds rule-deck checks while decoding version 1 suites without them.

`PDKStandardViewInspectionRequest` and
`PDKManifestViewInspectionRequest` are agent-facing engine requests. Their
payloads retain parser identity, canonical layer/cell/model/pin/timing facts,
numeric SPICE model parameters, subcircuits, Liberty cells, timing tables and
unit declarations, source artifact references, findings, binding evidence and
explicit qualification limitations. `PDKOracleExpectation` and
`PDKOracleRequest` bind those facts to a manifest digest; `PDKOracleComparisonPayload`
records field-level mismatches. `PDKQualificationGate` consumes retained
corpus and oracle payloads and emits only the local `oracleCorrelated` state.
It does not claim complete vendor-specific language coverage or process qualification.

`PDKRuleDeckInspectionRequest` is an agent-facing request for a single mapped
rule-deck asset. Its payload retains the immutable source reference, statement
count, expected/observed layer IDs, per-layer evidence and explicit grammar
limitations.

External providers return JSON-encoded `XcircuiteEngineResultEnvelope` values
with the request schema version and run ID. The external inspectors validate
the envelope before returning it, then validate the payload asset identity,
standard-view format when present, completed-payload validity, digest-bearing
standard-view source binding and rule-deck asset/PDK digest binding. Schema,
run, asset, format, source-reference and digest mismatches are blocked;
malformed JSON, provider failures and invalid completed payloads are returned
as structured failures. The contract does not qualify the external process.


## Error contract

- Throw only when execution cannot produce a valid result envelope.
- Represent design findings and failed checks as typed diagnostics and a completed domain payload.
- Represent missing prerequisites or insufficient semantics as `blocked`.
- Preserve cancellation as `cancelled`.
- Do not swallow parser, process or persistence failures.

## Xcircuite adapter

The adapter lives in the Xcircuite package and must:

1. resolve project-relative references through XcircuitePackage;
2. verify input digests;
3. evaluate ToolQualification requirements;
4. invoke the injected engine protocol;
5. persist every returned artifact;
6. map diagnostics and status to FlowStageResult;
7. attach design, PDK and tool provenance;
8. leave approval and resume handling to DesignFlowKernel.

The implemented adapters are `PDKDiscoveryFlowStageExecutor`,
`PDKValidationFlowStageExecutor`,
`PDKStandardViewInspectionFlowStageExecutor`, `PDKOracleFlowStageExecutor` and
`PDKQualificationFlowStageExecutor`. Each persists the complete result
envelope under the run's stage `raw` directory and exposes the persisted
reference as a flow artifact. Xcircuite owns the final package build and
headless integration verification; PDKKit's own detailed standard-view suite
is independently reproducible with the package Xcode test bundle.
