# Gridspace

A menu bar app that lays macOS Spaces out as a 2D grid and moves between them with trackpad swipes in all four directions.

Desktops fill rows of a fixed width (2-5 columns). Fullscreen apps get their own rows below the desktops, oldest first, so opening or closing an app never moves a desktop. The grid grows and shrinks with however many Spaces exist.

It doesn't replace Spaces. Desktops are reached with the "Switch to Desktop N" shortcuts and fullscreen apps by focusing their window. With Reduce motion on, switches fade instead of sliding.

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

- Accessibility access (needed to send the shortcuts)
- a trackpad being present
- system 3- or 4-finger swipes, which would fire alongside Gridspace's
- Reduce motion (fade instead of slide)
- "Automatically rearrange Spaces based on most recent use", which would reshuffle the grid
- the desktop and fullscreen app count
- the "Switch to Desktop N" and "Move left/right a space" shortcuts
- "When switching to an application, switch to a Space with open windows", which fullscreen jumps rely on

Swipes are natural: fingers left go to the Space on the right, fingers up go to the row below. Moving into a shorter row lands on its last item. "Invert vertical swipe" flips the vertical direction.

## Limits

- Up to 9 desktops, because the shortcuts beyond Desktop 9 have no default keys. Fullscreen apps have no limit.
- When a fullscreen app also has a window on another Space, macOS sometimes opens that one. Gridspace then walks the rest of the way with Control-arrow, which costs an extra fade or two.
- Trackpad input comes from the private MultitouchSupport framework, and the desktop list from private SkyLight calls. Either can break in a macOS update.
- Several displays with separate Spaces is untested.
