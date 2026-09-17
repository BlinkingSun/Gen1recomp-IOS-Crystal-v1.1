-- Standalone (luajit) dump of a Crystal map's cell collision + tile palettes.
-- usage: luajit tools/gen2_map_dump.lua <gen1recomp repo> <cache dir> <MAP_ID>
local engineRoot, cache, mapId = arg[1], arg[2], arg[3]
assert(engineRoot and cache and mapId, "usage: gen2_map_dump.lua <gen1recomp repo> <cache dir> <MAP_ID>")
package.path = engineRoot .. "/?.lua;" .. package.path
-- Permissions requires GameVersion; stub what it needs.
package.loaded["src.core.GameVersion"] = { get = function() return "crystal" end, generation = function() return 2 end, isCrystal = function() return true end }
local Permissions = require("src.world.gen2.Permissions")
local TileAttrs = require("src.world.gen2.TileAttrs")
local tilesets = dofile(cache .. "/tilesets.lua")
local maps = dofile(cache .. "/maps.lua")
local def = maps[mapId]; assert(def, "no map " .. tostring(mapId))
local ts = tilesets[def.tileset]; assert(ts, "no tileset " .. tostring(def.tileset))
print(("%s  tileset=%s  %dx%d blocks  border=%d  env=%s"):format(mapId, def.tileset, def.width, def.height, def.borderBlock or 0, tostring(def.environment)))
local function blockId(bx, by)
  if bx < 0 or by < 0 or bx >= def.width or by >= def.height then return def.borderBlock or 0 end
  return def.blocks[by * def.width + bx + 1] or 0
end
local function coll(cx, cy)
  local id = blockId(math.floor(cx / 2), math.floor(cy / 2))
  local quad = ts.collision[id + 1]; if not quad then return 0xff end
  local i = (cy % 2) * 2 + (cx % 2) + 1
  return quad[i] or 0xff
end
local function tile(tx, ty)
  local id = blockId(math.floor(tx / 4), math.floor(ty / 4))
  local block = ts.blocks[id + 1]; if not block then return nil end
  return block[(ty % 4) * 4 + (tx % 4) + 1]
end
local PAL = { [1]="g", [2]="R", [3]="G", [4]="W", [5]="Y", [6]="B", [7]="^", [8]="T" } -- gray red green water yellow brown roof text
local function cellClass(c)
  if Permissions.isWater(c) then return "~" end
  if Permissions.isGrass(c) then return "\"" end
  if Permissions.isCutTree(c) or Permissions.isHeadbuttTree(c) then return "t" end
  if Permissions.isLedge(c) then return "_" end
  if Permissions.isWarpCollision(c) then return "D" end
  if Permissions.isCounter(c) or (c >= 0x90 and c <= 0x9f) then return "c" end
  if Permissions.isWalkable(c) then return "." end
  if Permissions.isWall(c) then return "#" end
  return "?"
end
local W, Hc = def.width * 2, def.height * 2
print("\n-- cell class ('.' floor, '\"' grass, '~' water, 't' cut/headbutt tree, '_' ledge, 'D' warp, 'c' counter, '#' wall) with 1-cell border:")
for cy = -1, Hc do
  local row = {}
  for cx = -1, W do row[#row + 1] = cellClass(coll(cx, cy)) end
  print(table.concat(row))
end
print("\n-- raw collision bytes (hex) per cell:")
for cy = 0, Hc - 1 do
  local row = {}
  for cx = 0, W - 1 do row[#row + 1] = ("%02x"):format(coll(cx, cy)) end
  print(table.concat(row, " "))
end
print("\n-- tile palette slot per 8px tile (g gray, R red, G green, W water, Y yellow, B brown, ^ roof, T text), with 4-tile border:")
for ty = -4, Hc * 2 + 3 do
  local row = {}
  for tx = -4, W * 2 + 3 do
    local t = tile(tx, ty)
    local a = t and TileAttrs.forTile(ts, t)
    row[#row + 1] = a and (PAL[a.palette] or tostring(a.palette)) or " "
  end
  print(table.concat(row))
end
