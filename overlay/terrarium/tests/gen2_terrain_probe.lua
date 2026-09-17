-- Probe: lib/Gen2Terrain.lua INSIDE the engine, on a Gen 2 boot.
--
--   POKEPORT_VERSION=crystal DS_PROBE_DIR=<dir> \
--   POKEPORT_DRIVER=mods/TERRARIUM/tests/gen2_terrain_probe.lua gen1recomp
--
-- Warps to New Bark Town and dumps the classifier's view of the map and
-- of every neighbor the bridge hung a Map instance on, so the sandboxed
-- module (engine requires through the shim, rawset cache on the map) is
-- proven on the real objects the mesher will hand it.
return function(game)
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local logf = assert(io.open(OUT .. "/gen2_terrain.log", "w"))
  local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    logf:write(table.concat(parts, " "), "\n"); logf:flush()
  end
  local function wait(n) for _ = 1, n do coroutine.yield() end end
  local n = 0
  while not (game.world and game.world.map) do
    wait(1); n = n + 1
    if n > 3600 then log("FAIL: no world"); logf:close(); love.event.quit(); return end
  end
  local ok, err = pcall(function() game.world:setMap("NEW_BARK_TOWN", 8, 8, "down") end)
  log("setMap:", ok and "ok" or ("FAIL " .. tostring(err)))
  wait(30)
  local exports = game.mods and game.mods.exports
  local lib = exports and exports.TERRARIUM and exports.TERRARIUM.lib
  if not lib then log("FAIL: no TERRARIUM lib export"); logf:close(); love.event.quit(); return end
  local okG, Gen2Terrain = pcall(lib.require, "Gen2Terrain")
  log("require Gen2Terrain:", okG and "ok" or ("FAIL " .. tostring(Gen2Terrain)))
  if not okG then logf:close(); love.event.quit(); return end
  local world = game.world
  local function dumpMap(label, map)
    local okD, text = pcall(Gen2Terrain.dump, map, true)
    log(("== %s: isGen2Map=%s env=%s outdoor=%s"):format(label,
      tostring(Gen2Terrain.isGen2Map(map)), tostring(Gen2Terrain.environment(map)),
      tostring(Gen2Terrain.isOutdoor(map))))
    log(okD and (text or "nil") or ("dump FAIL " .. tostring(text)))
    local okK, kind = pcall(Gen2Terrain.cellKind, map, 8, 8)
    log("cellKind(8,8) =", okK and tostring(kind) or ("FAIL " .. tostring(kind)))
  end
  dumpMap(tostring(world.map and world.map.id), world.map)
  for _, nb in ipairs(world.neighbors or {}) do
    if nb.map then dumpMap("neighbor " .. tostring(nb.id), nb.map)
    else log("neighbor", tostring(nb.id), "has no map instance") end
  end
  log("done"); logf:close(); love.event.quit()
end
