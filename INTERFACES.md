# PDKKit Interface Contract

## Common shape

```swift
public protocol DomainExecuting: Sendable {
    func execute(
        _ request: DomainRequest
    ) async throws -> XcircuiteEngineResultEnvelope<DomainPayload>
}
```

Requests carry a schema version, run ID and typed artifact references. Payloads contain domain metrics only. Diagnostics and artifacts belong to the shared envelope.

## Products

### PDKCore

PDK identity and immutable manifest reference.

### PDKDiscovery

Local PDK discovery without validation claims.

### PDKValidation

Completeness and semantic validation.

### PDKStandardViews

Parser-backed canonical inspection for LEF, GDSII, OASIS, SPICE and Liberty
assets, including the supported detailed numeric semantics.

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
| `LocalPDKValidator` | Verify inputs, manifest identity, assets, hashes and cross-view coverage |
| `PDKCorpusSuiteValidator` | Validate retained corpus suite shape and safe relative manifest paths |
| `LocalPDKCorpusValidator` | Execute deterministic valid/blocked/failed corpus cases over `PDKValidating` |
| `LocalPDKStandardViewInspector` | Parse standard views into canonical detailed IR with input integrity checks |
| `PDKManifestViewBindingValidator` | Compare canonical view facts with manifest layer/device mappings |
| `LocalPDKManifestViewInspector` | Resolve a manifest asset, inspect it and return binding evidence |
| `LocalPDKOracleComparator` | Compare manifest-bound canonical facts against digest-bound immutable expectations |
| `PDKQualificationGate` | Require matching retained corpus and oracle evidence for `oracleCorrelated` |
| `LocalPDKQualificationEvaluator` | Load immutable corpus/oracle payload artifacts and return a qualification envelope |

`PDKValidationPayload` exposes findings, resolved immutable references, a
`PDKQualificationScope` and a `PDKCapabilityReport`. Both reports retain the
PDK digest and explicitly preserve the `unverified` qualification state.

`PDKCorpusValidationRequest` points to a suite and a bounded corpus root.
`PDKCorpusValidationPayload` contains one result per case, expected and
observed outcomes, finding codes, missing expected codes and corpus
limitations. Expected negative cases are successful corpus cases when the
validator reproduces the declared blocked or failed outcome.

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
