# AGENTS.md — PerAppVolume

Instructions for AI coding agents (Claude Code, Codex, Cursor, Copilot…) that need to **install**, **build** or **modify** PerAppVolume. Spanish version: [AGENTS.es.md](AGENTS.es.md).

PerAppVolume is a macOS menu bar app (Swift + SwiftUI, Swift Package Manager, no Xcode project) that controls the volume of each app using Core Audio process taps. Requires **macOS 14.2+**.

## Install for the user

Run these steps in order and report the result of each one. Stop and tell the user if a check fails.

1. **Check the platform.** `sw_vers -productVersion` must be 14.2 or newer.
2. **Install the latest release** (preferred, no build tools needed):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/barcodaniel501/PerAppVolume/main/scripts/install.sh | bash
   ```
   From a local clone you can run `PERAPPVOLUME_REPO=<owner>/PerAppVolume ./scripts/install.sh` instead.
   The script downloads the release zip, replaces `/Applications/PerAppVolume.app`, removes the quarantine attribute and opens the app.
3. **If there is no release yet, build from source** (needs the Command Line Tools; `xcode-select -p` must print a path, otherwise ask the user to run `xcode-select --install`):
   ```bash
   make install && open /Applications/PerAppVolume.app
   ```
   The universal build takes a few minutes; `ARCHS=arm64 make install` is faster on Apple Silicon.
4. **Verify:**
   ```bash
   pgrep -x PerAppVolume
   ```
   ```bash
   /Applications/PerAppVolume.app/Contents/MacOS/PerAppVolume --list
   ```
   The first command prints a PID when the app is running. The second prints the apps Core Audio sees (`[playing]` / `[idle]`) and exits.
5. **Tell the user what only they can do:**
   - Click the **sliders icon** in the menu bar.
   - When they first move an app's slider, macOS asks for **System Audio Recording**: they must click **Allow**. An agent cannot and must not grant this permission.
   - If they installed manually (without the script) and macOS blocks the app: **System Settings › Privacy & Security › Open Anyway**.

Never use `sudo`: nothing in the install needs administrator rights, and no drivers are installed.

### Uninstall

```bash
osascript -e 'quit app "PerAppVolume"'; rm -rf /Applications/PerAppVolume.app
```

Optional, removes saved volumes and settings: `defaults delete io.github.perappvolume.PerAppVolume`.

## Build and run

| Command | What it does |
| --- | --- |
| `swift build` | Debug build, fastest way to check that the code compiles |
| `make app` | Universal `build/PerAppVolume.app` + `build/PerAppVolume-<version>.zip` |
| `make install` | `make app` and copy to `/Applications` |
| `make run` | `make app` and open it |
| `make icon` | Regenerate `AppBundle/AppIcon.icns` from `scripts/make-icon.swift` |
| `make screenshots` | Regenerate `docs/screenshots/` (PNG + demo GIF, EN/ES, light/dark) with demo data |

Run `make screenshots` after any visible UI change and commit the new images. The `--screenshots` mode renders the SwiftUI views offscreen with demo data: it never creates audio taps, never changes the real volume and never saves settings.

There are no unit tests. To check a change: `swift build`, then `make install`, open the app and run `--list`. Audio behaviour (taps) can only be confirmed by the user listening, because it needs the System Audio Recording permission.

Each build gets a new ad-hoc signature, so macOS may ask the user for the audio permission again after reinstalling.

## Project map

```
Package.swift                      SwiftPM manifest (macOS 14.2, Swift 5 language mode)
AppBundle/                         Info.plist, AppIcon.icns, en.lproj / es.lproj
scripts/build-app.sh               builds per-arch, lipo, assembles .app, ad-hoc codesign, zip
scripts/install.sh                 installs the latest GitHub release
scripts/make-icon.swift            draws the app icon
.github/workflows/release.yml      CI build; publishes a Release on tags v*
Sources/PerAppVolume/
  main.swift                       entry point; handles --list and --screenshots
  ScreenshotGenerator.swift        renders README screenshots with demo data
  PerAppVolumeApp.swift            App entry + AppDelegate
  StatusItemController.swift       menu bar icon; the panel is a real NSMenu hosting the SwiftUI view
  MixerModel.swift                 app list, saved volumes, creates/removes taps
  Audio/AppTap.swift               process tap + private aggregate device + real-time gain
  Audio/AudioProcessScanner.swift  audio processes grouped by outermost .app bundle
  Audio/SystemVolume.swift         output device volume/mute
  Audio/CoreAudioHelpers.swift     Core Audio HAL helpers
  Localization.swift               all UI strings (English + Spanish)
  LaunchAtLogin.swift              SMAppService wrapper
  WindowManager.swift              mixer and settings windows
  Views/                           SwiftUI views
```

## Rules for changes

- **Bilingual:** every user-facing string goes in `Localization.swift` with English and Spanish text. Never hard-code UI text in views.
- **Docs in sync:** update both `README.md` (English, primary) and `README.es.md`, and both `AGENTS.md` and `AGENTS.es.md` when instructions change.
- **Menu panel:** keep it an `NSMenu` (not a `MenuBarExtra` window or custom panel) so it keeps the system look, keeps an auto-hidden menu bar visible while open, and closes on outside click. Timers that refresh the UI must run in `RunLoop.Mode.common`, because menus track events in `.eventTracking` mode.
- **Real-time code:** `AppTap.render` runs on the audio thread. No allocations, locks, logging or Swift arrays created there.
- **No drivers, no sudo:** keep the driver-free design based on `CATapDescription` with `muteBehavior = .mutedWhenTapped`.
- **Version:** bump `CFBundleShortVersionString` in `AppBundle/Info.plist`; releases are created by pushing a tag `vX.Y.Z`.
