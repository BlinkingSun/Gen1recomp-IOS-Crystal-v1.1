-- Gen 2 (Gold / Silver / Crystal) terrain classification.
--
-- On Gen 1 the mesher reads TILE IDS: map:cellTile() is a tile id and the
-- tileset carries id sets (walkable, waterTiles, grassTile, doorTiles ...).
-- On Gen 2 none of that exists: map:cellTile() answers the cell's COLL_*
-- collision byte (an unrelated number space) and the tileset carries a
-- collision quad per block plus a GBC palette slot per tile.  Read either
-- of those as a Gen 1 tile id and every town turns into forest, which is
-- exactly what 1.36.0-beta drew on Crystal.
--
-- This module answers the questions the terrain path asks -- "what is this
-- cell", "what does this tile look like" -- from the data Gen 2 actually
-- has:
--
--   * the COLL_* byte, through the engine's own predicates
--     (src/world/gen2/Permissions.lua, pokecrystal's permission table), for
--     floor / grass / water / small tree / ledge / warp / counter / wall;
--   * the tile's palette slot (src/world/gen2/TileAttrs.lua) to tell a
--     WALL apart: green = forest canopy, roof/brown/red/yellow = building,
--     gray = rock, fence, sign or other prop, water = a wet edge.
--
-- Everything here is pure over the map instance (src/world/gen2/Map.lua:
-- cellCollision / tileAt / tileset / def) and is safe to call on Gen 1 too:
-- every function answers nil there, so a caller can `or` it in front of the
-- Gen 1 path without a generation branch of its own.

local V = ...

local Gen2Terrain = {}

local Permissions, TileAttrs
local resolved = false
local function engine()
  if resolved then return Permissions end
  resolved = true
  local okP, P = pcall(require, "src.world.gen2.Permissions")
  local okT, T = pcall(require, "src.world.gen2.TileAttrs")
  if okP and type(P) == "table" and P.of then Permissions = P end
  if okT and type(T) == "table" and T.forTile then TileAttrs = T end
  return Permissions
end

-- A Gen 2 map instance: the one shape that has a collision quad table on
-- its tileset.  Gen 1 maps (and Gen 1 tilesets behind the compat alias)
-- never do, so this doubles as the generation test.
function Gen2Terrain.isGen2Map(map)
  return type(map) == "table" and type(map.tileset) == "table"
     and type(map.tileset.collision) == "table"
     and type(map.cellCollision) == "function"
end

-- ---------------------------------------------------------------- collision

-- pokecrystal constants/collision_constants.asm, the ones the predicates in
-- Permissions do not already name.
local COLL_FLOOR = 0x00
local COLL_WALL = 0x07
local COLL_PIT = 0x60
local COLL_PIT_68 = 0x68

local function isRange(c, lo, hi) return c >= lo and c <= hi end

-- The raw byte for a cell, border-extended (Map:blockId answers the border
-- block off-map), or nil on a Gen 1 map.
function Gen2Terrain.collision(map, cx, cy)
  if not Gen2Terrain.isGen2Map(map) then return nil end
  return map:cellCollision(cx, cy)
end

-- One word per cell.  Order matters: the specific kinds first, the two
-- permission buckets (walkable ground, impassable wall) last.
--
--   "ground"    COLL_FLOOR and every other LAND permission with no better
--               name (side walls b0-b7 are walkable cells with one blocked
--               edge; brakes/walk-forcers are floor to a renderer)
--   "grass"     tall / long grass (an encounter tile; drawn as a patch)
--   "water"     surfable water, waterfalls, currents, whirlpools, buoys
--   "ice"       ice floor (walkable, slippery)
--   "tree"      a CUT or HEADBUTT tree: one 2x2-cell prop, not forest
--   "ledge"     a hop ledge (Gen 2 says which way; see ledgeFacings)
--   "warp"      door, cave mouth, staircase, ladder, panel, carpet
--   "counter"   counter / shelf / PC / TV / bookshelf / window ... (indoor)
--   "pit"       a fall-through hole
--   "wall"      COLL_WALL and every other impassable byte
function Gen2Terrain.cellClass(map, cx, cy)
  local c = Gen2Terrain.collision(map, cx, cy)
  if c == nil then return nil end
  local P = engine()
  if not P then return nil end
  if P.isIce(c) then return "ice" end                     -- 0x23 sits inside the water bank
  if P.isWater(c) then return "water" end
  if isRange(c, 0x20, 0x3f) then return "water" end       -- the whole water bank: waterfalls, currents, whirlpools, buoys
  if isRange(c, 0xc0, 0xc7) then return "water" end       -- directional buoys
  if P.isGrass(c) then return "grass" end
  if P.isCutTree(c) or P.isHeadbuttTree(c) then return "tree" end
  if P.isLedge(c) then return "ledge" end
  if P.isWarpCollision(c) then return "warp" end
  if c == COLL_PIT or c == COLL_PIT_68 then return "pit" end
  if isRange(c, 0x90, 0x9f) then return "counter" end
  if P.isWalkable(c) then return "ground" end
  return "wall"
end

-- Convenience predicates in the vocabulary the Gen 1 path already uses.
function Gen2Terrain.isWaterCell(map, cx, cy)
  local k = Gen2Terrain.cellClass(map, cx, cy); if k == nil then return nil end
  return k == "water"
end
function Gen2Terrain.isWalkableCell(map, cx, cy)
  local k = Gen2Terrain.cellClass(map, cx, cy); if k == nil then return nil end
  return k == "ground" or k == "grass" or k == "ice" or k == "warp" or k == "ledge"
end
function Gen2Terrain.isGrassCell(map, cx, cy)
  local k = Gen2Terrain.cellClass(map, cx, cy); if k == nil then return nil end
  return k == "grass"
end
function Gen2Terrain.isDoorCell(map, cx, cy)
  local k = Gen2Terrain.cellClass(map, cx, cy); if k == nil then return nil end
  return k == "warp"
end

-- The facings that jump this ledge ({ down = true } etc.), or nil.
function Gen2Terrain.ledgeFacings(map, cx, cy)
  local c = Gen2Terrain.collision(map, cx, cy)
  local P = engine()
  if c == nil or not P or not P.ledgeFacings then return nil end
  return P.ledgeFacings(c)
end

-- ------------------------------------------------------------------- tiles

-- Palette slot names, pokecrystal constants/tileset_constants.asm PAL_BG_*
-- (+1, the way RomExtractorGen2 stores them).
local PALETTE = { "gray", "red", "green", "water", "yellow", "brown", "roof", "text" }
Gen2Terrain.PALETTE = PALETTE

-- Raw tile id on the 8px grid (border-extended), or nil.
function Gen2Terrain.tileId(map, tx, ty)
  if not Gen2Terrain.isGen2Map(map) or not map.tileAt then return nil end
  return map:tileAt(tx, ty)
end

-- { palette = "green", priority = bool, bank = 0|1 } for a tile, or nil.
function Gen2Terrain.tileHint(map, tx, ty)
  local id = Gen2Terrain.tileId(map, tx, ty)
  if id == nil then return nil end
  engine()
  local a = TileAttrs and TileAttrs.forTile(map.tileset, id)
  local slot = a and a.palette or 1
  return {
    id = id,
    palette = PALETTE[slot] or "gray",
    slot = slot,
    priority = a and a.priority or false,
    bank = a and a.vramBank or 0,
  }
end

-- Palette census of the four tiles under one 16px cell: { green = 3,
-- gray = 1 } plus `major`, the slot with the most tiles.
function Gen2Terrain.cellPalettes(map, cx, cy)
  if not Gen2Terrain.isGen2Map(map) then return nil end
  local counts, major, best = {}, nil, 0
  for dy = 0, 1 do
    for dx = 0, 1 do
      local h = Gen2Terrain.tileHint(map, cx * 2 + dx, cy * 2 + dy)
      if h then
        counts[h.palette] = (counts[h.palette] or 0) + 1
        if counts[h.palette] > best then best, major = counts[h.palette], h.palette end
      end
    end
  end
  counts.major = major
  return counts
end

-- A WALL cell, told apart by what it is drawn with and what it is joined to:
--   "forest"    green-palette wall: the tree border, hedges, bushes
--   "building"  a connected run of non-green walls that carries at least
--               one ROOF-palette tile: houses, labs, gates, towers
--   "prop"      brown / red / yellow walls with no roof anywhere in their
--               run: fences, posts, mailboxes, flower boxes
--   "water"     water-palette wall: a wet edge, a fountain rim
--   "rock"      gray: cliffs, boulders, signs, statues, ledges' faces
-- Non-wall cells answer their cellClass unchanged, so this is a strict
-- refinement: `kind = Gen2Terrain.cellKind(map, cx, cy) or gen1Kind`.
--
-- The run is a 4-connected flood over "built" wall cells (every palette
-- but green and water), computed once per map instance and cached on it.
-- Gen 2 map instances are static for a boot (the bridge builds one per
-- map id), and a Cut tree edit changes a tree cell, never a wall run.
local WALL_BY_PALETTE = {
  green = "forest", water = "water", gray = "rock", text = "rock",
  roof = "building", brown = "prop", red = "prop", yellow = "prop",
}

local function paletteKind(map, cx, cy)
  local pal = Gen2Terrain.cellPalettes(map, cx, cy)
  if pal and pal.roof and pal.roof > 0 then return "roof", pal end
  return (pal and pal.major) or "gray", pal
end

-- Label every built wall cell of the map (plus its 1-cell border ring)
-- with the id of its run, and record per run whether a roof was seen.
local function wallRuns(map)
  local runs = rawget(map, "__gen2TerrainRuns")
  if runs then return runs end
  runs = { cell = {}, building = {} }
  local W, H = map.widthCells, map.heightCells
  local function key(cx, cy) return cy * 4096 + cx end
  local function built(cx, cy)
    if cx < -1 or cy < -1 or cx > W or cy > H then return false end
    if Gen2Terrain.cellClass(map, cx, cy) ~= "wall" then return false end
    local pk = paletteKind(map, cx, cy)
    return pk ~= "green" and pk ~= "water"
  end
  local nextId = 0
  for cy = -1, H do
    for cx = -1, W do
      local k = key(cx, cy)
      if runs.cell[k] == nil and built(cx, cy) then
        nextId = nextId + 1
        local id, stack = nextId, { { cx, cy } }
        local sawRoof, sawDoor = false, false
        local minX, maxX, minY, maxY = cx, cx, cy, cy
        runs.cell[k] = id
        while #stack > 0 do
          local c = table.remove(stack)
          local x, y = c[1], c[2]
          if paletteKind(map, x, y) == "roof" then sawRoof = true end
          if x < minX then minX = x elseif x > maxX then maxX = x end
          if y < minY then minY = y elseif y > maxY then maxY = y end
          for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = x + d[1], y + d[2]
            local nk = key(nx, ny)
            if runs.cell[nk] == nil and built(nx, ny) then
              runs.cell[nk] = id
              stack[#stack + 1] = { nx, ny }
            elseif not sawDoor and Gen2Terrain.cellClass(map, nx, ny) == "warp" then
              sawDoor = true         -- a door in the wall: this run is a building
            end
          end
        end
        -- A building has a roof (the ROOF slot, or a red one on a gate), or a
        -- door, or at least a house's footprint.  Fences are one cell thin,
        -- sea rocks and flower boxes are one block: those stay props.
        local w, h = maxX - minX + 1, maxY - minY + 1
        runs.building[id] = sawRoof or sawDoor or (w >= 4 and h >= 3)
      end
    end
  end
  rawset(map, "__gen2TerrainRuns", runs)
  return runs
end

function Gen2Terrain.cellKind(map, cx, cy)
  local k = Gen2Terrain.cellClass(map, cx, cy)
  if k ~= "wall" then return k end
  local pk = paletteKind(map, cx, cy)
  if pk == "green" then return "forest" end
  if pk == "water" then return "water" end
  local runs = wallRuns(map)
  local id = runs.cell[cy * 4096 + cx]
  if id and runs.building[id] then return "building" end
  if pk == "roof" then return "building" end
  return WALL_BY_PALETTE[pk] or "rock"
end

-- Drop the cached runs (after a map edit that changes walls, if ever).
function Gen2Terrain.invalidate(map)
  if type(map) == "table" then
    rawset(map, "__gen2TerrainRuns", nil)
    rawset(map, "__gen2TreeTiles", nil)
  end
end

-- ------------------------------------------------------------------- map

-- Gen 2 stamps every map with an environment; the sky, the day/night tint
-- and the horizon all key off "is this outdoors".
local OUTDOOR = { TOWN = true, ROUTE = true }
function Gen2Terrain.isOutdoor(map)
  if not Gen2Terrain.isGen2Map(map) then return nil end
  local env = map.def and map.def.environment
  return OUTDOOR[env] == true
end

function Gen2Terrain.environment(map)
  if not Gen2Terrain.isGen2Map(map) then return nil end
  return map.def and map.def.environment or nil
end

-- ---------------------------------------------------------------- lineage

-- "gen1" | "gs" | "crystal" (src/core/GameVersion.lua:engine), resolved
-- once per boot.  Gold and Crystal share tileset NAMES but not sheets, so
-- anything authored per tile id has to be keyed by this as well.
local lineage
function Gen2Terrain.lineage()
  if lineage then return lineage end
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  local e = ok and GameVersion and GameVersion.engine and GameVersion.engine()
  lineage = (type(e) == "string" and e) or "gen1"
  return lineage
end

-- ------------------------------------------------------------- sheet ids

-- Crystal's tilesets bake into a 256-tile sheet: VRAM bank 0 at 0-127 and
-- bank 1 at 128-255 (src/world/gen2/TileAttrs.lua:sheetTileId).  A block's
-- raw tile byte is 0-127 either way and says which bank through its attr,
-- so the same raw id names two graphics.  Everything the mesher does with
-- a tile id -- atlas UVs, void tiles, per-tile pins -- has to use the
-- SHEET id, the way the engine's own 2D bake does.  Gold and Silver have
-- one bank and answer the raw id unchanged.
local MapAttrGrid
function Gen2Terrain.sheetTileId(map, raw)
  if raw == nil then return nil end
  local tileset = map and map.tileset
  if not (tileset and tileset.tileAttrs) then return raw end
  engine()
  if MapAttrGrid == nil then
    local ok, M = pcall(require, "src.world.gen2.MapAttrGrid")
    MapAttrGrid = (ok and type(M) == "table" and M.normalizeTile) and M or false
  end
  if not MapAttrGrid or not TileAttrs then return raw end
  local normId, attr = MapAttrGrid.normalizeTile(raw, tileset)
  if normId == nil then return raw end
  return TileAttrs.sheetTileId(normId, attr)
end

function Gen2Terrain.sheetTile(map, tx, ty)
  local raw = Gen2Terrain.tileId(map, tx, ty)
  if raw == nil then return nil end
  return Gen2Terrain.sheetTileId(map, raw)
end

-- ------------------------------------------------------------ mesher view

-- A bg event (sign, hidden item, ...) on this cell?  Gold has no sign
-- TILE: a signpost is a wall cell with a bgEvent to read.
function Gen2Terrain.isSignCell(map, cx, cy)
  if not Gen2Terrain.isGen2Map(map) or not map.signAtCell then return false end
  local ok, ev = pcall(map.signAtCell, map, cx, cy)
  return ok and ev ~= nil
end

-- The TileShape class a cell resolves to, in the mesher's own vocabulary
-- (lib/TileShape.lua FALLBACK_HEIGHTS / ART), or nil on a Gen 1 map:
--   ground / grass / water / ledge / counter   straight across
--   tree, forest    -> cylinder   one round canopy hull per cell
--   building, rock  -> wall       upright; the detector measures it
--   rock + bgEvent  -> signpost   a thin plate on a stick
--   prop            -> fence      a short standee (fence, post, box)
--   warp, ice, pit  -> ground     walkable; the door fold is Structures'
local CLASS = {
  ground = "ground", grass = "grass", water = "water", ledge = "ledge",
  counter = "counter", tree = "cylinder", forest = "cylinder",
  building = "wall", rock = "wall", prop = "fence",
  warp = "ground", ice = "ground", pit = "ground",
}
function Gen2Terrain.shapeClass(map, cx, cy)
  local kind = Gen2Terrain.cellKind(map, cx, cy)
  if kind == nil then return nil end
  if kind == "rock" and Gen2Terrain.isSignCell(map, cx, cy) then return "signpost" end
  return CLASS[kind] or "wall"
end

-- Every sheet tile id drawn in a tree or forest cell of this map (the
-- border ring included), for the canopy shade sampler.  Cached per map.
function Gen2Terrain.treeTiles(map)
  if not Gen2Terrain.isGen2Map(map) then return nil end
  local cached = rawget(map, "__gen2TreeTiles")
  if cached ~= nil then return cached or nil end
  local seen, list = {}, {}
  local W, H = map.widthCells, map.heightCells
  for cy = -1, H do
    for cx = -1, W do
      local k = Gen2Terrain.cellKind(map, cx, cy)
      if k == "forest" or k == "tree" then
        for dy = 0, 1 do
          for dx = 0, 1 do
            local id = Gen2Terrain.sheetTile(map, cx * 2 + dx, cy * 2 + dy)
            if id and not seen[id] then seen[id] = true; list[#list + 1] = id end
          end
        end
      end
    end
  end
  table.sort(list)
  rawset(map, "__gen2TreeTiles", #list > 0 and list or false)
  return #list > 0 and list or nil
end

-- One character per cell, for probes and dumps.
local GLYPH = {
  ground = ".", grass = '"', water = "~", ice = "=", tree = "t", ledge = "_",
  warp = "D", counter = "c", pit = "o", wall = "#",
  forest = "F", building = "H", rock = "r", prop = "p",
}
function Gen2Terrain.glyph(kind) return GLYPH[kind] or "?" end

function Gen2Terrain.dump(map, refine)
  if not Gen2Terrain.isGen2Map(map) then return nil end
  local W, H = map.widthCells, map.heightCells
  local rows = {}
  for cy = -1, H do
    local row = {}
    for cx = -1, W do
      local k = refine and Gen2Terrain.cellKind(map, cx, cy) or Gen2Terrain.cellClass(map, cx, cy)
      row[#row + 1] = Gen2Terrain.glyph(k)
    end
    rows[#rows + 1] = table.concat(row)
  end
  return table.concat(rows, "\n")
end

return Gen2Terrain
