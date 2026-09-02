# Installing CrashVector

CrashVector M9 introduces normal desktop packages. No Terminal or command prompt is required for normal installation, updating, or removal.

## macOS

The macOS package is a Universal 2 DMG and runs on both Apple Silicon and Intel Macs supported by Godot 4.4.1.

1. Download `CrashVector-<version>-macOS-universal.dmg` from the GitHub release.
2. Open the DMG.
3. Drag **CrashVector** to **Applications**.
4. Eject the CrashVector disk image.

The first public beta is ad-hoc signed rather than Developer-ID signed/notarized. macOS may therefore block the first launch. Use **System Settings → Privacy & Security → Open Anyway** after the first blocked launch. Do not disable Gatekeeper and do not use Terminal commands.

To uninstall, quit CrashVector and move **CrashVector.app** from Applications to the Trash. CrashVector's settings are stored separately in the normal user application-data location; deleting the app does not silently delete user settings.

## Windows

1. Download `CrashVector-<version>-Windows-x64-Setup.exe`.
2. Run the installer.
3. Accept the normal Windows elevation prompt if shown.
4. Launch CrashVector from the Start menu or the installer's final page.

The first beta is not Authenticode-signed, so Microsoft Defender SmartScreen may display an unknown-publisher warning.

To uninstall, use **Settings → Apps → Installed apps → CrashVector → Uninstall**. The installer registers CrashVector with Windows' standard uninstall system.

## Updates

Use **Updates** inside CrashVector. The app checks official GitHub Releases, downloads the package only after the user chooses Download, verifies its SHA-256 sidecar, then opens the normal platform installer and exits.

CrashVector does not patch or rewrite its own installed executable in place.
