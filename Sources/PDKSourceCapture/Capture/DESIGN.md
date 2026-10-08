# Capture

## Purpose and Scope

Parent: [PDK Source Capture](../DESIGN.md). No children. Own the capture protocol,
checked immutable source, policy and injected capture algorithm.

## Responsibilities and Boundaries

Own actual-byte verification, sequential accumulation, limits and session cleanup.
Availability resolution and local root opening belong to LocalCapture.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | Parent | Source admission | Module composition | No parser semantics |
| [LocalCapture](../LocalCapture/DESIGN.md) | Used by | Injected capture | Host service | Always await cleanup |

## Architecture

```text
intent -> read pages -> check/accumulate owned bytes -> digest exact buffer
       -> validate terminal identity -> await close -> immutable capture
```

## Contracts and Invariants

The parent admission invariants are owned by this component. The initializer of
the captured type validates expected byte count and digest; arbitrary receipts
cannot create a verified source. Safe immutable storage provides synchronous
borrowed views, with an explicit bounded conversion at Foundation codec boundaries.

## Failure, Concurrency, and Constraints

Read and digest errors remain typed. Always complete cleanup; combine primary and
cleanup failures without replacing either with success. Check cancellation and
page progress in the caller's task. Limits apply before allocation and appending.

## Verification and Change Impact

Tests are [PDKSourceCaptureTests](../../../Tests/PDKSourceCaptureTests).
Use injected read sessions to reject false receipts, repeated/empty pages,
truncation, oversized pages and cleanup failure. Real local access is covered by
LocalCapture tests. Admission changes require affected PDK reader tests.

## Invocation-Owned Storage

Bounded construction reserves copied source bytes before page materialization and
retains the receipt within `CapturedPDKSource`. Cooperative digest updates use one
reserved chunk of at most 4096 bytes, admit hashedBytes/parserWork before copying
or hashing, and check before/after each chunk. Span consumers borrow the immutable
source without Data conversion. Bounded `data` refuses an unowned copy; the explicit
bounded capture exposes no additional unowned Data-export API. A downstream domain
may borrow its Span and explicitly admit a required conversion under its own owner.

### Content-safe profile aliasing

`CapturedPDKSource.rebinding(reference:resources:)` creates an immutable alias only
when the supplied full reference has the checked buffer's exact byte count and
digest algorithm/value. Comparison work and final cancellation/deadline checks
use the caller's invocation accounting. The alias carries the supplied descriptor
and retains the same bytes and reservation; no copy, reopen or hash occurs. A
different content identity throws a typed capture failure. Descriptor/domain
selection remains the profile admission owner's responsibility. Original and
aliased copies keep the charge until the last buffer owner is released.
Legacy captures without an invocation-accounted storage owner are rejected with
an explicit unsupported-budget capability error before alias publication.
