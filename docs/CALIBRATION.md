# Calibration and validation scope

CrashVector is an educational structural-collision simulator. M8 introduced a deliberately narrow correlation envelope instead of implying that every available scenario is validated. Later M12–M16 production physics and presentation work do not broaden that evidence envelope.

## First external structural reference

The first reference is the NHTSA NCAP full-frontal rigid-barrier condition documented in **DOT HS 812 237**, *Update to Future Midsize Lightweight Vehicle Findings in Response to Manufacturer Review and IIHS Small-Overlap Testing* (February 2016).

Source: https://www.nhtsa.gov/sites/nhtsa.gov/files/812237_lightweightvehiclereport.pdf

The report documents laboratory test **7078** for a midsize four-door passenger car, with a laboratory test mass of **1,661 kg**. The physical test is stated as **56.5 km/h (35.1 mph)**. The report describes the test crash-pulse duration as approximately **120 ms** and publishes post-test driver-compartment x-direction measurements of **-3 mm at the brake pedal** and **8 mm at the foot rest**.

CrashVector does not expose the production vehicle used in the NHTSA research as a selectable model. The external reference constrains only the generic D-segment development scenario.

## Source evidence versus project regression

M8 deliberately keeps two categories separate.

### Source-correlation evidence

The stored source-correlation corridor currently covers **crash-pulse duration only**: **80–160 ms**, centred broadly around the published approximately 120 ms pulse.

This is the only M8 corridor directly anchored to the published observation used by the current automated correlation check.

### CrashVector project regression guardrails

The following thresholds are numerical development guardrails, not values published by NHTSA:

- longitudinal delta-v: **50–75 km/h**;
- safety-cell structural beam-deformation proxy: **0–45 mm**;
- energy-balance relative error: **<= 0.35**.

The delta-v guardrail explicitly allows post-impact rebound in CrashVector's simplified historical wall/contact model. The NHTSA source used by M8 does not provide the final rebound velocity needed to construct CrashVector's delta-v metric, so the project must not describe this range as an NHTSA correlation corridor.

Likewise, the safety-cell beam value is not brake-pedal, foot-rest, toe-board, steering-column or occupant-space intrusion. The published intrusion observations remain in the reference JSON as source information but are not re-labelled as CrashVector output.

CI checks both categories, but the UI and data model preserve which category each check belongs to.

## Scenario labels

CrashVector assigns one of four evidence-scope labels to a configured scenario.

**Reference-correlated** means the scenario lies inside the narrow current NHTSA-based envelope: generic D-segment midsize car, rigid wall, 50–60 km/h, 1,500–1,800 kg and approximately zero-degree frontal heading.

**Near reference** means the same class and impact type are close to that condition but outside the directly correlated mass/speed envelope.

**Class-scaled** means another generic passenger-car class uses the shared structural architecture and class scaling near the moderate-speed wall condition without a direct published reference for that class.

**Extrapolated** covers the rest. This includes high-speed comparisons such as 130 vs 140 km/h, vehicle-to-vehicle impacts, heavy-vehicle cases, riderless-motorcycle cases, all pedestrian/bicycle cases, yielding narrow targets and other conditions outside the current reference envelope.

The label is a statement about evidence coverage, not a safety rating.

## Expanded generic classes and targets

A/B/C/D/J/M passenger-car presets remain generic representative classes. The current production passenger-car structure uses the M11 44-node local graph on the M12+ rigid chassis; the historical M8 correlation runner remains a separate reduced-order reference path. Neither the later 44-node production graph nor the M16 class-specific presentation profiles inherit direct experimental validation merely because they share the same generic class labels.

The heavy articulated truck, rigid lorry / box truck and riderless motorcycle are separate generic structural approximations. The motorcycle model contains no rider and must not be used to infer rider trajectory, helmet performance or injury.

Pedestrian and riderless-bicycle targets are also extrapolated. M15 articulation is a numerical contact/trajectory model, not a validated human or cyclist biomechanics model.

The full-frontal rigid wall is a normal selectable simulation target and is also the geometry used for the current M8 reference condition.

## High-speed and comparison scope

Historical Visual Compare may run arbitrary user-entered speeds in its legacy regression path, for example **130 and 140 km/h**. Such a comparison is useful for showing the nonlinear `v²` kinetic-energy relationship, but it remains extrapolated until appropriate high-speed reference evidence is added.

The desktop production Compare workflows are currently disabled until their historical synchronous runner is ported to the rigid-body world architecture. This implementation limitation does not change the evidence classification.

A successful 56.5 km/h rigid-wall reference check does not validate 90, 130, 140, 200 km/h or any other high-speed result.

## What M8 does not validate

M8 does not validate occupant/rider injury risk, airbags, seat belts, dummies, helmets, star ratings, exact production-model deformation, broadside impacts, complex oblique impacts, truck-underride injury outcomes, pedestrian/cyclist biomechanics, articulated-target joint behaviour or forensic crash reconstruction.

The NHTSA research uses detailed finite-element models and laboratory measurements. CrashVector's reduced-order node/beam and rigid-body representations are intentionally far simpler, so their claims must remain correspondingly narrower.

In particular, M8 does **not** validate:

- M12 rigid-body world motion or suspension/contact coupling;
- M13 staged whole-body collapse;
- M14 pole/tree yielding or vulnerable-target rigid-body trajectory;
- M15 articulated pedestrian/bicycle dynamics;
- M16 class-specific generated vehicle presentation.

## Adding future references

Future reference datasets belong in `calibration/references/` and must keep these categories distinct:

1. published test conditions and observations;
2. source-supported metric mappings/correlation corridors;
3. CrashVector-only regression guardrails;
4. the exact scenario scope to which successful correlation may be applied.

A new reference should add a deterministic regression test before its scope can be shown as correlated in the UI.
