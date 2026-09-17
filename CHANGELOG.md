# Changelog

## 0.1.0 — 2026-09-17

First public kit.

- `overlay/terrarium/lib/Gen2Terrain.lua`: Gen 2 cell classifier (collision byte + tile palettes + wall runs), sheet-id remap for Crystal's two VRAM banks, per-map tree tiles, mesher class mapping.
- Terrarium patch: cell classes drive `TileShape.at` on Gen 2; profile pins keyed by game lineage; sheet ids in the grid; Gen 2 water from collision; canopy shades from the map; Gen 2 tree budget of 1400; `Map.tileAt` override in the bridge; Metal: overlay flip in `beginOverlay`, shadow-map orientation probe, `Device.metal()`.
- Engine patch 0001: iOS external-display scene guard (XR glasses / AirPlay no longer kill the app).
- Engine patch 0002: Gold composites a pipeline's world canvas like Gen 1 does (scaled to the playfield, flipped on iOS/LÖVE 12).
- Probes and tools for headless testing on desktop and in the iOS Simulator.
