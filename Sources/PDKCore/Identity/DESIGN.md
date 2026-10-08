# PDK Identity

## Purpose and Scope

Implemented single-source identity values. The loader and caller migration
remain owned by the dependent ManifestLoading sprint. Parent:
[PDKCore](../DESIGN.md). No children.

Own manifest-reference claims and resolved-asset values with one content-identity
authority. Move the affected reference/value/error files into this component
when implementing it. Do not reorganize unrelated Core source.

## Responsibilities and Boundaries

`ArtifactReference` owns digest, byte count and descriptor. `ArtifactLocator`
owns availability. A PDK value associates those contracts with process metadata
or an asset ID. Value construction and decoding enforce structural consistency;
neither proves that bytes have been read or establishes qualification.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKCore](../DESIGN.md) | Parent | PDK values | Module composition | Core does not depend on capture or discovery |
| [CircuiteFoundation](../../../../CircuiteFoundation/DESIGN.md) | Depends on | ArtifactReference, ArtifactLocator | Identity and availability authorities | Full reference comparison includes descriptor |
| [ManifestLoading](../../PDKDiscovery/ManifestLoading/DESIGN.md) | Used by | Reference construction | Metadata derived from admitted bytes | A decoded reference remains a claim |
| [PDKValidation](../../PDKValidation/DESIGN.md) | Used by | Resolved references | Initial inventory and downstream joins | Compare reference, not the availability-bearing container |
| [PDKStandardViews](../../PDKStandardViews/DESIGN.md) | Used by | Exact source reference | View/rule admission | Existing capture remains required |

## Architecture

```text
PDKReference                         PDKResolvedAsset
  processID + version                  assetID
  manifest: ArtifactReference          reference: ArtifactReference
  manifestLocator: ArtifactLocator     locator: ArtifactLocator
             |                                  |
             +---- no stored digest/count ------+
```

## Contracts and Invariants

Public shape; each primary type belongs in its own file:

```swift
public struct PDKReference: Sendable, Hashable, Codable {
    public let manifest: ArtifactReference
    public let manifestLocator: ArtifactLocator
    public let processID: String
    public let version: String
    public var digest: String { manifest.digest.hexadecimalValue }

    public init(
        manifest: ArtifactReference,
        manifestLocator: ArtifactLocator,
        processID: String,
        version: String
    ) throws(PDKReferenceError)
}

public struct PDKResolvedAsset: Sendable, Hashable, Codable {
    public let assetID: String
    public let reference: ArtifactReference
    public let locator: ArtifactLocator

    public init(
        assetID: String,
        reference: ArtifactReference,
        locator: ArtifactLocator
    ) throws(PDKResolvedAssetError)
}
```

| Invariant | Enforcement |
|---|---|
| Digest and size have one stored authority | Remove `PDKReference.digest` storage and `PDKResolvedAsset.computedSHA256`, `computedByteCount`, stored `path` and `artifactReference()` |
| Manifest claim is structurally usable | Reject blank process/version, non-SHA-256 identity, non-JSON format and unsupported technology kind |
| Availability describes the claimed content type | Validate locator role/format and kind under the explicit PDK descriptor policy |
| Exact references are preserved | Accept technology kinds `technology` and `pdk.technology`; preserve the producer-defined role and supplied reference without rewriting its descriptor |
| Asset projection is unambiguous | Reject blank asset ID or incompatible locator/reference descriptors; compare normalized PDK kind intent, retaining the reference unchanged |
| Decode cannot bypass construction checks | Custom decoding invokes the same checked initializer |
| Location is not semantic identity | Use `.manifest` or `.reference` for content equality and canonical dependency identity; container Hashable includes availability |

Artifact roles remain Foundation-owned open producer tokens. A stage output can
be consumed as a manifest without changing its artifact role to input; the
consuming operation records its own input relationship in provenance.

The descriptor policy permits the existing generic technology locator to describe
the PDK-qualified technology reference, and likewise the existing asset-intent
normalization. It never changes the expected reference supplied to capture.
Identity is exactly that reference; normalization applies only to checking intent.

Both value encodings gain `schemaVersion: 2`; only version 2 is accepted. Encode
the stored fields above plus the version. Reject obsolete duplicate identity/path
keys even when their values agree. The manifest document schema remains version 1.
Breaking envelope migration is owned by [ManifestLoading](../../PDKDiscovery/ManifestLoading/DESIGN.md#verification-and-change-impact).

## State, Ownership, and Lifecycle

Values are immutable and Sendable. They own no handle, session, retained source
buffer or shared mutable state. Copies preserve claims; copying does not establish
that the artifact remains available. Later readers must still capture exact bytes.
No target-conditional storage or Sendable conformance is introduced.

## Failure, Concurrency, and Constraints

Use typed `PDKReferenceError` and `PDKResolvedAssetError` for invalid
metadata, descriptor or schema. Remove errors whose only purpose was detecting
disagreement between duplicate digest/count fields. No I/O, actor or Mutex is
needed for these value checks. UInt64 byte counts remain owned by Foundation;
Int64 conversion belongs only at an existing bounded consumer boundary.

## Verification and Change Impact

`PDKIdentityValueTests` owns constructor/decoder refusal, full descriptor
retention, immutable field usage and deterministic serialization. Reject version
1 and contradictory duplicate-field payloads; round-trip the generic and
PDK-qualified technology descriptors and producer-defined roles without changing
the reference.
Compile each affected public caller after removing duplicate constructor fields
and the projection method. Recheck validation's inventory-to-child reference join.

The current public API counterexample changes `computedSHA256` and obtains a
different reference from `artifactReference()`. The new API must make this state
unrepresentable, and reject its former wire representation. This is a value
contract, not evidence of source admission, portability or process qualification.
