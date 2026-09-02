# Third-Party Notices

CrashVector source code is intended to be licensed under MPL-2.0.

## Godot Engine

CrashVector is built with Godot Engine. Godot Engine is distributed under the MIT License. Engine binaries and notices are not vendored in this repository.

## Jolt Physics

CrashVector's planned/default 3D world-physics backend is Jolt Physics through Godot's supported 3D physics integration. Jolt Physics is distributed under the MIT License. No standalone Jolt source or binary is vendored in this repository.

## FFmpeg

CrashVector M7 can invoke a user-installed FFmpeg executable to encode rendered JPEG frames as H.264 MP4 video. FFmpeg is **not bundled or redistributed by this repository**. The installed FFmpeg build is external software and may be distributed under LGPL or GPL terms depending on how it was built and which codecs/features are enabled. Anyone packaging FFmpeg together with CrashVector must review the exact FFmpeg build configuration and comply with the corresponding licence and notice requirements.

## Assets

CrashVector currently uses procedural primitive meshes and runtime-generated vehicle/environment visuals. No third-party production vehicle model, texture, audio, or environment asset is distributed.

Before any third-party asset is added, its source, author, licence, redistribution terms, and attribution requirements must be recorded here or in `assets/attribution/`.
