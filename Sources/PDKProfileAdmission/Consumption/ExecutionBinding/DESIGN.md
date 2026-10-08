# Execution Source Binding

## Purpose and Scope

Status: proposed; no production API or behavioral proof exists yet. Parent:
[Consumption](../DESIGN.md). No children. Own the non-overridable connection between
its strict profile-scoped projection and a domain's complete prepared source graph.
This closes PN5's external circuit/include boundary without changing profile identity.

## Responsibilities and Boundaries

Validate explicit occurrence correspondence and entry context. PDKCore owns the
structural wire values; the domain owns actual capture, grammar, source graph and
prepared executable input. The host authenticates the retained domain observation
artifact and supplies the exact prepared owner. This component neither parses
SPICE/Liberty nor observes numerical operating conditions or grants qualification.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Consumption](../DESIGN.md) | parent | CP-01..06 and retained stage projection | Strict inner graph comparison | Do not weaken preprocessing or corner equality |
| [Profile values](../../../PDKCore/Profile/DESIGN.md) | depends on | Selection/source/runtime authority and proposed wire values | Neutral occurrence binding | Wire data is not domain execution authority |
| [Core preparation](../../../../../CoreSpice/Sources/CoreSpiceIO/SimulationPreparation/DESIGN.md) | used by | Prepared actual source graph | Circuit-to-library entries | Preserve inherited parameter identity and physical directive position |
| [STA preparation](../../../../../TimingEngine/Sources/STAEngine/PreparedExecution/DESIGN.md) | used by | Owned per-corner Liberty source selection | Direct root entries | No fabricated named process observation |
| [Host](../../../../../Xcircuite/Sources/Xcircuite/ProfileExecution/DESIGN.md) | used by | Exact prepared execution, evidence publication | Authenticated composition | Decoded claims are not prepared owners |

## Architecture

```text
admitted profile -> CP projection ---------------------+
                                                     -> execution binding -> matched owner
domain prepared graph -> occurrence/entry observations +
                          full input identity
matched owner + same domain prepared owner -> domain execution -> retained evidence
```

## Contracts and Invariants

EB-01: The execution graph identifies every captured input occurrence, exact full
reference, selected section, preprocessing identity and actual incoming edge in
grammar order. Repeated content and inactive directives retain their domain meanings.
The domain computes `executionInputIdentity` from the complete graph, root identity
and grammar/policy identity; diagnostic paths and availability do not enter it.

EB-02: Each projected occurrence has exactly one ordered
`PDKExecutionSourceBinding(profileOccurrenceID, executionOccurrenceID)`; actual
execution IDs are unique within this correspondence. All contributing occurrences
inside a selected profile subtree must be represented, in the same lexical order.
Missing, extra, duplicated, reordered or substituted contributors fail. Inputs
outside those subtrees remain visible in full execution provenance; they cannot
be silently substituted for a required view or merged into a selected library.
An extra contributing profile entry also fails; repeated entries require an
explicitly representable admitted projection, otherwise capability refusal.

EB-03: A projected root is a *scope* root. `PDKExecutionEntry` associates it with
an actual execution occurrence. A direct execution root has an explicit null
external parent/edge. An included root records the actual preceding external
parent occurrence, full parent reference and complete physical incoming dependency.
The parent and edge must agree with the domain graph. Descendants retain their
actual parent relation through EB-02. Never replace an actual external parent by
a guessed nil parent, omit the boundary record or invent an include position.

EB-04: Root source/section/corner/preprocessing context and every descendant
context must equal the admitted projection. External inherited `.param` values
are not discarded or reset to the expected environment. A different environment
requires an explicitly authored and re-admitted profile definition; this sprint
provides no automatic rebasing, parameter equivalence or context relaxation.
Unavailable bounded context semantics fail before execution.

EB-05: `PDKExecutionConsumptionClaim` schema 1 contains the existing schema-2
`PDKConsumptionClaim`, complete execution-input identity, ordered occurrence
bindings and root-entry records. A framed `PDKKit.Profile.ExecutionBinding` v1
digest binds projection identity plus these exact fields. It is separate from
profile selection and CP projection identities, whose framing stays unchanged.
Canonical source/edge/reference framing reuses its existing owner; negative zero,
ordering, length and checked arithmetic rules apply consistently.

