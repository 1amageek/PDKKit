# SPICE Profile Inspection Adapter

## Purpose and Scope

Status: proposed optional host SwiftPM product/target, not implemented. Parent:
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
| [CoreSpiceIO](../../../CoreSpice/Sources/CoreSpiceIO/DESIGN.md) | depends on | Planned caller-owned exact source intake | Loaded deck and capture inventory | Existing loadFile alone does not enforce an expected graph |
| [CoreSpiceParserSPICE](../../../CoreSpice/Sources/CoreSpiceParserSPICE/DESIGN.md) | depends on | Grammar and planned dependency events | Includes/sections/conditionals | Unknown required grammar remains blocked |
| [Standard inspection](../PDKStandardViews/StandardInspection/DESIGN.md) | coordinates with | Structural inspection versus profile admission | Handwritten SPICE intake migration | Names/counts do not prove a closed graph |

## Architecture

```text
captured PDK source + explicit section/context
    -> CoreSpiceIO caller-owned source intake
         -> SPICEParser + exact FileResolver adapter
              -> PDKProfileDependencyResolving -> checked child capture
    -> parsed facts + ordered dependency events + capture inventory
    -> PDKProfileSourceFacts checked by admission
```

## Contracts and Invariants

The adapter conforms directly to PDKProfileSourceInspecting. It translates exact
captures to SPICESourceDocument with a source-key/capture-ID table. A diagnostic
filename is not materialization authority. A custom FileResolver delegates
include/library operations exclusively to the admission resolver. Do not use
LocalFileResolver or the current filesystem search inside exact profile admission.

Reuse CoreSpice's parser, library-section projection, lexical model precedence
and conditional evaluation. Join grammar-owned dependency events to full expected
references/source keys. Capture ordinals and host paths are not canonical graph
identity. Every active include and external lib is represented; local lib sections
are selection facts. Unknown conditional selection blocks. Repeated nonrecursive
includes reuse bytes while preserving separate lexical occurrences.

Report model/subcircuit, terminal and section facts from parser-owned IR, retaining
actual origins. Do not copy expression evaluation or model physics into PDKKit.
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
