# SPICE Profile Inspection Adapter

## Purpose and Scope

Status: implementation in progress; optional native host SwiftPM product/target. Parent:
[PDKKit](../../DESIGN.md). No children; production source is an explicit platform
adapter at the module boundary. Translate the CoreSpice-owned grammar into the
profile admission contract without implementing another include parser.

## Responsibilities and Boundaries

The proposed `PDKSpiceProfileInspection` target depends on PDKCore,
PDKProfileAdmission, PDKSourceCapture and CoreSpiceIO. CoreSpice does not depend
on PDKKit. PDKCore/ProfileAdmission do not import this optional adapter.
The standalone PDK CLI and Xcircuite inject the same native adapter. This adds an
exact CoreSpice package dependency only during implementation and adoption;
CoreSpice's current dependency path is Foundation/SignoffToolSupport, so this
direction introduces no PDK package cycle. Adopt exact revisions without local
path references or hidden overrides.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [PDKKit](../../DESIGN.md) | parent | Standalone host composition | Optional adapter | No UI or flow runtime dependency |
| [Admission](../PDKProfileAdmission/DESIGN.md) | depends on | Source inspecting and dependency resolving | Exact acquisition authority | No arbitrary filesystem resolver |
| [CoreSpiceIO](../../../CoreSpice/Sources/CoreSpiceIO/DESIGN.md) | depends on | Bounded caller-owned source intake | Loaded deck and capture inventory | Existing loadFile alone does not enforce an expected graph |
| [CoreSpiceParserSPICE](../../../CoreSpice/Sources/CoreSpiceParserSPICE/DESIGN.md) | depends on | Grammar and planned dependency events | Includes/sections/conditionals | Unknown required grammar remains blocked |
| [Standard inspection](../PDKStandardViews/StandardInspection/DESIGN.md) | coordinates with | Structural inspection versus profile admission | Handwritten SPICE intake migration | Names/counts do not prove a closed graph |

## Architecture

```text
captured PDK source + explicit section/context
    -> CoreSpiceIO caller-owned source intake
         -> same SPICE grammar + contextual resolver adapter
              -> PDKProfileDependencyResolving -> checked child capture
    -> parsed facts + ordered dependency events + capture inventory
    -> PDKProfileSourceFacts checked by admission
```

## Contracts and Invariants

The adapter conforms directly to PDKProfileSourceInspecting. It translates exact
captures through bounded checked Span admission to owned source documents, retaining
an occurrence-to-PDK-input table distinct from the immutable content/source keys. A diagnostic
filename is not materialization authority. A custom SPICEContextualFileResolver delegates
include/library operations exclusively to the admission resolver. Do not use
LocalFileResolver or the current filesystem search inside exact profile admission.

Reuse CoreSpice's parser, library-section projection, lexical model precedence
and conditional evaluation. Join grammar-owned dependency events to full expected
references/source keys. Capture ordinals and host paths are not canonical graph
identity. Every active include and external lib is represented; local lib sections
are selection facts. Unknown conditional selection blocks. Repeated nonrecursive
includes reuse bytes while preserving separate lexical occurrences.

Report actual model names/types/parameters, subcircuit names/ordered ports and
section facts from parser-owned IR, retaining occurrence-linked origins. A model
declaration does not declare terminals; do not synthesize them from device type. Do not copy expression evaluation or model physics into PDKKit.
Existing CoreSpice failures on adopted foundry grammar remain blocked; static
source inventory does not prove parser or numerical success.

## Runtime Flows

Translate captured root -> selected context -> parse with exact resolver and
shared accounting -> check parser/resolver failure and required coverage -> retain
source/dependency evidence -> emit facts. Recorded resolution failure cannot be
swallowed into successful empty IR.

## State, Ownership, and Lifecycle

One call owns parser state and the source-key table. Admission retains bytes.
Text/section projections and parser storage are charged to the same resource
owner. Scoped copies at the String-based parser boundary are reserved and
measured; this design makes no zero-copy claim. Async closure is admission-owned.

## Failure, Concurrency, and Constraints

Preserve typed cause and source location. Parser-owned work/cancellation checks
occur between bounded chunks and expansions. The adapter cannot reset duration
or byte/work counters. Required unavailable parsing blocks instead of falling
back to the handwritten structural inspector.

## Verification and Change Impact

Planned owner: `PDKSpiceProfileInspectionTests`, using the actual parser and
temporary files for nested include, external/local lib, selected section,
inactive/unknown conditionals, repeated inclusion, cycle, changed/missing/
undeclared child, physical source location and cumulative budget/cancellation.
Include supported and unsupported literal sources. CoreSpice owns its source
intake/events; standalone CLI and consumer composition follow after both pass.


### Bounded lower-contract composition

