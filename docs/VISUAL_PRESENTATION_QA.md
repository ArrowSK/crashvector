# Visual presentation QA

CrashVector's production regressions already verify physics, collision/contact routing, replay and packaging. The visual presentation layer also needs explicit contracts so a technically valid build cannot silently regress into implausible relative sizing, detached rider geometry or presentation pieces that no longer follow their structural anchors.

`tests/visual_presentation_contracts.gd` is the cross-target presentation gate. It intentionally does not introduce a new rendering or physics architecture.

## Passenger cars

The gate checks the public A/B/C/D/J/M catalog dimensions for monotonic length and plausible road-car bounds, instantiates every production Kenney passenger skin and validates broad rendered dimensions. The gate strictly requires the axis-specific class-fit contract, rendered length/width matching the catalog, and increasing A < B < C < D < J < M rendered length.

The dedicated passenger-car PRs retain their more detailed nose/contact and material regressions; this file is the shared top-level guard.

## Heavy articulated truck

The gate keeps the trailer within plausible road-trailer proportions and verifies that wheel presentation remains tied to the structural axle anchors. The gate requires separate tractor/trailer presentation roots, an active fitted CC0 tractor and a visible fifth-wheel gap.

## Motorcycle and rider

The motorcycle gate checks two-wheel topology, visual wheelbase and fork/swingarm presentation. It requires the tubular presentation contract and verifies each long cylinder is aligned to the structural span that owns it.

The rider gate preserves the existing two-rigid-body physics contract, forbids the legacy rectangular arm/leg blocks, requires the articulated presentation root/segment contract, and checks both hands remain attached to the actual motorcycle grip meshes.

## Cyclist

The cyclist gate preserves the existing 11-body rider and five pre-impact bicycle couplings. It requires the visible pelvis to follow the real `CyclistPelvis` body and both visible hands to remain near the existing bicycle control couplings before release.

## Final-gate behaviour

This is the final presentation-fix PR, so the shared gate has no compatibility escape hatches. Passenger class fitting, articulated-truck roots, tubular motorcycle geometry, articulated rider presentation, and body-bound cyclist anchors are mandatory contracts. Removing one of those APIs, metadata fields, or presentation links must fail CI rather than silently disabling the corresponding assertion.

## Evidence boundary

These checks are presentation-quality and consistency regressions. They do not establish crashworthiness, biomechanics, injury prediction, manufacturer geometry, regulatory compliance or forensic accuracy.
