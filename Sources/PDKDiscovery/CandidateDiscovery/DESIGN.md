# Candidate Discovery

## Purpose and Scope

Parent: [PDK Discovery](../DESIGN.md). No children. This is a host-only local adapter. Own invocation-bounded
candidate selection from explicit local roots; return candidates, not profiles.

## Responsibilities and Boundaries

The caller supplies checked roots, an exact requested descriptor, an optional
process ID filter and one resource accountant. Foundation owns secure enumeration;
ManifestLoading owns same-read input association and decoding. This component owns
root binding checks, candidate selection and retained output collection capacity.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDK Discovery](../DESIGN.md) | Parent | Discovery composition | Module index | Legacy discovery remains per-source |
| [ManifestLoading](../ManifestLoading/DESIGN.md) | Depends on | PDKBoundedManifestLoading | Retained source and decoded metadata | No separate path decode |
| [LocalCapture](../../PDKSourceCapture/LocalCapture/DESIGN.md) | Depends on | PDKLocalSourceEnumerating | Controlled immutable inventory | Original root is reused for each load |
| [Profile accounting](../../PDKCore/Profile/DESIGN.md) | Depends on | PDKAdmissionResourceAccounting | Invocation deadline and costs | Same accountant throughout |

## Architecture

```text
checked roots + descriptor + optional process ID + shared resources
    -> binding preflight -> controlled root inventory
    -> regular-file pdk.json -> bounded manifest load -> process comparison
    -> retained candidate collection
```

## Contracts and Invariants

`PDKBoundedDiscoveryRoot` requires an absolute file URL with no base URL, a checked
inventory intent carrying its root ID, and an explicit source budget. The service
rejects duplicate root IDs and duplicate URL bindings before I/O. URL strings are
compared as supplied; no canonicalization, alias resolution or authorization
substitution occurs. Caller-owned input storage is outside managed output capacity.

`PDKBoundedDiscovering.discover(roots:descriptor:processID:resources:)` returns only
a completed `PDKBoundedDiscoveryResult`. Entries are considered in caller root order
and the backend inventory order. Only regular files whose final path segment equals
`PDKManifest.fileName` are loaded. Duplicate process/version candidates remain
separate candidates. Filtering compares the loaded manifest's process ID, preserving
Swift String equality; no profile admission or automatic selection is performed.

Roots and candidates are charged before enumeration and load respectively. Each
loop, comparison and collection migration is admitted before work. Checks before and
after asynchronous operations and publication use the same invocation accountant;
the accountant owns the shared deadline, while each lower operation also retains
its caller-selected per-operation limit. Every failure throws typed incomplete
search evidence (completed-root and observed-candidate counts), never partial success.

## Runtime Flows

```text
preflight -> charge root -> await inventory -> inspect entries
    -> charge candidate -> await load -> compare filter -> grow/append output
    -> next root -> final check -> publish
failure/cancel -> unwind owned output and inventory -> typed incomplete error
```

## State, Ownership, and Lifecycle

Output uses an immutable published random-access collection with explicit optional
candidate slots. Growth doubles the logical slot capacity with overflow checking;
reserve `capacity * MemoryLayout<PDKBoundedCandidate?>.stride` before allocation.
Old and new slots are simultaneously charged during migration. Every migrated
candidate is reconstructed with the new shared reservation; the old slots and lease
are released after migration. No guessed maximum preallocation, cumulative dead
capacity, new shared mutable owner or global cache is used.

Each candidate retains its loaded source/document, original inventory entry and
latest collection capacity reservation. Copies of a candidate or result retain
those owners until the last copy releases them. Managed capacity means these exact
logical element slots, not allocator rounding, object headers or process RSS.
| State | Storage and isolation | Release boundary |
|---|---|---|
| Dependencies | Immutable Sendable protocol handles | Service lifetime |
| Candidate slots/count | Invocation-local Array/value, exclusive mutation before publication | Last result/candidate copy via shared capacity receipt |
| Accountant test state | Existing common Mutex fixture | Last reservation copy |

There is no conditional compilation, mutable shared state or target-specific
synchronization path in this host component. Native execution is verified here;
WASM/Embedded filesystem execution is outside this adapter's supported scope.
Foundation and ManifestLoading retain their own admitted storage through their
public owner contracts. Extracted raw metadata is not a substitute for retaining
its owner handle.

## Failure, Concurrency, and Constraints

The service has only immutable injected enumerator and loader dependencies;
invocation-local buffers are never shared before publication. No platform branch
changes Sendable or synchronization semantics. No filesystem backend, FileManager
traversal, legacy referencer or legacy loading fallback participates. Injected
services must satisfy the lower contracts, including complete inventories and
same-read association. Malformed or unsupported manifests abort the whole search.

## Verification and Change Impact

[BoundedCandidateDiscoveryTests](../../../Tests/PDKDiscoveryTests/BoundedCandidateDiscoveryTests.swift)
uses real isolated temporary roots. It proves same-captured-byte filtering,
cumulative root/read/decode limits, no-follow symlinks, malformed/format failure,
cancellation stopping later roots, pre-allocation output refusal, and last-copy
candidate/result retention. Test accounting uses the existing common Mutex fixture;
production selection adds no mutable shared state. Recheck manifest and enumeration
composition when either lower public contract changes; qualification stays with
its existing owner.
