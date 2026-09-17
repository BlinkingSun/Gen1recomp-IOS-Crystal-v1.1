# Testing

## Standalone (no LÖVE): the classifier against a cache

```sh
luajit overlay/terrarium/tools/gen2_terrain_dump.lua work/gen1recomp "<save dir>/crystal/data/generated" NEW_BARK_TOWN ROUTE_29
```

Prints one glyph per cell (`F` forest, `H` building, `p` prop, `r` rock, `t` lone tree, `"` grass,
`~` water, `_` ledge, `D` warp, `.` ground) plus a census. `gen2_map_dump.lua` prints the raw collision
bytes and palette slots.

## Headless drivers (desktop)

The engine runs a driver script with `POKEPORT_DRIVER=<file>`; the probes in `overlay/terrarium/tests/`
boot Crystal, warp, switch the pipeline on, and write logs and screenshots into `DS_PROBE_DIR`:

```sh
POKEPORT_IDENTITY=probe POKEPORT_VERSION=crystal DS_PROBE_DIR=/tmp/out \
POKEPORT_DRIVER=work/Terrarium/tests/gen2_levels_probe.lua  <gen1recomp app or `love .`>
```

- `gen2_levels_probe.lua` — one screenshot per camera level (and per tilt-shift level).
- `gen2_outdoor_probe.lua` — north-facing shots plus a grid of the class the mesher resolved for every
  cell beside the classifier's own; `G2_MAP`, `G2_X`, `G2_Y` pick the spot.
- `gen2_gpu_probe.lua` — the 3D availability verdict, shader compile log and renderer info (what the
  mod's own GPU report would say).
- `gen2_terrain_probe.lua`, `gen2_roof_probe.lua` — classifier and roof-run dumps.

The identity is a separate save directory; copy a Crystal cache into it (`crystal/` from your real
save directory) and put the mod under its `mods/`.

## iOS Simulator (Metal, with a console)

```sh
cd work/gen1recomp && scripts/build_ios.sh --release --version 0.2.60     # no --device = simulator
xcrun simctl boot <device>; xcrun simctl install <device> dist/ios/Release-iphonesimulator/gen1recomp++.app
xcrun simctl get_app_container <device> <bundle id> data                  # seed Documents/ there
SIMCTL_CHILD_POKEPORT_VERSION=crystal SIMCTL_CHILD_POKEPORT_GAME=crystal \
SIMCTL_CHILD_POKEPORT_DRIVER=<abs path inside the container> \
  xcrun simctl launch --console-pty <device> <bundle id>
xcrun simctl io <device> screenshot out.png
```

Notes: on iOS `love.event.quit()` restarts the app in-process, so a driver that is done should idle
rather than quit; a reinstall changes the container path, so drivers that hard-code it must be
regenerated.