The exact lower requirements are owned by
[Parser](../../../CoreSpice/Sources/CoreSpiceParser/DESIGN.md#bounded-contextual-source-contract),
[ParserSPICE](../../../CoreSpice/Sources/CoreSpiceParserSPICE/DESIGN.md#bounded-profile-grammar)
and [IO](../../../CoreSpice/Sources/CoreSpiceIO/DESIGN.md#bounded-profile-source-intake).
Existing post-await event/count-only APIs do not meet this assumption.

Proposed concrete provider: `LocalPDKSpiceProfileInspector`, conforming directly to
PDKProfileSourceInspecting. Constructor fixes parser/policy identity, explicit
parser configuration with include resolution enabled and source/hash chunk policy.
Disabled include resolution is rejected rather than publishing a leaf source. It offers no arbitrary root
parameter/environment argument: the first native adapter uses empty root initial
parameters. Core derives that actual entry fingerprint and compares it to the
input context's required initialPreprocessingIdentity before parsing. Policy and
initial environment are separate checked authorities. Definition schema is owned
by [Profile](../PDKCore/Profile/DESIGN.md), not this adapter.

The resolver receives Core-created immutable contextual requests before await.
It joins the parent occurrence to the exact owned PDK input, maps the original
physical offset/ordinal/directive/route/requested child section and actual child
entry identity to PDKProfileDependencyRequest, then delegates only to the admission
resolver. Register the returned input and fresh child occurrence before returning
a checked owned document. The same Core environment snapshot enters child parsing.
A full-file include has nil child section even when parent has a selected section.
Repeated content reuses PDK capture ownership while preserving distinct occurrences,
origins and ordered events. No expected graph is invented before grammar traversal.

The native bridge forwards work/check calls to shared parserWork/deadline/cancel,
actual lower hashing to hashedBytes, and lower storage reservations to liveOwnedBytes
or temporaryBytes. The trusted bridge constructs lower reservation receipts from
its existing admitted token and release callback; this grants no source/result
authority. It never forwards synthetic sourceBytes as a filesystem read:
PDKSourceCapture already owns actual reads/pages/open handles. It maps resource
failures without losing their typed cause. Copies at Span-to-text, projection,
lexer/AST/transforms and output boundaries reserve their concrete managed logical
extent before work. No token-to-byte multiplier, RSS claim or new allocator is used.

One call owns the occurrence table and lower results. Async acquisition is already
supported; no blocking bridge, detached task or independently scheduled resolver is
required. Any registry/shared state uses actor or Mutex with callbacks outside locks.
Lower parsed owners remain alive while all PDKProfileSourceFacts arrays/strings are
copied by their existing checked accounting constructor. Release lower temporary
and result storage after that copy; returned facts retain their own reservations
and actual PDK inputs. Refused parsing publishes no facts, and awaited acquisition
cleanup completes before the failure leaves the call.

### First native capability boundary

Use the same grammar and existing conditional evaluator. Preserve parameter-only
child inheritance and whole-parent preprocessing before I/O; do not inherit parent
functions/header scope or re-evaluate parent branches after child merge. Source
preprocessing evidence reports actual active/inactive/unresolved decisions.
Unresolved active conditions or lost required meaning fail explicitly.

Complete source PVT is unavailable in the current parser and cannot be derived
from a section, expected corner or manifest. Required source PVT fails typed.
Only Core-owned, explicitly observed constant TEMP/TNOM can initially be emitted;
expression-dependent temperature remains typed unsupported until a bounded
Core-owned projection is implemented. No SPICEAnalysisOptions.resolve fallback
runs under this bounded path, and its absent-value defaults are not source facts.
Model TNOM, circuit nominal temperature and operating TEMP remain different facts.
Physical range/required-coverage checks belong to admission/domain owners.

A fixed backend may explicitly reject Unicode normalization or another operation
that cannot provide cooperative bounded processing. Refusal is a named capability,
not ASCII re-interpretation or fallback to unaccounted parsing. Valid supported
syntax keeps ordinary CoreSpice meaning. Syntax acceptance does not establish
numerical/foundry qualification.

Proof adds actual parent/child environment identity (empty root and inherited
parameters), selected-parent/full-child nil section, same-content repeated origins,
capacity refusal before copy/COW, TEMP versus TNOM, required source-PVT/expression
refusal and final-copy facts lifetime to the existing planned graph fixtures.
Lower contracts must pass first. Build affected products on one frozen native
snapshot, separate build/runtime timeouts, then verify only upper composition;
do not repeat numerical/CLI/GPU qualification as source-intake evidence.

### Native adapter implementation boundary

`LocalPDKSpiceProfileInspector` uses the public CoreSpiceIO profile grammar.
`PDKSpiceResourceBridge` forwards actual work and hashed bytes into the same
PDK accountant, and retains each PDK reservation in a lower receipt callback.
The sourceBytes notification only checks cancellation: capture already charged
actual reads; it is not a second filesystem read.

`PDKSpiceOccurrenceResolver` owns an accounted occurrence/input/document table in
an actor. Each occurrence has a unique admitted diagnostic filename; this is
only a correlation token for Core-owned physical line/column evidence, never
source authority. Child input registration happens before returning the child
document. Exact source keys and full references remain acquisition authority.
Resolver failures remain recorded by the invocation resolver and are rethrown by
admission before the inspector failure is wrapped.

Parser and document owners survive through the checked upper facts copy. Every
intermediate array uses admitted concrete temporary capacity. Raw model names,
ports, sections and diagnostic text retain their lower owner until their checked
copy. Unavailable source PVT and expression-dependent temperatures fail explicitly.
No analysis defaults or model terminal synthesis enter source facts.
