# Changelog

## 0.4.2 — 2026-09-18

- Terrarium patch: no paper anywhere in the two battle HUDs over the world (HP bars, "HP:" badge, frames and ball rows go through the palette shader's transparent-paper path; HP numbers are outlined like the names; rectangle fallbacks dropped). Message box and menus keep their paper.
- Terrarium patch: the wipe into a battle is painted in window space after the 3D composite, clipped to the GB panel, with the engine's own patterns and colours; the flash phase is emulated with brief veils. Previously the squares landed as a grey block and the Poké Balls lost their palette.

## 0.4.1 — 2026-09-18

- Terrarium patch: the scene stays up through a battle's ending. Gold emits `battle.ended` twice, from the battle model the moment the outcome is decided and from the screen when the faint, experience and fade are done; only the screen's now ends the staging. The world fades to white under the panel's own exit fade (and holds on a whiteout), as the original does.

## 0.4.0 — 2026-09-18

- New `trainer-art/`: the `CRYSTAL_TRAINER_ART` mod (full-colour trainer sprites for all 67 Gen 2 trainer classes plus the Gold and Kris back views) with the generation charter and scripts; wraps `BattleState.trainerArt` (`engine_internals`) and the `player.sprite` hook, scales via `battle_sprite_scales`. No images are committed.
- Terrarium patch: trainer cards are keyed only for the two-tone pics; true-colour trainer art keeps its own transparency.

## 0.3.1 — 2026-09-18

- Terrarium patch: enemy trainers stand in the arena too (their paper keyed out of the card), the shot waits until the battle screen is on top so the engine's wipe is untouched, and the intro-paper skip and outlined lettering apply only while drawing over a shot.
- Known: the engine's own battle wipe over Terrarium's Gold world shows a grey block and pink squares for a second; it did so before this kit too.

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
