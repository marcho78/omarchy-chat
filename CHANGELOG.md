# Changelog

All notable changes to the Yapper plugin. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.4]

### Security
- Pins daemon 1.0.1, which bounds media downloads and ffmpeg, allowlists
  cached attachment extensions, rejects edits from other senders, and caps
  search time, socket requests and remote string lengths.
- Link previews are no longer fetched automatically in encrypted rooms; a
  "Show link preview" chip loads one on request.
- Notification arguments derived from other people's text can no longer be
  read as options by the notification script.
- `bin/pick-files` runs Python in isolated mode.

### Fixed
- Plain-text links containing `&` no longer end up double-escaped.

## [1.0.3]

### Security
- Before `makepkg` runs, the helper reduces the daemon checkout to exactly
  the verified commit with `git clean -fdx` and confirms nothing untracked
  or ignored remains; `makepkg` runs with `-C`, so its source directory is
  recreated from that tree on every build. Nothing from a previous build can
  reach the package. Source builds therefore compile in full every time.

## [1.0.2]

### Security
- Message HTML (`formatted_body`) is rebuilt from an allowlist of formatting
  tags and attributes; every other tag and attribute is dropped and all text
  is re-escaped. Links keep only `https://`, `http://` and `mailto:` targets,
  and every browser launch, from a message link, a link preview or the
  homeserver's sign-in URL, is refused unless the URL has one of those
  schemes.

## [1.0.1]

### Changed
- The plugin installs, reinstalls and updates only the daemon commit pinned
  in the plugin release (`daemonPinCommit`). The run-time lookup of newer
  `pkg-v*` tags is gone; a newer daemon ships as a new plugin release.

## [1.0.0]

### Added
- The Yapper look: rail, sidebar, room view, threads, room info, people,
  explore, search, settings, verification and recovery, with seven palettes,
  per-look color overrides, custom palettes and live color preview. The
  Omarchy look on the shell's own widgets stays available.
- Daemon install from the panel as a pacman package, prebuilt or built from
  source, pinned to one commit of the daemon repository and run in a
  terminal by `bin/yapper-helper`, with a progress card (phase, crates
  compiled, percentage, elapsed time) fed by the helper's state file.
- Quit Yapper in the rail: closes the window and stops the daemon.
- Settings › Daemon: Stop, Start, Restart, Reinstall or switch, Reset the
  data, Remove the package or everything.
- Daemon updates from `pkg-vX.Y.Z` tags, installed the same way.
- File attachments through the desktop portal file chooser.

### Changed
- Every program the plugin runs is named by absolute path; no shell.
- American spelling throughout.

[Unreleased]: https://github.com/marcho78/omarchy-yapper/compare/v1.0.4...HEAD
[1.0.4]: https://github.com/marcho78/omarchy-yapper/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/marcho78/omarchy-yapper/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/marcho78/omarchy-yapper/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/marcho78/omarchy-yapper/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/marcho78/omarchy-yapper/releases/tag/v1.0.0
