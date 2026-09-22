# Changelog

All notable changes to the Yapper plugin. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/marcho78/omarchy-yapper/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/marcho78/omarchy-yapper/releases/tag/v1.0.0
