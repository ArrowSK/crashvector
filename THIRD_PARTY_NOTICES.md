# Third-Party Notices

CrashVector source code is intended to be licensed under MPL-2.0.

## Godot Engine

CrashVector is built with Godot Engine. Godot Engine is distributed under the MIT License. Engine binaries and notices are not vendored in this repository.

## Jolt Physics

CrashVector's planned/default 3D world-physics backend is Jolt Physics through Godot's supported 3D physics integration. Jolt Physics is distributed under the MIT License. No standalone Jolt source or binary is vendored in this repository.

## FFmpeg

CrashVector M7 can invoke a user-installed FFmpeg executable to encode rendered JPEG frames as H.264 MP4 video. FFmpeg is **not bundled or redistributed by this repository**. The installed FFmpeg build is external software and may be distributed under LGPL or GPL terms depending on how it was built and which codecs/features are enabled. Anyone packaging FFmpeg together with CrashVector must review the exact FFmpeg build configuration and comply with the corresponding licence and notice requirements.

## Kenney Car Kit 3.1

CrashVector uses generic presentation meshes from **Kenney Car Kit 3.1**, created and distributed by Kenney (https://kenney.nl/assets/car-kit).

- Licence: Creative Commons Zero (CC0 1.0 Universal).
- Attribution: not required by the licence; CrashVector credits Kenney voluntarily.
- Purpose in CrashVector: presentation geometry only. CrashVector's own structural graph, vehicle dimensions, mass, collision geometry, deformation calculations and evidence boundaries remain authoritative.
- Repository source: `third_party/kenney_car_kit`, pinned as a Git submodule to commit `153591d606970058a4d0e44aeadf435c2d3f89ed` of the public Car Kit mirror used by this repository.
- Passenger-car mapping: Kenney `hatchback-sports`, `sedan`, `sedan-sports`, `suv` and `van`, plus `wheel-default`.

The upstream Car Kit license file also identifies the pack as CC0 and permits personal, educational and commercial use. A normal source checkout should initialize submodules before running the full Kenney visual path.

## Other assets

CrashVector continues to use procedural/runtime-generated geometry where no Kenney Car Kit asset matches the simulated object class or where a generated presentation element is required to remain physically coupled to CrashVector's structural model. No branded production-vehicle model is distributed.

Before any additional third-party asset is added, its source, author, licence, redistribution terms, and attribution requirements must be recorded here or in `assets/attribution/`.
