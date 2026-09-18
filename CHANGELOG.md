# Changelog

## 0.3.0 — 2026-09-18

- Terrarium patch: battles on the map work on Gold. The Gen 1 staging is driven from the Gen 2 battle *screen* (the event payload hands over the model), the billboard bake scales by pack density, the player's back sprite stands in the foreground like Kanto's, staged sides are no longer drawn flat in the panel, the intro slide's white paper is skipped over a shot, and the HUD is lettered onto the world with an outline instead of white plates. When no arena fits, a softened snapshot of the last overworld frame backs the plain screen. The 3D-BTL and BACK SPRITES rows work on Gold.
- Screenshots: `battle-crystal-staged.png`, `battle-crystal-staged-intro.png`, `battle-crystal-staged-ios-simulator.png`.

## 0.2.0 — 2026-09-18

- Terrarium patch: Gold's "battle on the map" first pass is off (`OverworldBattle.enabled()` is false on Gen 2 and the 3D-BTL row is dropped). It hid the opponent's picture and never stood it in the 3D shot, so Crystal battles showed an empty arena until they ended. The engine's own battle screen draws both pictures again.
- New `battle-art/`: the `CRYSTAL_BATTLE_ART` mod. One Black/White still frame per species (front, back, shiny): `build.sh` downloads each species' animated PNG from the Bulbagarden Archives and keeps the first frame (or slices absol89's Battle Art atlases with `--battle-art DIR`), served through the engine's `pokemon.sprite` hook in true colour, with per-picture `battle_sprite_scales` records. No sprite art is in this repository.
- `screenshots/battle-crystal-bw.png`.

## 0.1.0 — 2026-09-17

First public kit.

- `overlay/terrarium/lib/Gen2Terrain.lua`: Gen 2 cell classifier (collision byte + tile palettes + wall runs), sheet-id remap for Crystal's two VRAM banks, per-map tree tiles, mesher class mapping.
- Terrarium patch: cell classes drive `TileShape.at` on Gen 2; profile pins keyed by game lineage; sheet ids in the grid; Gen 2 water from collision; canopy shades from the map; Gen 2 tree budget of 1400; `Map.tileAt` override in the bridge; Metal: overlay flip in `beginOverlay`, shadow-map orientation probe, `Device.metal()`.
- Engine patch 0001: iOS external-display scene guard (XR glasses / AirPlay no longer kill the app).
- Engine patch 0002: Gold composites a pipeline's world canvas like Gen 1 does (scaled to the playfield, flipped on iOS/LÖVE 12).
- Probes and tools for headless testing on desktop and in the iOS Simulator.
