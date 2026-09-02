# Calibration and validation scope

CrashVector is an educational structural-collision simulator. M8 introduces a deliberately narrow correlation envelope instead of implying that every available scenario is validated.

## First external structural reference

The first correlation reference is the NHTSA NCAP full-frontal rigid-barrier condition documented in **DOT HS 812 237**, *Update to Future Midsize Lightweight Vehicle Findings in Response to Manufacturer Review and IIHS Small-Overlap Testing* (February 2016).

Source: https://www.nhtsa.gov/sites/nhtsa.gov/files/812237_lightweightvehiclereport.pdf

The report documents laboratory test **7078** for a midsize four-door passenger car and gives a laboratory test mass of **1,661 kg**. The NCAP condition is a full-frontal impact into a rigid barrier at a nominal **56 km/h (35 mph)**. Elsewhere in the report the physical test is stated as **56.5 km/h (35.1 mph)**. The report describes the test crash-pulse duration as approximately **120 ms**. It also publishes post-test driver-compartment x-direction measurements of **-3 mm at the brake pedal** and **8 mm at the foot rest**.

CrashVector does **not** expose the production vehicle used in that NHTSA research as a selectable model. The reference is used only to constrain the generic **D-segment midsize** development class.

## What is actually compared

The M8 regression runs a 1,661 kg generic D-segment CrashVector vehicle at 56.5 km/h into the rigid-wall target. The comparison gates:

- crash-pulse duration, measured from first contact until the vehicle's longitudinal speed falls below 10% of its initial value;
- longitudinal delta-v;
- CrashVector's maximum permanent safety-cell beam deformation proxy;
- numerical energy-balance error.

The pulse-duration and delta-v checks are physically comparable at a broad structural level. The safety-cell beam deformation value is **not** the same measurement as brake-pedal, foot-rest, toe-board, steering-column, or occupant-space intrusion. The published intrusion values are retained in the reference JSON as source observations but are not silently re-labelled as CrashVector output.

## Project correlation corridors

The reference file separates published observations from CrashVector-defined engineering corridors. The current corridors are:

- pulse duration: **80–160 ms**, centred broadly around the report's approximately 120 ms test pulse;
- longitudinal delta-v: **50–63 km/h** for the 56.5 km/h rigid-barrier condition;
- safety-cell structural proxy: **0–45 mm**;
- energy-balance relative error: **<= 0.35**.

These corridors are project regression thresholds, not limits published by NHTSA. A change to a corridor must be reviewed together with its documented basis; CI should not be made green by widening a corridor without explanation.

## Scenario labels

CrashVector assigns one of four validation-scope labels to the currently configured scenario:

**Reference-correlated** means the scenario is inside the narrow current NHTSA-based envelope: generic D-segment midsize car, rigid wall, 50–60 km/h, 1,500–1,800 kg, and approximately zero-degree frontal heading.

**Near reference** means the same class and impact type are close to the reference but outside the directly correlated mass or speed corridor.

**Class-scaled** means a B- or C-segment passenger car uses the same generic structural architecture and class scaling in a moderate-speed rigid-wall impact, but that class has no direct published correlation test in M8.

**Extrapolated** covers the rest, including 90 and 140 km/h high-speed cases, car-vs-car, car-vs-truck, non-rigid-wall targets, and other configurations outside the present reference envelope.

The label is a statement about evidence coverage, not a safety rating.

## What M8 does not validate

M8 does not validate occupant injury risk, airbags, seat belts, dummies, vehicle star ratings, exact production-model deformation, side impacts, oblique/broadside impacts, truck underride injury outcomes, or crash reconstruction. It also does not make the 90/140 km/h visual comparisons "validated" merely because the lower-speed structural reference passes.

The NHTSA report itself uses detailed finite-element models with approximately two million elements and compares laboratory acceleration and intrusion measurements. CrashVector's node/beam model is intentionally far simpler, so its correlation claims must remain correspondingly narrower.

## Adding future references

Future reference datasets should be placed in `calibration/references/` and must keep three kinds of data separate:

1. published test conditions and observations;
2. CrashVector metric mappings and engineering corridors;
3. the exact scenario scope to which a successful correlation may be applied.

A new reference should add a deterministic regression test before its scope can be shown as correlated in the UI.
