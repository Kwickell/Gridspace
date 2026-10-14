# Gridspace

A menu bar app that lays macOS Spaces out as a 2D grid and moves between them with trackpad swipes in all four directions.

Desktops fill rows of a fixed width (2-5 columns). Fullscreen apps get their own rows below the desktops, oldest first, so opening or closing an app never moves a desktop. The grid grows and shrinks with however many Spaces exist.

It doesn't replace Spaces. Switching uses InstantSpaceSwitcher's synthetic Dock swipes (vendored in `Sources/ISS`, MIT), which land instantly with no animation, for desktops and fullscreen apps alike.

## Install

```sh
make install   # builds, copies to /Applications and launches
make doctor    # prints the setup checks and exits non-zero if something needs fixing
build/Gridspace.app/Contents/MacOS/Gridspace --list    # grid items in order, * marks the current one
build/Gridspace.app/Contents/MacOS/Gridspace --go 3    # jump to item 3
make test
```

## Setup

The Doctor window opens on launch when something is off, and from the menu bar at any time. It checks and offers fixes for:

- Accessibility access (needed to post the switching swipes)
- a trackpad being present
- system 3- or 4-finger swipes, which would fire alongside Gridspace's
- "Automatically rearrange Spaces based on most recent use", which would reshuffle the grid
- the desktop and fullscreen app count

Swipes are natural: fingers left go to the Space on the right, fingers up go to the row below. Moving into a shorter row lands on its last item. "Invert vertical swipe" flips the vertical direction.

## Limits

- Trackpad input comes from the private MultitouchSupport framework, the Space list from private SkyLight calls, and switching from undocumented Dock swipe events. Any of them can break in a macOS update.
- Several displays with separate Spaces is untested.
