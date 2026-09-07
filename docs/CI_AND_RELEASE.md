# CI, visual review and desktop release flow

CrashVector separates code validation, rendered presentation review and desktop packaging so ordinary development does not spend macOS/Windows runner minutes on every commit.

## Normal code changes

`.github/workflows/ci.yml` is the normal automated gate for `main` and pull requests. It uses one Ubuntu/Godot job, imports the project once, then runs the unique M0-M18 regression scripts sequentially. The old milestone-specific workflows were removed because they repeatedly imported the same project and re-ran overlapping tests on separate runners.

Documentation-only changes under `docs/` or Markdown files do not start CI.

Normal CI does **not** build DMG or Windows installers.

## Rendered presentation review

`.github/workflows/visual-review.yml` is manual (`workflow_dispatch`). It renders:

- pristine A/B/C/D/J/M passenger cars at 1280x720, 1920x1080 and 2560x1440 in 3/4, side and front views;
- representative frontal, rear and broadside production-crash preview/aftermath frames.

The PNG files are uploaded as a workflow artifact for human review. This is intentionally not a per-push workload because visual acceptance is expensive and still requires a person to judge composition, proportions and obvious presentation defects.

## Desktop packages and releases

`.github/workflows/package-release.yml` is manual (`workflow_dispatch`). It always builds the macOS Universal 2 DMG and Windows x64 installer and verifies package structure/checksums. Packaging no longer runs on normal pushes or pull requests. The established optional macOS Developer ID/notarization and Windows Authenticode paths are preserved when their credentials are configured.

The workflow asks for a validation level:

- `none` — package-only diagnostic build; no regression suite is run;
- `smoke` — focused layout, Kenney presentation, runtime-stability and M18 side-impact checks;
- `full` — the complete consolidated M0-M18 regression set.

It also asks whether to publish a versioned GitHub release. Publishing requires `smoke` or `full` validation to succeed, successful macOS and Windows packages, a new semantic version in `project.godot`, and matching release notes under `docs/releases/<version>.md`. `validation=none` deliberately cannot publish; it produces artifacts only. Existing release tags are never overwritten.

A package produced with `validation=none` is an **unvalidated diagnostic artifact**. It may be useful for local visual inspection when regression capacity is constrained, but it must not be described as having passed CrashVector's regression suite.

## GitHub Actions quota

Separating these workflows reduces runner consumption but cannot bypass GitHub-hosted Actions account limits. If GitHub refuses to allocate hosted runners because the account quota is exhausted, automated tests, visual rendering and package builds are all unavailable until runner capacity becomes available again. Source changes can still be committed with `[skip ci]`, but their runtime behaviour remains unverified until a runner or local Godot environment executes the relevant checks.
