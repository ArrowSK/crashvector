# Desktop distribution, updates and releases

CrashVector's desktop distribution layer was introduced in M9 and remains separate from simulation physics, replay, analysis, comparison, calibration and video export. Later milestones reuse the same packaging and updater architecture rather than introducing a second release path.

The canonical application version is `application/config/version` in `project.godot`. Packaging scripts, native package metadata, the updater and the release workflow all derive their version from that one value. Native operating-system version fields that cannot contain Semantic Version prerelease text are generated deterministically from it; they are not independent release versions.

The current verified public desktop release is `0.9.0-beta.5`. It packages the M23 runtime stability and presentation corrections after full regression validation, runtime visual/contact review and native package checks. Public download and update discovery therefore resolve to the current v0.9 beta.

## Install on macOS

The public macOS asset is named `CrashVector-<version>-macOS-universal.dmg`.

1. Download the DMG from the official `ArrowSK/crashvector` GitHub Release.
2. Open the DMG in Finder.
3. Drag `CrashVector.app` to the Applications shortcut shown in the disk image.
4. Launch CrashVector from Applications.

The package is Universal 2. The packaging workflow verifies that the application executable contains both `arm64` and `x86_64` slices.

To remove CrashVector, quit it and move `CrashVector.app` from Applications to Trash. No Terminal command is part of the normal installation or removal procedure.

### macOS signing

The packaging workflow always signs the application. When Apple Developer ID credentials are configured it uses Developer ID signing and can notarize the DMG. Without those paid credentials, the beta is ad-hoc signed and unnotarized. Gatekeeper can therefore warn that the developer cannot be verified.

This is a distribution-signing limitation, not a checksum bypass. Use only packages attached to the official `ArrowSK/crashvector` release and verify the published SHA-256 when independent verification is desired.

Developer ID signing and notarization can be enabled through repository secrets without changing the packaging architecture.

## Install on Windows

The public Windows asset is named `CrashVector-<version>-Windows-x64-Setup.exe`.

1. Download the Setup executable from the official `ArrowSK/crashvector` GitHub Release.
2. Run Setup and follow the graphical installer.
3. CrashVector installs under the normal 64-bit Program Files location.
4. The installer creates a Start-menu entry and registers CrashVector with Windows Installed apps.

To remove CrashVector, use Windows Settings → Apps → Installed apps → CrashVector → Uninstall. The installer supplies a normal Inno Setup uninstaller.

When Authenticode credentials are not configured, the executable and installer may be unsigned and Windows SmartScreen may show an unknown-publisher warning. The workflow already supports Authenticode signing when a certificate is configured.

## Built-in updater

The normal application UI contains **Updates**. The flow is:

`Updates → Check for updates → review version/release notes → Download → SHA-256 verify → Install`

CrashVector discovers releases only from the official `ArrowSK/crashvector` GitHub Releases API. It never silently installs an update.

The updater:

- shows the installed version and available version;
- supports Semantic Version prereleases such as `0.8.0-beta.3`;
- allows a beta installation to advance to a later beta or to the eventual stable version;
- keeps stable installations off prerelease builds unless the application is itself on a prerelease channel;
- has an explicit **Check for updates** control;
- can make at most one automatic background check per day;
- stores the automatic-check preference locally and lets the user disable it;
- displays the GitHub Release notes before download;
- chooses the DMG on macOS and the Setup EXE on Windows from the release manifest;
- verifies the downloaded package against the manifest SHA-256 before enabling installation;
- deletes/rejects a package when SHA-256 verification fails;
- leaves the existing installation untouched if discovery, download or verification fails;
- never overwrites the currently running executable.

After successful verification, macOS opens the downloaded DMG and returns installation to Finder. Windows launches the verified Setup executable. CrashVector exits only after the operating system successfully accepts that handoff.

## Update manifest

Each published release contains `update-manifest.json`. Schema version 1 contains:

- `schema_version`;
- CrashVector `version`;
- exact GitHub `release_tag`;
- package `filename`;
- `platform`;
- `architecture`;
- `sha256`;
- file `size`.

The updater requires the manifest version and tag to agree with the GitHub Release and resolves package downloads by exact asset filename. The release workflow generates the manifest only after both platform packages have been built and their checksum sidecars have been verified.

## Packaging architecture

Generated package metadata and native icon containers are not maintained as competing hand-edited sources.

