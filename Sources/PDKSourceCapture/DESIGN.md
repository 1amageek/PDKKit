# PDK Source Capture

## Purpose and Scope

This module owns a bounded, immutable capture of the bytes actually consumed by
PDK validation. Parent: [PDKKit](../../DESIGN.md). Children:
[Capture](Capture/DESIGN.md) and [LocalCapture](LocalCapture/DESIGN.md).
It is independently buildable against the fixed CircuiteFoundation public products.
Legacy capture bounds one expected source. Invocation-bounded capture and candidate
discovery additionally require an explicit root, typed root-relative path, and
PDKCore accounting owner. Parser allocations remain with the document decoder.

## Responsibilities and Boundaries

Capture verifies actual owned bytes against an expected artifact reference and
publishes them only after successful read-session and root-capability cleanup.
Manifest, standard-view, rule-deck and oracle evidence readers consume captures
instead of reopening paths.
It does not decode a manifest, discover includes, resolve process semantics,
compile rules or models, or qualify a process. Captures do not claim to be a
complete PDK dependency graph.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKKit](../../DESIGN.md) | Parent | Exact parser input identity | Host reader composition | Existing result schemas remain authoritative |
| [PDKValidation](../PDKValidation/DESIGN.md) | Used by | Verified manifest input | Validation admission | Capture does not bound identity discovery |
| [PDKStandardViews](../PDKStandardViews/DESIGN.md) | Used by | Verified semantic input | View, rule and oracle admission | Manifest binding enforces resolved source identity |
| [CircuiteFoundation](../../../CircuiteFoundation/DESIGN.md) | Depends on | ArtifactAccessing, ArtifactReadSession, ContentDigesting | Fixed bounded access and digest protocols | Receipts alone do not prove the accumulated bytes |
| [Capture](Capture/DESIGN.md) | Child | Checked immutable capture | In-memory admission | Only verified bytes may be returned |
| [LocalCapture](LocalCapture/DESIGN.md) | Child | Root-bound local capture | Host adapter | Local paths are availability, not content identity |

## Architecture

```text
PDK validation / standard-view readers
    -> PDKSourceCapturing
        -> injected ArtifactAccessing + ContentDigesting
        -> checked immutable CapturedPDKSource
LocalPDKSourceCapturer
    -> root-capability FileSystem backend
    -> the same checked capture algorithm
```

## Contracts and Invariants

- Expected reference, final observed identity, owned byte count and digest agree.
- Sequential page offsets, nonempty progress before terminal completion, and
  cumulative byte limits are checked before appending or reserving storage.
- Capture's digest is computed from the same owned bytes exposed to its consumer.
- A successful capture has reached a terminal page and completed cleanup.
- Borrowed byte views cannot outlive their owner; no pointer escapes a borrow.
- No capture is published after a read, digest, cancellation or cleanup failure.
- The fixed public Foundation implementation remains unmodified.

## State, Ownership, and Lifecycle

One invocation owns one read session and accumulated immutable byte storage.
The local adapter owns its root capability and awaits its termination after
session termination on every path. No mutable global cache or shared parser state
is introduced. The caller retains the returned buffer; host Data conversion is
one explicit codec boundary copy and is included in the memory budget.

## Failure, Concurrency, and Constraints

Typed failures preserve the primary operation and cleanup failure when both occur.
Limits cover source bytes, page count, work and elapsed-time admission; host
defaults are documented policy and callers may supply valid budgets. Deadlines
are checked before/after backend operations and final digest/cleanup. They refuse
an over-budget result, and do not promise preemption of a blocking backend or
cleanup call. Successful cleanup remains mandatory even after the deadline. CPU materialization and
codec conversion must be accounted for, rather than advertised as zero-copy.
Capture invocations have independent state; backend actors own file lifetimes.

## Verification and Change Impact

[PDKSourceCaptureTests](../../Tests/PDKSourceCaptureTests) owns success, actual-byte
mismatch, byte/page/progress limits, cancellation and cleanup failure tests.
[PDKKitTests](../../Tests/PDKKitTests) owns real-file reader and CLI composition.
Lower contracts are tested before consumers. Result status/provenance shapes are
preserved; source errors are translated to structured blockers/failures, and
cancellation remains cancelled or is propagated as cancellation. No simulation,
DRC execution, WASM/Embedded or process qualification claim follows from these tests.

## Invocation Accounting Integration

SourceCapture depends on PDKCore's resource protocol, never on admission policy.
`PDKBoundedLocalSourceCapturing.capture` and `PDKLocalSourceDiscovering.discover`
are separate explicit capabilities implemented by `LocalPDKBoundedSourceCapturer`.
`PDKLocalSourceEnumerating` supplies controlled directory inventory under the same
root lifecycle and owner; candidate filtering remains Discovery-owned.
Capture and discovery require root URL, root ID, `ArtifactRelativePath`, per-source budget and one
invocation owner. They call only Foundation's controlled source discovery API;
exact capture supplies the expected descriptor and verifies the entire returned
reference before copying, and then hashes the same owned published bytes again.
The legacy capture protocol remains one-source admission and cannot satisfy these
bounded capabilities by implicit injection.

```text
explicit root + relative path + invocation owner
    -> acquire root/concurrency reservations
    -> Foundation controlled discovery -> immutable pages
    -> compare exact reference (exact mode only)
    -> reserve/copy/hash the same owned capture
    -> await root shutdown -> final resource/time check -> publish owner
```

The bridge maps Foundation read/hash/page/work/entry work and owned/temporary/open
extents onto readBytes/hashedBytes/pages/parserWork/scannedEntries/liveOwnedBytes/
temporaryBytes/openResources. Typed original errors survive the bridge, including
cancellation/deadline/closed errors. Each root descriptor is admitted before root
construction; each acquisition is admitted before opening. Primary and cleanup
failures remain distinct. Cleanup is awaited even after resource cancellation.
Managed extents cover declared payload and container capacities, not process RSS,
allocator rounding or host runtime overhead. Copies of captures share live-owner
receipts; the last copy releases capacity. Unaccounted Data export is refused for
bounded captures, which expose Span borrowing or an explicitly caller-owned copy.
