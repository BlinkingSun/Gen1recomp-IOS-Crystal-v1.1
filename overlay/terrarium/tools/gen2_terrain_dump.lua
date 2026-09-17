-- Standalone (luajit) check of lib/Gen2Terrain.lua against the engine's own
-- Gen 2 Map class and a Crystal cache.  No LÖVE needed.
-- usage: luajit tools/gen2_terrain_dump.lua <engine repo> <cache dir> <MAP_ID> [MAP_ID...]
local engineRoot, cache = arg[1], arg[2]
package.path = engineRoot .. "/?.lua;" .. package.path
package.loaded["src.core.GameVersion"] = {
  get = function() return "crystal" end, generation = function() return 2 end,
  isCrystal = function() return true end,
}
package.loaded["src.core.Logger"] = { warn = function() end, info = function() end }
local Map = require("src.world.gen2.Map")
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)/tools/") or "."
local Gen2Terrain = assert(loadfile(here .. "/lib/Gen2Terrain.lua"))({})
local tilesets = dofile(cache .. "/tilesets.lua")
local maps = dofile(cache .. "/maps.lua")
for i = 3, #arg do
  local def = assert(maps[arg[i]], "no map " .. arg[i])
  local map = Map.new(def, assert(tilesets[def.tileset]))
  print(("== %s (%s, %s, outdoor=%s)"):format(arg[i], def.tileset, tostring(Gen2Terrain.environment(map)), tostring(Gen2Terrain.isOutdoor(map))))
  print(Gen2Terrain.dump(map, true))
  local census = {}
  for cy = 0, map.heightCells - 1 do for cx = 0, map.widthCells - 1 do
    local k = Gen2Terrain.cellKind(map, cx, cy); census[k] = (census[k] or 0) + 1
  end end
  local parts = {}; for k, n in pairs(census) do parts[#parts + 1] = k .. "=" .. n end
  table.sort(parts); print("census: " .. table.concat(parts, " "))
end
