# PDKKit Requirements

## Goal

Provide one immutable, process-scoped source of truth for every design and signoff stage.

## Required functions

| Function | Required behavior | Priority |
|---|---|---:|
| Manifest schema and migration | Decode, validate and migrate process identity, version and asset references. | P0 |
| Local discovery | Discover candidate PDK installations without claiming semantic validity. | P1 |
| Asset resolution and hashing | Resolve layer maps, models, cells, decks and corner assets with immutable digests. | P0 |
| Layer and device semantics | Represent manufacturing layers, purposes, devices, terminals and extraction recognition. | P0 |
| Corner model | Represent PVT, RC, EM and reliability corners and their cross-domain mapping. | P0 |
| Cross-view validation | Validate LEF, GDS/OASIS, SPICE, Liberty and rule-deck consistency. | P1 |
| Qualification scope export | Expose the process profile and deck digests needed by ToolQualification. | P0 |

## Required outcomes

- Every downstream request carries the same PDK digest.
- Missing process semantics block execution.
- A PDK can be inspected and validated headlessly.

## Common platform requirements

- Public execution surfaces are protocol-first, Sendable and dependency-injected.
- Requests and payloads are Codable, Hashable and schema-versioned.
- PDKCore uses CircuiteFoundation `ArtifactLocator` and `ArtifactReference` for
  artifact intent and verified identity. The existing XcircuiteFileReference
  shape remains only as a compatibility envelope projection.
- Diagnostics contain a stable code, severity, affected entity and suggested actions.
- Unsupported semantics and missing prerequisites produce blocked results.
- Native and external-tool backends conform to identical request and payload schemas.
- Execution capability, corpus validation, oracle correlation, process qualification and release approval remain distinct.
- Xcircuite owns flow construction, artifact persistence, qualification gates, repair loops, approval and resume.
- The package never imports Xcircuite or circuit-studio.

## Required developer surfaces

- Typed API
- Deterministic JSON CLI
- Positive and negative fixtures
- Contract and parser round-trip tests
- Reference corpus
- Capability and limitation report
- Xcircuite stage adapter tests
