# M22 — Cyclist coupling and moving pedestrians

M22 extends CrashVector's vulnerable-road-user trajectory/contact scope while preserving the existing M12-M21 vehicle physics architecture.

This milestone does **not** add biomechanics, injury prediction, a pedestrian gait solver, a bicycle tyre-force model or regulatory correlation. The new targets remain generic educational trajectory/contact models.

## Scope added

M22 adds two capabilities:

1. a new **Cyclist (generic rider + bicycle)** target; and
2. configurable initial translation speed for the existing articulated pedestrian target.

The existing **Bicycle (riderless)** target remains separate and keeps its previous scope. M22 does not silently turn old riderless-bicycle scenarios into cyclist scenarios.

## Generic cyclist

The cyclist target uses one of the existing City / Road / E-bike bicycle archetypes plus a generic adult rider.

The physical topology is:

- one bicycle frame/root rigid body;
- two independently simulated bicycle wheel rigid bodies;
- eleven generic rider rigid bodies;
- two bicycle hub joints;
- ten bounded rider articulation joints; and
- five temporary rider-to-bicycle coupling joints at the seat, hands and feet.

The rider topology deliberately reuses the finalized M15 articulated-person part names and bounded joint approach. Before contact, the temporary coupling joints keep the rider associated with the bicycle while allowing limited posture motion. On the first production-compatible vehicle contact, those coupling joints are detached so the rider and bicycle can follow independent post-impact trajectories.

Self-collision between the rider and bicycle parts remains disabled after release. This is deliberate: M22 is a bounded trajectory/contact model and does not introduce an unvalidated high-energy rider/bicycle collision solver.

### Mass

The scenario's cyclist mass is the **combined rider + bicycle mass**.

The selected bicycle contributes its existing generic default mass. The remaining configured mass is assigned across the eleven rider bodies using the same generic segment fractions used by the articulated-person model. The UI and scenario validation preserve at least a 35 kg rider share for the selected bicycle.

The default rider assumption is 75 kg, so the default combined masses are:

- City bicycle: 91 kg;
- Road bicycle: 84 kg;
- E-bike: 99 kg.

These are generic scenario defaults, not population or injury-model inputs.

### Initial motion and impact coupling

Cyclist initial speed may be set from 0 to 80 km/h along the target heading. Arbitrary heading differences are allowed for generic broadside/oblique trajectory scenarios.

CrashVector continues to use the established vulnerable-road-user contact architecture: road-user rigid segments collide with the road, while passenger-car coupling is initiated through the production front-crush probe path rather than turning articulated rider or wheel parts into rigid ramps under the car.

The M22 one-shot cyclist transfer is closing-speed based and bounded. It distributes generic contact demand between the bicycle frame, rider pelvis and rider torso, then releases the temporary rider/bicycle couplings. This is a stability-oriented educational coupling, not a biomechanical force or injury calculation.

## Moving pedestrians

The existing articulated pedestrian may now begin with a configured translation speed from 0 to 20 km/h along its heading.

This means the entire articulated pedestrian starts with the same world velocity. M22 does **not** animate or physically model walking/running gait, foot placement, propulsion, balance control or ground-reaction cycles. The speed is simply the pedestrian's initial translational motion before impact.

The existing M15 bounded articulated topology, road collision, replay and high-speed vertical-transfer guard remain unchanged.

## Riderless bicycle remains separate

`Bicycle (riderless)` remains available for the original riderless educational scenarios and keeps its established rear-end / near-head-on heading restriction.

Broadside/oblique rider+bicycle scenarios should use the new `Cyclist` target instead. This separation keeps old saved scenarios and regression expectations semantically stable.

## Presentation and replay

`M22RoadUserPresentationSkin3D` composes the existing connected bicycle presentation with the existing articulated-person presentation. It is presentation-only and does not own physics bodies.

Replay continues to store the rigid transform and velocities of every articulated road-user part. Cyclist replay additionally stores whether the rider-to-bicycle coupling had already released, so pre-contact and post-contact states can be reproduced consistently.

## Desktop controls

The existing M16/M10 desktop layout is preserved rather than redesigned.

- `Cyclist (generic rider + bicycle)` appears in the normal Impact target selector.
- The Target tab exposes bicycle archetype, combined mass and initial speed for a cyclist.
- The existing Pedestrian target now exposes initial speed up to 20 km/h.
- The riderless Bicycle target remains unchanged.

## Regression intent

`tests/m22_cyclist_moving_pedestrian.gd` covers:

- pedestrian speed preflight and configured initial motion;
- continued rejection of the old riderless-bicycle broadside path;
- cyclist broadside/oblique preflight;
- cyclist physical body/joint topology;
- preservation of combined cyclist mass across actual rigid bodies;
- pre-impact rider coupling and contact-time release;
- replay preservation of articulated part state and coupling-release state;
- production routing through `crash_demo_m22.gd`;
- installation of the combined rider+bicycle presentation; and
- a representative generic cyclist production impact with finite motion and a bounded vertical-stability check.

The test is included in consolidated M0-M22 CI and in both publishable package validation levels (`smoke` and `full`).

## Evidence boundary

M22 does not provide:

- pedestrian or cyclist injury criteria;
- head/torso/limb injury probability;
- validated rider ejection prediction;
- gait or balance prediction;
- tyre/steering/braking rider control;
- manufacturer bicycle geometry;
- regulatory vulnerable-road-user correlation; or
- forensic reconstruction accuracy.

M19's public protocol references and contact diagnostics do not validate M22 cyclist or moving-pedestrian outcomes.

## Validation status

The M22 implementation has passed the full M0–M22 Godot suite, production visual/contact review and native package checks.

The current public packaged beta is `0.9.0-beta.3`, which retains M19–M22 alongside the M23 runtime presentation corrections. The modelling boundaries above remain unchanged.
