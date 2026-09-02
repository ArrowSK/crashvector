# Desktop packaging

M9 is the first desktop-distribution milestone.

## Release version

The first package line is `0.1.0-beta.1`. `VERSION`, `AppMetadata.VERSION`, export metadata, installer metadata, release notes, and updater tests are kept in sync by CI.

## macOS

GitHub Actions builds the project on `macos-14` with the official Godot 4.4.1 editor and export templates. The exported Universal 2 `.app` is ad-hoc codesigned, verified with `codesign`, placed beside an Applications shortcut, and packed into a compressed DMG with `hdiutil`.

This is deliberately not presented as notarized. If Apple Developer credentials are added later, the workflow can replace ad-hoc signing with Developer ID signing/notarization.

## Windows

GitHub Actions builds the Windows x64 Godot export and packages it with Inno Setup. The installer writes CrashVector under Program Files, creates Start-menu entries, and registers a normal Windows uninstaller.

## Release publication

On pull requests, both package jobs build and upload temporary GitHub Actions artifacts. They do not publish a release.

On a successful push to `main`, the same package jobs run again. Only after both succeed does the publication job verify the SHA-256 sidecars and create the versioned GitHub prerelease if that tag does not already exist.

Published version assets are treated as immutable. A changed build requires a new version.

## Package names

- `CrashVector-<version>-macOS-universal.dmg`
- `CrashVector-<version>-macOS-universal.dmg.sha256`
- `CrashVector-<version>-Windows-x64-Setup.exe`
- `CrashVector-<version>-Windows-x64-Setup.exe.sha256`
- `update-manifest.json`