| Proposed value | Required structural fields / ownership |
|---|---|
| PDKExecutionSourceObservation | Ordered full domain occurrence table (IDs, references, sections, preprocessing, parent/edge), input/configuration identities and grammar/policy identity; untrusted data retained by the domain owner |
| PDKExecutionSourceBinding | Profile-scoped occurrence ID plus full-domain occurrence ID; one ordered row per projected occurrence |
| PDKExecutionEntry | Projected root ID, domain root ID and explicitly nullable external parent ID/full reference/incoming edge; all external fields jointly present or null |
| PDKExecutionConsumptionClaim / 1 | Existing scoped claim, execution-input identity, source bindings and entries; construction cannot mint checked ownership |
| PDKMatchedExecutionConsumption | Internal constructor; retained CP match, verified binding identity and observation storage; never Codable |

The observation's domain-computed configuration identity must equal the stage
requirement; input identity must equal the execution claim. Domain graph IDs are
unique and every nonroot parent precedes its child. External parent/edge fields
are validated against the complete observation table, not against themselves.
The host's prepared-owner/artifact join authenticates which observation was used;
this neutral matcher does not authenticate caller-created observation data.

Proposed module function:

```swift
public func matchPDKExecutionConsumption(
    _ claim: PDKExecutionConsumptionClaim,
    against projection: PDKStageProjection,
    observed: PDKExecutionSourceObservation,
    resources: any PDKAdmissionResourceAccounting
) throws(PDKProfileConsumptionError) -> PDKMatchedExecutionConsumption
```

`PDKExecutionSourceObservation` is bounded neutral graph data emitted from the
domain's retained preparation. It contains full references/context/edges, entries
and the domain-computed input/configuration identities, not expected profile rows.
The function validates EB-01..05 and invokes CP comparison. Its derived algorithm
is not a protocol requirement and cannot be overridden. The returned internally
constructed owner retains the CP match and bound observation storage. Neither
untrusted observation data nor a matched value independently authenticates the
domain implementation or proves numerical completion.

## Runtime Flows

Capture/admit -> domain preparation -> compute actual identities/observations ->
project explicit requirements using actual configuration identity -> build scoped
claim from actual observations -> EB/CP comparison -> execute the same preparation.
Completion records bind the same execution-input, configuration and binding
identities. A source recapture or a new preparation requires a new match.

## State, Ownership, and Lifecycle

The stage retains admission, prepared domain owner and matcher output until result
publication completes. New copied observations/bindings retain stage accounting
receipts through last-copy release. Original admitted backing remains with its
original owner/accountant; do not reopen a closed admission accountant or recharge
immutable shared captures. No borrowed pointer, I/O handle or mutable domain graph
escapes. Temporary traversal/framing buffers release on every exit.

## Failure, Concurrency, and Constraints

Add typed reasons for entry mismatch, unknown/repeated execution occurrence,
unrepresented contributor, context mismatch and input/configuration identity
mismatch. Preserve existing CP/resource causes and cancellation. Check work and
capacity before traversal/growth; bounded canonical hashing checks cancellation
before publication. No callback or I/O is performed under accountant locks.
Uniform Sendable/isolation contracts apply; Native proof does not qualify WASM or
Embedded. There is no successful fallback to standalone CP matching.

## Verification and Change Impact

Proposed `PDKProfileAdmissionTests/ExecutionBindingTests` owns direct-root and actual
external-entry success, physical edge/parent tampering, inherited parameter drift,
repeated/extra/missing contributors, section mismatch, stable relocation identity,
full-graph/configuration drift, quotas/cancellation and final-copy release.
Core/Timing own the truth of their observations; host owns invocation and evidence
authentication. Existing CP vectors/tests remain valid if their premise is unchanged.
Change impact: PDKCore new values, this component's matcher, domain preparation,
host request/result readers and its integration tests migrate in one adoption.
