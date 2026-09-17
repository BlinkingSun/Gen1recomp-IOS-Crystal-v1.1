-- Probe: one screenshot per voxel pipeline level on a Crystal map, after
-- the bake, so every camera the ladder offers is on record.
--   POKEPORT_VERSION=crystal DS_PROBE_DIR=<dir> [G2_MAP= G2_X= G2_Y=]
return function(game)
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local MAP = os.getenv("G2_MAP") or "NEW_BARK_TOWN"
  local X, Y = tonumber(os.getenv("G2_X") or 8), tonumber(os.getenv("G2_Y") or 8)
  local logf = assert(io.open(OUT .. "/levels.log", "w"))
  local function log(...) local p = {} for i = 1, select("#", ...) do p[i] = tostring(select(i, ...)) end logf:write(table.concat(p, " "), "\n"); logf:flush() end
  local function wait(n) for _ = 1, n do coroutine.yield() end end
  local function shot(name)
    local done = false
    love.graphics.captureScreenshot(function(data)
      pcall(function() local f = assert(io.open(OUT .. "/" .. name, "wb")); f:write(data:encode("png"):getString()); f:close() end)
      done = true
    end)
    local n = 0; while not done and n < 120 do wait(1); n = n + 1 end
    log("shot", name, done and "ok" or "TIMEOUT")
  end
  local n = 0
  while not (game.world and game.world.map) do wait(1); n = n + 1; if n > 3600 then log("FAIL no world"); logf:close(); love.event.quit(); return end end
  pcall(function() game.world:setMap(MAP, X, Y, "up") end)
  wait(90)
  local Pipelines = require("src.render.Pipelines")
  local max = Pipelines.maxLevel and Pipelines.maxLevel("terrarium_voxel") or 1
  local labels = Pipelines.levelLabels and Pipelines.levelLabels("terrarium_voxel")
  log("maxLevel", max, "labels", labels and table.concat(labels, " | ") or "?")
  -- bake at max first so every lower level draws the finished mesh
  pcall(Pipelines.setLevel, "terrarium_voxel", max)
  wait(600)
  for lv = 1, max do
    pcall(Pipelines.setLevel, "terrarium_voxel", lv)
    wait(90)
    shot(("level%d.png"):format(lv))
  end
  -- and the tilt-shift ladder on top of the last level
  local tmax = Pipelines.maxLevel and Pipelines.maxLevel("terrarium_tiltshift") or 1
  local tl = Pipelines.levelLabels and Pipelines.levelLabels("terrarium_tiltshift")
  log("tilt maxLevel", tmax, "labels", tl and table.concat(tl, " | ") or "?")
  for lv = 1, tmax do
    pcall(Pipelines.setLevel, "terrarium_tiltshift", lv)
    wait(60)
    shot(("tilt%d.png"):format(lv))
  end
  log("done"); logf:close(); love.event.quit()
end