`tools/prepare_packaging.py` reads `project.godot` and generates the Godot export presets plus Inno Setup version definitions. `tools/render_icon.gd` renders the repository's canonical SVG branding master, and `tools/generate_icon_containers.py` deterministically generates and validates the native multi-resolution ICO/ICNS containers used by packaging.

Current validation and packaging are split into three workflows/jobs with different purposes:

1. **Normal consolidated CI** — `.github/workflows/ci.yml` imports/parses the project once, performs the architecture audit and runs the unique M0-M22 regression stack on Ubuntu/Godot. Documentation-only changes do not trigger it.
2. **Presentation visual review** — `.github/workflows/visual-review.yml` is manual. It renders the passenger-car acceptance views and representative crash frames and also produces the M19 contact-fidelity observation matrix. Generated images/data are evidence for human review; successful artifact generation by itself is not visual acceptance or external validation.
3. **Package and release** — `.github/workflows/package-release.yml` is manual. It builds and validates the macOS Universal 2 DMG and Windows x64 installer. Optional signing/notarization paths are used when credentials exist.

The package workflow accepts three validation levels:

- `none` — package-only diagnostic build; no regression suite is run;
- `smoke` — focused layout/presentation/runtime plus dedicated M18-M22 production gates;
- `full` — consolidated historical/package regression coverage through M22.

A `validation=none` artifact is an unvalidated diagnostic package and cannot be published as a GitHub Release. A publishable run requires `smoke` or `full` validation plus both native package jobs to succeed. `full` is the preferred release-candidate validation when runner capacity is available.

The Windows package job performs a real silent installation into Program Files, checks the installed executable and uninstaller, then performs a real uninstall before accepting the package. Both platform jobs generate and verify SHA-256 sidecars.

## No runtime monkey patching

Production code must use normal inheritance, composition, services and signals. CI scans `src/` and `app/` for prohibited runtime implementation replacement patterns such as `set_script(...)`, `take_over_path(...)`, direct script reassignment or equivalent mechanisms.

A match fails the architecture audit before the regression suite is accepted.

## Current release-readiness sequence

The current public package is `0.9.0-beta.5`. Future releases must not be created merely because a candidate version exists.

Once runner capacity is available, use this order:

1. Run consolidated CI or the package workflow with `validation=full` and require the project import/parse plus M0-M22 regressions to succeed.
2. Run the manual presentation visual review and inspect the pristine A/B/C/D/J/M vehicle frames, representative crash frames and M19 contact matrix.
3. Build and validate both native packages. Retain the Universal 2 architecture check, macOS signing verification, Windows install/uninstall verification and both checksum checks.
4. Create matching versioned release notes for the candidate only after its source, documentation and package behaviour are ready to publish.
5. Run `Package and release` with `publish_release=true` and `validation=smoke` or `full`; `full` is preferred.

The publish job refuses to run with `validation=none`, requires successful validation/macOS/Windows jobs, re-verifies both package SHA-256 sidecars, builds `update-manifest.json`, requires matching release notes, and refuses to overwrite an existing `v<version>` release.

Published release assets are therefore immutable. If an already-published binary needs correction, increment the application version and publish a new release.

A normal published release contains:

```text
CrashVector-<version>-macOS-universal.dmg
CrashVector-<version>-macOS-universal.dmg.sha256
CrashVector-<version>-Windows-x64-Setup.exe
CrashVector-<version>-Windows-x64-Setup.exe.sha256
update-manifest.json
```

## GitHub Actions quota

The consolidated/manual workflow split reduces runner consumption but cannot bypass GitHub-hosted Actions account limits. If GitHub refuses to allocate hosted runners because the quota is exhausted, automated tests, rendered review and native package builds remain unavailable until runner capacity returns.

Source changes may be committed with `[skip ci]`, but those commits must remain explicitly runtime-unvalidated until Godot executes the relevant checks. The current M19-M22 source completed those gates before its public v0.9 release.

## Building from source

Source development remains supported. Install Godot 4.4.1 or newer, clone the repository with submodules, open `project.godot`, and run the main scene. Git is needed only for source development, not for users installing the packaged desktop application.

For an existing checkout, run `git submodule update --init --recursive` before launching if the pinned Kenney Car Kit passenger-car presentation assets are not already present.

The packaging helpers are release-engineering tools; end users do not need Python, Git, Godot, Terminal or PowerShell to install or update CrashVector.
