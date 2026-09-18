# How it works

## Why Crystal was a wall of trees

Terrarium's mesher decides what every 16×16 cell is from **Gen 1 tile ids**: the tileset names its
grass tile, its water tiles, its walkable tiles, and a hand-authored profile (`data/voxel_heights.lua`)
pins tree canopies, signs and posts by tile id. The engine's Gen 2 games have none of that. A Gold or
Crystal map carries a **collision byte** per cell (`COLL_*`, pokecrystal's permission table) and a **GBC
palette slot** per tile, and `Map:cellTile()` answers the collision byte, not a tile id. Two things
followed: every unpinned tile fell to "wall", and — the actual tree soup — Terrarium's profile ships a
`TILESET_JOHTO` entry of canopy tile ids measured on *Gold's* sheet, which Crystal reuses by name with a
different layout, so those pins landed on Crystal's grass and path tiles.

## The classifier (`lib/Gen2Terrain.lua`)

Per cell, from the engine's own predicates (`src/world/gen2/Permissions.lua`):
water · tall/long grass · lone tree (CUT / HEADBUTT) · ledge · warp · counter · ice · pit · ground · wall.
Walls are then refined by the tiles' palette slots and by 4-connected runs:

| palette / run | kind |
|---|---|
| green | **forest** → canopy hull |
| run with a roof-palette tile, a door on its edge, or a footprint ≥ 4×3 cells | **building** → wall, measured by the detector |
| brown / red / yellow otherwise (fences, posts, boxes, sea rocks) | **prop** → short standee |
| gray (cliffs, boulders, signs) | **rock** → wall; with a sign event → **signpost** |

`TileShape.at` takes that class ahead of every tile-level rule on Gen 2 maps. Profile pins are keyed by
lineage (`TILESET_JOHTO@crystal`; Gold keeps the bare name), so Gold's table can no longer fire on
Crystal. Tree canopies take their shades from the tiles the map actually draws in forest cells. Water
and shore are answered from the collision byte and the water palette. Crystal's tilesets bake two VRAM
banks into one 256-tile sheet; the grid and the atlas use sheet ids (in this cache no Crystal tileset
turned out to use the second bank, so that part is insurance).

## iOS

Three things stood between "renders on the Mac" and "renders on the phone":

1. **SDL 3.4 + external displays.** The engine's iOS build uses SDL 3.4, whose scene delegate runs the
   app's `main()` for *every* UIScene. Connect an external display (USB-C XR glasses, AirPlay) and iOS
   creates a second scene, SDL boots a second copy of the engine nested inside the running one, and the
   10-second scene watchdog kills the app. Patch 0001 makes the engine's own hook layer ignore any scene
   that is not the device's interactive scene and never start the app twice (SDL issue #16161).
2. **Gold's composite.** A world pipeline hands the engine a window-resolution image. The Gen 1 renderer
   blits it scaled by the display density and, on iOS with LÖVE 12, vertically flipped (a pass that
   bypasses LÖVE's projection lands the other way up in a Metal canvas). Gold's `World:draw` pasted it at
   1:1 with neither step: on a phone the scene was cropped to a corner with the player at the bottom
   edge, and upside down. Patch 0002 makes Gold do what Gen 1 does.
3. **Inside the mod**, the projection fold stays as Terrarium wrote it (the engine undoes it), and only
   two things are Metal-specific: the 2D overlays drawn into the scene canvas after the 3D pass are drawn
   pre-flipped so the engine's flip lands them upright, and the shadow map probes which way this runtime
   stores a folded pass before its first use. `Device.metal()` is Battle Art's detection rule (LÖVE ≥ 12
   and a Metal or Apple GLES renderer string).

## Why the level lives in `options.lua`

`Game2` loads its options from the `gold` block of the file and `Pipelines.applyOptions` reads
`gold.pipelines`. The top-level `pipelines` block is Gen 1's. The Gen 2 OPTIONS menu never builds the
engine's pipeline rows, and phones have no hotkeys — so the preset is the only switch.

## Battles on Crystal

Terrarium's "battle on the map" has a Gold first pass (`OverworldBattle.installGen2`)
that wraps the Gen 2 battle screen: it suppresses the opponent's panel picture
and is meant to stand the opponent in a frozen 3D shot of the arena. On Gen 2
the stand never appears, so a battle shows the player's Pokémon and the HUDs
over an empty patch of ground until it ends. The patch makes
`OverworldBattle.enabled()` return false on Gen 2 and drops the 3D-BTL options
row there; the engine's own battle screen then draws both pictures.

`CRYSTAL_BATTLE_ART` uses only public mod API: `pokemon.sprite` is raised for
every battle picture with the side and species being resolved, the mod answers
with its own PNG and sets `ctx.trueColor` so the GBC palette pass skips it, and
a `battle_sprite_scales` record per picture (keyed by the resolved asset path)
sizes it for the 7-tile enemy box and 6-tile player box. A replaced static
picture whose Crystal animation sheet is not replaced is held still by the
engine, which is what makes a one-frame-per-species mod enough.
