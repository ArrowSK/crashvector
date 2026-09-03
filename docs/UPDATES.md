# Update architecture

M9 adds an explicit updater rather than modifying application code at runtime.

## User flow

1. CrashVector may check official GitHub Releases once per day. Automatic checks can be disabled.
2. A check transfers release metadata only.
3. When a compatible newer release exists, the user chooses whether to download it.
4. CrashVector downloads the platform package and the matching `.sha256` sidecar.
5. The package is hashed locally and deleted if verification fails.
6. **Open installer & quit** hands control to the operating system:
   - macOS opens the verified DMG;
   - Windows launches the verified Setup executable.
7. The normal system install replaces/upgrades the application.

No update is installed silently.

## Channels

A prerelease build such as `0.1.0-beta.1` is allowed to see newer prereleases and stable releases. A stable build does not automatically opt into prereleases.

The updater uses semantic-version ordering rather than comparing version strings lexically.

## Trust boundary

SHA-256 verification detects corruption or an asset/sidecar mismatch. It is not a substitute for platform code signing because the package and checksum are published through the same GitHub release account.

The first beta is ad-hoc signed on macOS and unsigned on Windows. Future Developer ID/notarization and Authenticode signing can be added to the packaging workflow without changing the updater's package handoff model.

## No monkey patching

CrashVector production GDScript does not replace live scripts or take over Resource paths at runtime. Milestones extend the application through normal inheritance, composition, explicit services, and signals. CI rejects `set_script(...)` and `take_over_path(...)` in `src/`.

The updater is a normal `UpdateService` Node. It does not inject or overwrite methods in the editor.
