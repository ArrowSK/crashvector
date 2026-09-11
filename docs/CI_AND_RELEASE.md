# CI, visual review and desktop release flow

CrashVector separates code validation, rendered presentation review and desktop packaging so ordinary development does not spend macOS/Windows runner minutes on every commit.

## Normal code changes

`.github/workflows/ci.yml` is the normal automated gate for `main` and pull requests. It uses one Ubuntu/Godot job, imports the project once, then runs the unique M0-M22 regression scripts sequentially. The old milestone-specific workflows were removed because they repeatedly imported the same project and re-ran overlapping tests on separate runners.

Documentation-only changes under `docs/` or Markdown files do not start CI.

Normal CI does **not** build DMG or Windows installers.

## Rendered presentation and contact-fidelity review

`.github/workflows/visual-review.yml` is manual (`workflow_dispatch`). It renders:

- pristine A/B/C/D/J/M passenger cars at 1280x720, 1920x1080 and 2560x1440 in 3/4, side and front views;
- representative frontal, rear and broadside production-crash preview/aftermath frames.

The same manual workflow also runs the M19 full-frontal/offset/oblique/broadside production observation matrix and uploads `build/m19_contact_fidelity/contact_matrix.json` with the PNG artifact. That JSON is diagnostic only: it reports the current Godot contact manifold and associated production metrics and does not define an external validation corridor.

This review is intentionally not a per-push workload because rendered acceptance and four additional production simulations are expensive and still require a person to judge composition and contact behaviour.

## Desktop packages and releases

`.github/workflows/package-release.yml` is manual (`workflow_dispatch`). It always builds the macOS Universal 2 DMG and Windows x64 installer and verifies package structure/checksums. Packaging no longer runs on normal pushes or pull requests. The established optional macOS Developer ID/notarization and Windows Authenticode paths are preserved when their credentials are configured.

The workflow asks for a validation level:

- `none` — package-only diagnostic build; no regression suite is run;
- `smoke` — focused layout, Kenney presentation, runtime-stability, M18 passenger-car side impact, dedicated M19 contact diagnostics, M20 heavy/lorry/motorcycle impact, M21 fifth-wheel articulation and M22 cyclist/moving-pedestrian production gates;
- `full` — the consolidated historical/package regression set through M22, including the dedicated M19-M22 production checks.

The expensive four-case M19 observation matrix remains in the manual visual-review workflow because it is intended for evidence inspection rather than pass/fail external correlation. M20-M22 add production capabilities, so their dedicated regressions are part of both `smoke` and `full`: a publishable release cannot gain heavy/other-vehicle deformation, articulated fifth-wheel dynamics or cyclist/moving-pedestrian scope while omitting the corresponding production gate.

It also asks whether to publish a versioned GitHub release. Publishing requires `smoke` or `full` validation to succeed, successful macOS and Windows packages, a new semantic version in `project.godot`, and matching release notes under `docs/releases/<version>.md`. `validation=none` deliberately cannot publish; it produces artifacts only. Existing release tags are never overwritten.

A package produced with `validation=none` is an **unvalidated diagnostic artifact**. It may be useful for local visual inspection when regression capacity is constrained, but it must not be described as having passed CrashVector's regression suite.

## Current M23 release state

The current `main` source is implemented through M23 and versioned as the published **`0.9.0-beta.5` desktop beta**. The full regression gate, runtime presentation review and macOS/Windows package checks succeeded before release. Therefore:

- source routing, tests and package gates are wired through M23;
- public installers and the updater manifest resolve to `0.9.0-beta.5`;
- package checksums use portable LF-terminated sidecars;
- future releases must still complete the same gates before publication.

Once runner capacity is available, use this order:

1. Run normal consolidated CI or the package workflow with `validation=full` to import/parse the project and execute M0-M22.
2. If a quicker first diagnostic is needed, package `smoke` is the minimum publishable regression subset because it includes M19-M22.
3. Run `Presentation visual review` and inspect the pristine passenger-car frames, representative deformation frames and M19 contact matrix rather than treating artifact generation itself as visual acceptance.
4. Build macOS Universal 2 and Windows x64 packages and retain the existing signature/install/uninstall/checksum checks.
5. If the source/runtime/visual/package gates are acceptable, publish a new version with matching release notes using `publish_release=true`.
6. The workflow will refuse publication if validation is `none`, if either native package fails, or if the release tag already exists.

If validation uncovers a code defect after packages or release metadata have escaped into a published release, do not replace that release in place: fix the defect and bump to a new prerelease version.

The preferred release-candidate path is `full` validation plus manual visual review. `smoke` exists as the minimum publishable gate, not as a reason to skip the full suite when capacity is available.

## GitHub Actions quota

Separating these workflows reduces runner consumption but cannot bypass GitHub-hosted Actions account limits. If GitHub refuses to allocate hosted runners because the account quota is exhausted, automated tests, visual rendering and package builds are all unavailable until runner capacity becomes available again. Source changes can still be committed with `[skip ci]`, but their runtime behaviour remains unverified until a runner or local Godot environment executes the relevant checks.
