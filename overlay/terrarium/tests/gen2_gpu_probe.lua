-- Probe: can Terrarium's 3D pass build on THIS renderer?  Boots Crystal,
-- turns the voxel pipeline on, and writes the verdict, the shader compile
-- log and the renderer info -- the same report reportGPU() would write if
-- the engine ever asked the pipeline's `available` on a Gen 2 boot.
--   POKEPORT_VERSION=crystal DS_PROBE_DIR=<dir> [G2_MAP= G2_X= G2_Y=]
return function(game)
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local MAP = os.getenv("G2_MAP") or "NEW_BARK_TOWN"
  local X, Y = tonumber(os.getenv("G2_X") or 8), tonumber(os.getenv("G2_Y") or 8)
  local logf = assert(io.open(OUT .. "/gpu.log", "w"))
  local function log(...) local p = {} for i = 1, select("#", ...) do p[i] = tostring(select(i, ...)) end logf:write(table.concat(p, " "), "\n"); logf:flush() end
  local rawprint = print
  _G.print = function(...) local p = {} for i = 1, select("#", ...) do p[i] = tostring(select(i, ...)) end logf:write("[print] ", table.concat(p, "\t"), "\n"); logf:flush(); rawprint(...) end
  local function wait(n) for _ = 1, n do coroutine.yield() end end
  local function shot(name)
    local done = false
    love.graphics.captureScreenshot(function(data) pcall(function() local f = assert(io.open(OUT .. "/" .. name, "wb")); f:write(data:encode("png"):getString()); f:close() end); done = true end)
    local n = 0; while not done and n < 120 do wait(1); n = n + 1 end
    log("shot", name, done and "ok" or "TIMEOUT")
  end
  log("love version:", love.getVersion())
  local okR, name, ver, vendor, device = pcall(love.graphics.getRendererInfo)
  log("renderer:", okR and (tostring(name) .. " | " .. tostring(ver) .. " | " .. tostring(vendor) .. " | " .. tostring(device)) or "?")
  local okS, caps = pcall(love.graphics.getSupported)
  if okS and type(caps) == "table" then local parts = {} for k, v in pairs(caps) do parts[#parts + 1] = k .. "=" .. tostring(v) end table.sort(parts); log("supported:", table.concat(parts, " ")) end
  local okF, fmts = pcall(love.graphics.getCanvasFormats)
  if okF and type(fmts) == "table" then local parts = {} for k, v in pairs(fmts) do if v then parts[#parts + 1] = k end end table.sort(parts); log("canvas formats:", table.concat(parts, " ")) end
  local n = 0
  while not (game.world and game.world.map) do wait(1); n = n + 1; if n > 3600 then log("FAIL no world"); logf:close(); love.event.quit(); return end end
  pcall(function() game.world:setMap(MAP, X, Y, "up") end)
  wait(60)
  local Pipelines = require("src.render.Pipelines")
  log("pipelines registered:", (function() local t = {} for _, e in ipairs(Pipelines.list()) do t[#t + 1] = e.id .. "(world=" .. tostring(e.def.drawWorld ~= nil) .. ")" end return table.concat(t, " ") end)())
  log("world pipeline before:", tostring(Pipelines.worldPipeline and Pipelines.worldPipeline()), "level terrarium_voxel =", tostring(Pipelines.level("terrarium_voxel")))
  local okL, errL = pcall(Pipelines.setLevel, "terrarium_voxel", 3)
  log("setLevel(terrarium_voxel, 3):", okL and "ok" or ("FAIL " .. tostring(errL)), "-> level now", tostring(Pipelines.level("terrarium_voxel")), "world pipeline", tostring(Pipelines.worldPipeline and Pipelines.worldPipeline()))
  wait(300)
  local lib = game.mods and game.mods.exports and game.mods.exports.TERRARIUM and game.mods.exports.TERRARIUM.lib
  if not lib then log("FAIL: no TERRARIUM lib export (mod not loaded?)"); shot("gpu_noload.png"); logf:close(); love.event.quit(); return end
  local Voxel3D = lib.require("Voxel3D")
  local okA, avail = pcall(Voxel3D.available)
  log("Voxel3D.available():", okA and tostring(avail) or ("threw " .. tostring(avail)))
  local okRep, rep = pcall(Voxel3D.report)
  log("---- Voxel3D.report() ----"); log(okRep and tostring(rep) or ("threw " .. tostring(rep))); log("---- end report ----")
  local okQ, Quality = pcall(lib.require, "Quality")
  if okQ and Quality and Quality.report then local okq, q = pcall(Quality.report); log("Quality:", okq and tostring(q) or tostring(q)) end
  local okC, ChunkMesher = pcall(lib.require, "ChunkMesher")
  if okC then
    for _ = 1, 300 do pcall(ChunkMesher.pump, false); coroutine.yield() end
    local okB, res = pcall(ChunkMesher.build, game.world.map, false, {})
    log("ChunkMesher.build:", okB and ("ok -> " .. tostring(res)) or ("THREW " .. tostring(res)))
  end
  shot("gpu_after.png")
  log("done"); logf:close(); _G.print = rawprint
  love.event.quit()
end
