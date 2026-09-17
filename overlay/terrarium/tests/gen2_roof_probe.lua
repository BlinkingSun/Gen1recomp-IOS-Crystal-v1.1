-- Probe: what the gabled-roof pass samples on a Crystal house.
--   POKEPORT_VERSION=crystal DS_PROBE_DIR=<dir> G2_MAP= G2_X= G2_Y= G2_TX0= G2_TX1= G2_TY0= G2_TY1=
return function(game)
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local MAP = os.getenv("G2_MAP") or "NEW_BARK_TOWN"
  local X, Y = tonumber(os.getenv("G2_X") or 7), tonumber(os.getenv("G2_Y") or 11)
  local TX0, TX1 = tonumber(os.getenv("G2_TX0") or 6), tonumber(os.getenv("G2_TX1") or 13)
  local TY0, TY1 = tonumber(os.getenv("G2_TY0") or 20), tonumber(os.getenv("G2_TY1") or 25)
  local logf = assert(io.open(OUT .. "/roof.log", "w"))
  local function log(...) local p = {} for i = 1, select("#", ...) do p[i] = tostring(select(i, ...)) end logf:write(table.concat(p, " "), "\n"); logf:flush() end
  local function wait(n) for _ = 1, n do coroutine.yield() end end
  local function shot(name)
    local done = false
    love.graphics.captureScreenshot(function(data) pcall(function() local f = assert(io.open(OUT .. "/" .. name, "wb")); f:write(data:encode("png"):getString()); f:close() end); done = true end)
    local n = 0; while not done and n < 120 do wait(1); n = n + 1 end
  end
  local n = 0
  while not (game.world and game.world.map) do wait(1); n = n + 1; if n > 3600 then log("FAIL no world"); logf:close(); love.event.quit(); return end end
  pcall(function() game.world:setMap(MAP, X, Y, "up") end)
  wait(60)
  local Pipelines = require("src.render.Pipelines")
  pcall(Pipelines.setLevel, "terrarium_voxel", 5); wait(500)
  local lib = game.mods.exports.TERRARIUM.lib
  local Structures = lib.require("Structures")
  local Gen2Terrain = lib.require("Gen2Terrain")
  local map = game.world.map
  local S = Structures.forMap(map)
  local function keyOf(tx, ty) return (ty + 64) * 4096 + (tx + 64) end
  local seen = {}
  for ty = TY0, TY1 do
    local row = {}
    for tx = TX0, TX1 do
      local run = S.runs[keyOf(tx, ty)]
      local s = S.shapeAt[keyOf(tx, ty)]
      local t = map:tileAt(tx, ty)
      local h = Gen2Terrain.tileHint(map, tx, ty)
      row[#row + 1] = ("%3s/%s%s"):format(t and ("%02x"):format(t) or "--", h and h.palette:sub(1,2) or "??", run and "*" or " ")
      if run and not seen[run] then
        seen[run] = true
        local parts = {}
        for k, v in pairs(run) do if type(v) ~= "table" and type(v) ~= "function" then parts[#parts + 1] = k .. "=" .. tostring(v) end end
        table.sort(parts)
        log(("RUN at tx=%d ty=%d: %s"):format(tx, ty, table.concat(parts, " ")))
        if run.roofRows and run.north then
          for idx = 0, run.roofRows - 1 do
            local rt = map:tileAt(tx, run.north + idx)
            local rh = Gen2Terrain.tileHint(map, tx, run.north + idx)
            log(("   roof idx %d -> row %d tile %s palette %s"):format(idx, run.north + idx, tostring(rt), rh and rh.palette or "?"))
          end
        end
      end
    end
    log(("ty %2d: %s"):format(ty, table.concat(row, " ")))
  end
  for lv = 3, 5 do pcall(Pipelines.setLevel, "terrarium_voxel", lv); wait(60); shot(("roof_level%d.png"):format(lv)) end
  log("done"); logf:close(); love.event.quit()
end
