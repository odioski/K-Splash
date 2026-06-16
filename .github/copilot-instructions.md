# K-Splash Copilot Instructions

## Build, package, and validation commands

This repository does not define an automated test suite or lint target. The repo-specific commands are:

- Package the plasmoid archive: `./compress-for-KDE-store.sh`
- Reinstall the plasmoid into the local Plasma 6 session: `./reinstall`

There is no single automated test command. For a targeted check of one change, reinstall with `./reinstall`, then exercise the specific widget behavior you changed in a running Plasma session:

- refresh flow: click **Refresh now**
- save flow: click the widget icon after enabling saved downloads
- settings flow: right-click the widget to open configuration

`./reinstall` assumes the checkout lives at `/home/mrod/CODE/K-Splash` because `PACKAGE_DIR` is hard-coded in that script. Update the script if the repository is moved.

`./compress-for-KDE-store.sh` writes `K-Splash-latest.tar.gz` at the repository root; that archive is part of this repository, so packaging changes may need the archive refreshed intentionally.

## High-level architecture

K-Splash is a KDE Plasma 6 plasmoid package declared in `metadata.json`. The runtime entry point is `contents/ui/main.qml`, and the configuration UI is wired from `contents/config/config.qml` to `contents/ui/configGeneral.qml`.

The code is split into three layers:

1. **Runtime UI and state (`contents/ui/main.qml`)**: owns the countdown timer, busy/error/status state, current photo metadata, widget interactions, and all command execution via `P5Support.DataSource { engine: "executable" }`.
2. **Pure helper/parsing layer (`contents/code/logic.js`)**: normalizes config input, chooses Unsplash sources, scrapes Unsplash HTML for image/photographer/details, builds attribution markup, and constructs shell commands for fetch, download, wallpaper update, sound playback, and saved-copy export.
3. **Configuration schema/UI (`contents/config/main.xml` + `contents/ui/configGeneral.qml`)**: `main.xml` defines persistent config keys, while `configGeneral.qml` exposes each key through `cfg_*` aliases and builds the settings form.

The refresh flow is:

1. `main.qml` collects `plasmoid.configuration` into a small config object and calls `Logic.buildUnsplashDomUrl(...)`.
2. `fetchExec` runs the curl command from `Logic.buildDomFetchCommand(...)`.
3. `handleUnsplashHtml(...)` passes the returned HTML to `Logic.extractDomPhotoDetails(...)`.
4. If wallpaper changes are enabled, `exec` runs the shell command from `Logic.buildCommand(...)`, which downloads the image to `/tmp` and updates every Plasma desktop wallpaper through `qdbus6`, `qdbus`, or `dbus-send`.

The save flow is separate: clicking the widget icon triggers `saveCurrentWallpaper()`, which copies the last downloaded temp image into the configured download directory using `Logic.buildSaveCopyCommand(...)`.

## Key conventions

- Keep orchestration in QML and reusable logic in `logic.js`. New parsing, URL construction, shell command assembly, or filename logic should go into `logic.js`, while `main.qml` should stay focused on state transitions and UI events.
- When adding or renaming a setting, update all of these together: `contents/config/main.xml`, the matching `cfg_*` alias in `contents/ui/configGeneral.qml`, and the config object assembled in `main.qml` before calling logic helpers.
- Command execution follows a consistent pattern: each `P5Support.DataSource` handler reads `exit code`/`stdout`/`stderr`, updates `lastStatus`, and always calls `disconnectSource(sourceName)`.
- Unsplash integration is DOM-scraping based, not official API driven. Preserve the current fallback behavior that rotates across collection URLs/IDs, custom search terms, and a final `"wallpaper"` search.
- Attribution formatting is intentional. The text should remain `Photo by [photographer] on Unsplash`, and outbound Unsplash/profile links should continue to use the referral query parameters from `REFERRAL_SOURCE` and `REFERRAL_MEDIUM`.
- Temporary wallpaper files are expected under `/tmp/K-Splash-wallpaper-<photoId>.jpg`. The permanent saved copy is derived from that temp file plus metadata from the most recent successful refresh.
