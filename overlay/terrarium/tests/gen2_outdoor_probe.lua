-- Probe: the voxel pass on a Crystal outdoor map, looking INTO the town.
--
--   POKEPORT_VERSION=crystal DS_PROBE_DIR=<dir> [G2_MAP=NEW_BARK_TOWN G2_X=8 G2_Y=8]
--   POKEPORT_DRIVER=mods/TERRARIUM/tests/gen2_outdoor_probe.lua gen1recomp
--
-- Like gold_outdoor_probe but facing UP (north), so the shots show the
-- houses and not the border forest, plus a dump of the class the mesher
-- resolved for every cell (Structures.forMap's shapeAt), beside the
-- classifier's own view, so a disagreement between the two is visible.
return function(game)
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local MAP = os.getenv("G2_MAP") or "NEW_BARK_TOWN"
  local X, Y = tonumber(os.getenv("G2_X") or 8), tonumber(os.getenv("G2_Y") or 8)
  local logf = assert(io.open(OUT .. "/gen2_outdoor.log", "w"))
  local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    logf:write(table.concat(parts, " "), "\n"); logf:flush()
  end
  local rawprint = print
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    logf:write("[print] ", table.concat(parts, "\t"), "\n"); logf:flush()
    rawprint(...)
  end
  local function wait(n) for _ = 1, n do coroutine.yield() end end
  local Logger = require("src.core.Logger")
  local seen = 0
  local function drain(tag)
    local h = Logger.history
    if #h > seen then
      for i = seen + 1, #h do log(tag, h[i]) end
      seen = #h
    end
  end
  local function shot(name)
    local done = false
    love.graphics.captureScreenshot(function(data)
      local ok, err = pcall(function()
        local fd = data:encode("png")
        local f = assert(io.open(OUT .. "/" .. name, "wb"))
        f:write(fd:getString()); f:close()
      end)
      if not ok then log("shot FAIL", name, tostring(err)) end
      done = true
    end)
    local n = 0
    while not done and n < 120 do wait(1); n = n + 1 end
    log("shot", name, done and "ok" or "TIMEOUT")
  end

  local n = 0
  while not (game.world and game.world.map) do
    wait(1); n = n + 1
    if n > 3600 then log("FAIL: no world"); logf:close(); love.event.quit(); return end
  end
  drain("[boot]")
  local ok, err = pcall(function() game.world:setMap(MAP, X, Y, "up") end)
  log("setMap", MAP, X, Y, "up:", ok and "ok" or ("FAIL " .. tostring(err)))
  wait(120)
  drain("[warp]")
  shot("g2_2d.png")

  local Pipelines = require("src.render.Pipelines")
  local okL, errL = pcall(function()
    Pipelines.setLevel("terrarium_voxel",
      Pipelines.maxLevel and Pipelines.maxLevel("terrarium_voxel") or 1)
  end)
  if not okL then log("setLevel FAIL:", tostring(errL)) end
  for i = 1, 6 do wait(120); drain("[voxel" .. i .. "]") end
  shot("g2_voxel.png")

  -- the mesher's view of the map beside the classifier's
  local exports = game.mods and game.mods.exports
  local lib = exports and exports.TERRARIUM and exports.TERRARIUM.lib
  if lib then
    local okS, Structures = pcall(lib.require, "Structures")
    local okG, Gen2Terrain = pcall(lib.require, "Gen2Terrain")
    local world = game.world
    local map = world.map
    if okS and okG and map then
      local okF, S = pcall(Structures.forMap, map)
      if not okF then log("Structures.forMap FAIL:", tostring(S)) else
        local SYM = { water = "~", ground = ".", wall = "#", ledge = "_", grass = '"',
          cylinder = "o", canopy = "O", fence = "f", sign = "s", signpost = "s",
          post = "|", billboard = "b", prop = "p", void = " ", tree = "T",
          roof = "^", cliff = "C", counter = "c", flower = "*" }
        local W, H = map.widthCells, map.heightCells
        log(("== mesher classes for %s (%dx%d cells; top-left tile of each cell), then classifier"):format(map.id, W, H))
        for cy = -1, H do
          local row, row2 = {}, {}
          for cx = -1, W do
            local s = S.shapeAt[(cy * 2 + 64) * 4096 + (cx * 2 + 64)]   -- Structures' keyOf(tx, ty)
            row[#row + 1] = s and (SYM[s.class] or "?") or " "
            row2[#row2 + 1] = Gen2Terrain.glyph(Gen2Terrain.cellKind(map, cx, cy))
          end
          log(table.concat(row) .. "   " .. table.concat(row2))
        end
        local sites = S.treeSites and #S.treeSites or -1
        log("treeSites =", sites, "runs =", S.runs and #S.runs or "?",
            "doorFold =", S.doorFold and #S.doorFold or "?", "figures =", S.figures and #S.figures or "?")
      end
    else
      log("lib require FAIL", tostring(Structures), tostring(Gen2Terrain))
    end
  else
    log("no TERRARIUM lib export")
  end

  -- walk north 3, look again
  local input = game.input
  if input and input.pressQueue then
    for _ = 1, 3 do input.pressQueue[#input.pressQueue + 1] = "up"; wait(24) end
  end
  wait(60); drain("[walk]")
  shot("g2_walk.png")
  local okT, errT = pcall(function()
    Pipelines.setLevel("terrarium_tiltshift",
      Pipelines.maxLevel and Pipelines.maxLevel("terrarium_tiltshift") or 1)
  end)
  if not okT then log("tilt setLevel FAIL:", tostring(errT)) end
  wait(120); drain("[tilt]")
  shot("g2_tilt.png")
  drain("[end]"); log("done"); logf:close(); _G.print = rawprint
  love.event.quit()
end
