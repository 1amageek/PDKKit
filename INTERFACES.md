# PDKKit Interface Contract

The breaking identity-construction contract is owned by [Identity](Sources/PDKCore/Identity/DESIGN.md) and
[ManifestLoading](Sources/PDKDiscovery/ManifestLoading/DESIGN.md).

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
and execution provenance.

## Products

### PDKCore

PDK identity and immutable manifest reference.

### PDKSourceCapture

Independently buildable host source admission, depending only on the fixed
CircuiteFoundation products. The owning contract is
[PDKSourceCapture](Sources/PDKSourceCapture/DESIGN.md).

```swift
public protocol PDKSourceCapturing: Sendable {
    func capture(_ intent: ArtifactAccessIntent)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource
}

public protocol PDKLocalSourceCapturing: Sendable {
    func capture(
        reference: ArtifactReference,
        at locator: ArtifactLocator,
        relativeTo root: URL?,
        budget: ArtifactAccessBudget
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource
}
```

`StandardPDKSourceCapturer` accepts an injected `ArtifactAccessing` service and
`ContentDigesting` implementation. `LocalPDKSourceCapturer` uses the secure root
capability backend. `CapturedPDKSource` has no arbitrary public initializer; its
immutable buffer was checked against the expected content identity. `withBytes`
lends a `Span`; `data(maximumByteCount:)` makes an explicit bounded codec copy.
`PDKSourceCaptureError` retains both primary and cleanup failures.

Local validation, standard-view, manifest-view, rule-deck, external rule-deck
admission and oracle comparison inject `PDKLocalSourceCapturing` and optionally
`ArtifactAccessBudget`. Their default is the source module's capture policy.
`projectRootPath` remains a base for workspace-relative availability; it does not
restrict separately supplied absolute availability. Explicit capture roots do
restrict absolute sources to their descendants. Identity discovery preceding
capture and codec/parser allocations are outside this budget.

### PDKDiscovery

Local PDK discovery without validation claims. `PDKManifestLoading.discover` and
`loadExact` return `PDKLoadedManifest` from captured bytes. Exact loading preserves
the supplied reference and never rediscovers identity. The loaded value has no
public arbitrary initializer or Codable conformance.

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
| `PDKManifestCodec` | Decode and encode the current manifest schema; obsolete schemas and field names fail closed |
| `LocalPDKManifestLoader` | Capture the selected manifest identity and decode metadata from the same bytes |
| `LocalPDKAssetResolver` | Resolve manifest-relative assets within the manifest root and hash bytes |
| `PDKManifestValidator` | Validate typed identity, layer, device, corner and mapping semantics |
| `LocalPDKDiscoverer` | Discover candidate manifests without qualification claims |
| `LocalPDKValidator` | Verify inputs, manifest identity, assets, hashes, parser-backed cross-view semantics and coverage |
| `PDKCorpusSuiteValidator` | Validate retained corpus suite shape and safe relative manifest paths |
| `LocalPDKCorpusValidator` | Execute deterministic valid/blocked/failed corpus cases over `PDKValidating` |
| `LocalPDKStandardViewInspector` | Parse standard views into canonical detailed IR with input integrity checks |
| `PDKManifestViewBindingValidator` | Compare canonical view facts with manifest layer/device mappings |
| `LocalPDKManifestViewInspector` | Capture the manifest, resolve its asset and verify exact retained source identity before binding |
| `PDKRuleDeckInspecting` | Inspect a manifest-bound rule-deck asset through a typed request/payload contract |
| `LocalPDKRuleDeckInspector` | Verify rule-deck integrity, executable statements and mapped-layer evidence |
| `PDKExternalStandardViewResultProviding` | Supply a JSON-encoded typed result from an external standard-view backend |
| `PDKExternalRuleDeckResultProviding` | Supply a JSON-encoded typed result from an external rule-deck backend |
| `ExternalPDKStandardViewInspector` | Decode and fail closed on external standard-view result contract mismatches |
| `ExternalPDKRuleDeckInspector` | Decode and fail closed on external rule-deck result, asset and PDK-digest mismatches |
| `LocalPDKOracleComparator` | Compare manifest-bound canonical facts against digest-bound immutable expectations |

`PDKValidationPayload` exposes findings, resolved immutable references, a
`standardViewResults` collection and a `PDKCapabilityReport`. Each
standard-view result retains its format, execution status, parser-backed
payload and PDK digest.
Each immutable `PDKResolvedAsset.reference` is its sole content identity.
Identity values use strict schema 2 and reject obsolete duplicate fields.
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
reproduces the declared blocked or failed outcome. Corpus schema version 2 is
required and includes rule-deck checks in the case contract.

`PDKStandardViewInspectionRequest` and
`PDKManifestViewInspectionRequest` are agent-facing engine requests.
The authoritative expected-source propagation and request versions are defined in
[PDKStandardViews](Sources/PDKStandardViews/DESIGN.md). Their
payloads retain parser identity, canonical layer/cell/model/pin/timing facts,
numeric SPICE model parameters, subcircuits, Liberty cells, timing tables and
the standard-owned typed `LEFDocument` for physical declarations,
unit declarations, source artifact references, findings, binding evidence and
explicit qualification limitations. `PDKOracleExpectation` and
`PDKOracleRequest` bind those facts to a manifest digest; `PDKOracleComparisonPayload`
records field-level mismatches. ToolQualification consumes retained corpus and
oracle artifacts when evaluating process-scoped trust. PDKKit does not claim
complete vendor-specific language coverage or process qualification.

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
concrete `.xcircuite` workspace and run-artifact stores. The detailed
standard-view suite remains independently reproducible from the package test
bundle.

## Prepared Execution Source Binding

The non-overridable `matchPDKExecutionConsumption(_:against:observed:resources:)`
composes existing schema-2 CP matching with the
[execution binding contract](Sources/PDKProfileAdmission/Consumption/ExecutionBinding/DESIGN.md).
PDKCore owns schema-1 structural `PDKExecutionSourceObservation`,
`PDKExecutionSourceBinding`, `PDKExecutionEntry`, and
`PDKExecutionConsumptionClaim` values. Observations carry domain input/configuration/
grammar identities and every actual captured occurrence, including external entry
parents and inherited preprocessing; they are untrusted data.

The result `PDKMatchedExecutionConsumption` has no public arbitrary initializer or
Codable conformance. It retains `consumption: PDKMatchedConsumption`,
`bindingIdentity`, `executionInputIdentity`, `configurationIdentity`,
`grammarPolicyIdentity`, checked `sources`, `sourceBindings`, and `entries`. Retain
the enclosing checked owner while borrowing its source values. Domain preparation
and host evidence authentication remain independent owners; neither a decoded
claim nor this match proves numerical execution or qualification.
