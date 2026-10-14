# Gridspace

A menu bar app that lays macOS desktops out as a 2D grid (2×2, 2×3, 2×4, 3×3) and moves between them with trackpad swipes in all four directions.

It doesn't replace Spaces. macOS still keeps desktops in one row; Gridspace maps that row onto a grid and switches with the "Switch to Desktop N" shortcuts. With Reduce motion on, switches fade instead of sliding.

## Install

```sh
make install   # builds, copies to /Applications and launches
make doctor    # prints the setup checks and exits non-zero if something needs fixing
make test
```

## Setup

The Doctor window opens on launch when something is off, and from the menu bar at any time. It checks and offers fixes for:

- Accessibility access (needed to send the shortcuts)
- a trackpad being present
- system 3- or 4-finger swipes, which would fire alongside Gridspace's
- Reduce motion (fade instead of slide)
- "Automatically rearrange Spaces based on most recent use", which would reshuffle the grid
- enough desktops for the grid
- the "Switch to Desktop N" shortcuts

Swipes are natural: fingers left go to the desktop on the right, fingers up go to the row below. "Invert vertical swipe" flips the vertical direction.

## Limits

- Up to 9 desktops, because the shortcuts beyond Desktop 9 have no default keys.
- Fullscreen app spaces are left out of the grid. Swipes do nothing while one is active.
- Trackpad input comes from the private MultitouchSupport framework, and the desktop list from private SkyLight calls. Either can break in a macOS update.
- Several displays with separate Spaces is untested.
