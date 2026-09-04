# Desktop distribution, updates and releases

CrashVector M9 adds normal end-user desktop distribution without changing the M0–M8 simulation model. The packaging and updater layers sit outside the physics, replay, analysis, comparison, calibration and video-export layers.

The canonical application version is `application/config/version` in `project.godot`. Packaging scripts, native package metadata, the updater and the release workflow all derive their version from that one value. Native operating-system version fields that cannot contain Semantic Version prerelease text are generated deterministically from it; they are not independent release versions.

## Install on macOS

The public macOS asset is named `CrashVector-<version>-macOS-universal.dmg`.

1. Download the DMG from the official `ArrowSK/crashvector` GitHub Release.
2. Open the DMG in Finder.
3. Drag `CrashVector.app` to the Applications shortcut shown in the disk image.
4. Launch CrashVector from Applications.

The M9 macOS build is Universal 2 and the packaging CI verifies that the application executable contains both `arm64` and `x86_64` slices.

To remove CrashVector, quit it and move `CrashVector.app` from Applications to Trash. No Terminal command is part of the normal installation or removal procedure.

### First-beta signing note

The packaging workflow always signs the application. When Apple Developer ID credentials are configured it uses Developer ID signing and can notarize the DMG. Without those paid credentials, the beta is ad-hoc signed and unnotarized. Gatekeeper can therefore warn that the developer cannot be verified. This is a distribution-signing limitation, not a checksum bypass: use only the package attached to the official GitHub Release and compare its published SHA-256 if independent verification is desired.

The workflow is intentionally designed so Developer ID signing and notarization can be enabled through repository secrets without changing the packaging architecture.

## Install on Windows

The public Windows asset is named `CrashVector-<version>-Windows-x64-Setup.exe`.

1. Download the Setup executable from the official `ArrowSK/crashvector` GitHub Release.
2. Run Setup and follow the graphical installer.
3. CrashVector installs under the normal 64-bit Program Files location.
4. The installer creates a Start-menu entry and registers CrashVector with Windows Installed apps.

To remove CrashVector, use Windows Settings → Apps → Installed apps → CrashVector → Uninstall. The installer supplies a normal Inno Setup uninstaller.

The first beta can be unsigned when Authenticode credentials are not configured, so Windows SmartScreen may show an unknown-publisher warning. The CI architecture already supports Authenticode signing of both the application executable and installer when a certificate is added; no packaging redesign is required.

## Built-in updater

The normal application UI contains **Updates**. The flow is:

`Updates → Check for updates → review version/release notes → Download → SHA-256 verify → Install`

CrashVector discovers releases only from the official `ArrowSK/crashvector` GitHub Releases API. It never silently installs an update.

The updater:

- shows the installed version and available version;
- supports Semantic Version prereleases such as `0.1.0-beta.1`;
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

The updater requires the manifest version and tag to agree with the GitHub Release and resolves package downloads by exact asset filename. The release pipeline generates the manifest only after both platform packages have been built and their checksum sidecars have been verified.

## Packaging architecture

M9 keeps generated files out of source control where they would create competing version or icon sources.

`tools/prepare_packaging.py` reads `project.godot` and generates the Godot export presets plus Inno Setup version definitions. `tools/render_icon.gd` renders the repository's canonical SVG branding master, and `tools/generate_icon_containers.py` deterministically generates and validates the native multi-resolution ICO/ICNS containers used by packaging. The branding artwork itself is not modified by M9.

The CI has three independent gates:

1. **Core CI (M0–M9)** — Godot import/parse, all existing M0–M8 regressions and runtime smoke tests, road-user/Comparison Lab tests, M9 updater/version tests, the complete-editor smoke test, and the no-monkey-patching audit.
2. **macOS package** — official Godot 4.4.1 editor/templates, real Universal 2 export, architecture verification, native icon packaging, signing verification, real DMG creation, mount/content validation and SHA-256 artifact.
3. **Windows package** — official Godot 4.4.1 editor/templates, real x64 export, native icon/version-resource verification, Inno Setup build, real install/uninstall validation and SHA-256 artifact.

M9 is not accepted merely because the source tests pass; all three gates must pass.

## No runtime monkey patching

M9 uses normal inheritance and a dedicated updater service. The main M9 editor layer extends the existing M8/extended editor and calls its base implementation rather than replacing an existing script at runtime.

CI scans production source for prohibited runtime script/resource replacement patterns such as `set_script(...)`, `take_over_path(...)`, direct `.script = ...` replacement, or equivalent script-property reassignment. A match fails Core CI.

## Release process

For a release candidate:

1. Change only the canonical `application/config/version` in `project.godot`.
2. Add human-readable notes under `docs/releases/<version>.md`.
3. Merge only after Core CI, macOS packaging and Windows packaging are green.
4. On a successful push to `main`, the release job downloads the already-validated platform artifacts, verifies both SHA-256 sidecars, generates `update-manifest.json`, and creates the corresponding GitHub Release.
5. Versions containing a prerelease suffix are published as GitHub prereleases.

Published release assets are immutable. If a released binary needs correction, increment the application version and publish a new release. The automation detects an existing tag/release and refuses to replace its binaries under the same version.

## `0.1.0-beta.1` release assets

The first M9 beta is expected to publish:

```text
CrashVector-0.1.0-beta.1-macOS-universal.dmg
CrashVector-0.1.0-beta.1-macOS-universal.dmg.sha256
CrashVector-0.1.0-beta.1-Windows-x64-Setup.exe
CrashVector-0.1.0-beta.1-Windows-x64-Setup.exe.sha256
update-manifest.json
```

## Building from source

Source development remains supported. Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the main scene. Git is needed only for source development, not for users installing the packaged desktop application.

The packaging helpers are release-engineering tools; end users do not need Python, Git, Godot, Terminal or PowerShell to install or update CrashVector.
