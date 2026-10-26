# Gridspace

A menu bar app that lays macOS Spaces out as a 2D grid and moves between them with trackpad swipes in all four directions.

Each display has a fixed grid (rows × columns) where desktops and fullscreen apps sit in whatever cells you put them, with empty cells allowed. Arrange Spaces (⌃⌥⌘G or the menu) sets the size and lets you drag Spaces onto any cell; dropping on another Space swaps them. A closed Space leaves its cell empty; a new one fills the first free cell after the last filled one, then the earliest free cell, and a full grid grows by a row. Mission Control's order is never changed.

It doesn't replace Spaces. Switching uses InstantSpaceSwitcher's synthetic Dock swipes (vendored in `Sources/ISS`, MIT), which land instantly with no animation, for desktops and fullscreen apps alike.

## Install

```sh
make install   # builds, copies to /Applications and launches
swift scripts/make-icon.swift   # regenerates Resources/AppIcon.icns
make doctor    # prints the setup checks and exits non-zero if something needs fixing
build/Gridspace.app/Contents/MacOS/Gridspace --list    # grid items in order, * marks the current one
build/Gridspace.app/Contents/MacOS/Gridspace --go 3    # jump to item 3
make test
```

## Setup

The first launch opens a short onboarding: grant Accessibility and Input Monitoring, hand the trackpad swipes to Gridspace, and arrange the grid. Settings (⌘, from the menu) holds the finger count, swipe handover, vertical direction, overlay, the Arrange shortcut and launch at login.

The Doctor (in the menu and Settings) checks the setup any time and offers fixes for:

- Accessibility access (needed to post the switching swipes)
- a trackpad being present
- system 3- or 4-finger swipes, which would fire alongside Gridspace's
- the desktop and fullscreen app count

Swipes are natural: fingers left go to the Space on the right, fingers up go to the row below. Empty cells are skipped; if nothing is filled in that direction, nothing happens. "Invert vertical swipe" flips the vertical direction.

## Limits

- Trackpad input comes from the private MultitouchSupport framework, the Space list from private SkyLight calls, and switching from undocumented Dock swipe events. Any of them can break in a macOS update.
- Several displays with separate Spaces is untested.

## Licence

MIT, see `LICENSE`. The vendored InstantSpaceSwitcher code in `Sources/ISS` keeps its own MIT licence, in `Sources/ISS/LICENSE`.
