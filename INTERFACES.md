# PDKKit Interface Contract

## Common shape

```swift
public protocol DomainExecuting: Sendable {
    func execute(
        _ request: DomainRequest
    ) async throws -> DomainResult
}
```

Requests carry a schema version, run ID and Foundation artifact locators.
PDKCore resolves those inputs to immutable `ArtifactReference` values before
consuming bytes. Domain result types carry their own diagnostics, artifacts
and execution provenance; no generic result envelope is required.

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
| `PDKExternalStandardViewResultProviding` | Supply a JSON-encoded typed result from an external standard-view backend |
| `PDKExternalRuleDeckResultProviding` | Supply a JSON-encoded typed result from an external rule-deck backend |
| `ExternalPDKStandardViewInspector` | Decode and fail closed on external standard-view result contract mismatches |
| `ExternalPDKRuleDeckInspector` | Decode and fail closed on external rule-deck result, asset and PDK-digest mismatches |
| `LocalPDKOracleComparator` | Compare manifest-bound canonical facts against digest-bound immutable expectations |
| `PDKQualificationGate` | Require matching retained corpus and oracle evidence for `oracleCorrelated` |
| `LocalPDKQualificationEvaluator` | Load immutable corpus/oracle payload artifacts and return a qualification result |

`PDKValidationPayload` exposes findings, resolved immutable references, a
`standardViewResults` collection, a `PDKQualificationScope` and a
`PDKCapabilityReport`. Each standard-view result retains its format, execution
status, parser-backed payload and PDK digest. Both reports retain the PDK digest
and explicitly preserve the `unverified` qualification state.
Each `PDKResolvedAsset` also exposes `foundationArtifactReference()`, the
canonical immutable identity used by downstream boundary code.
`PDKStandardViewIR.sourceArtifact`, `PDKRuleDeckInspectionPayload.sourceArtifact`
and `PDKOracleComparisonPayload.oracleArtifact` retain the canonical
CircuiteFoundation identity directly in the domain payload.
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

External providers return JSON-encoded typed domain results with the request
schema version and run ID. The external inspectors validate the result before
returning it, then validate the payload asset identity,
standard-view format when present, completed-payload validity, digest-bearing
standard-view source binding and rule-deck asset/PDK digest binding. Schema,
run, asset, format, source-reference and digest mismatches are blocked;
malformed JSON, provider failures and invalid completed payloads are returned
as structured failures. The contract does not qualify the external process.


## Error contract

- Throw only when execution cannot produce a valid typed result.
- Represent design findings and failed checks as typed diagnostics and a completed domain payload.
- Represent missing prerequisites or insufficient semantics as `blocked`.
- Preserve cancellation as `cancelled`.
- Do not swallow parser, process or persistence failures.

## Flow integration

PDKKit engines conform directly to their domain protocols and to the shared
Foundation artifact, diagnostic and provenance contracts. DesignFlowKernel
injects those protocols, applies tool-qualification and flow policy, and
persists typed results through its ledger protocol. Xcircuite supplies the
concrete `.xcircuite` workspace and run-artifact stores. PDKKit does not define
an adapter or compatibility facade, and its detailed standard-view suite
remains independently reproducible from the package test bundle.
