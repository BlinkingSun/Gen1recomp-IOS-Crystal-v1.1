-- Crystal Trainer Art: full-colour trainer pics for Gen 2 battles.
--
-- Enemy trainers: the engine resolves a class's picture in
-- BattleState.trainerArt(data, classId) with no hook of its own, so that
-- function is wrapped (engine_internals) to answer with this mod's art and
-- trueColor. The player's back view goes through the public player.sprite
-- hook. Draw scales are battle_sprite_scales records keyed by asset path.
local mod = ...

local function loadData(rel)
  local source = mod:read(rel)
  if not source then
    error(("CRYSTAL_TRAINER_ART: %s is missing -- reinstall the mod"):format(rel), 0)
  end
  local chunk, err = load(source, "@" .. tostring(mod.path) .. "/" .. rel)
  if not chunk then
    error(("CRYSTAL_TRAINER_ART: %s did not compile: %s"):format(rel, tostring(err)), 0)
  end
  return chunk()
end

local ART = loadData("data/art.lua")

local resolved = {}
local function assetPath(rel)
  local hit = resolved[rel]
  if hit then return hit end
  local path = mod.assets:path(rel)
  resolved[rel] = path
  return path
end

local registered = 0
for group, recs in pairs(ART) do
  for id, rec in pairs(recs) do
    local path = assetPath(rec.path)
    if path then
      mod.content.battle_sprite_scales:register("cta_" .. group .. "_" .. id,
        { path = path, scale = rec.scale })
      registered = registered + 1
    end
  end
end
mod.log:info("Crystal Trainer Art: %d pics registered", registered)

-- Enemy trainers
local okB, BS2 = pcall(require, "src.ui.gen2.BattleState")
if okB and BS2 and BS2.trainerArt and not BS2.crystalTrainerArtHook then
  BS2.crystalTrainerArtHook = true
  local inner = BS2.trainerArt
  function BS2.trainerArt(data, classId)
    local rec = classId and ART.trainers[classId]
    if rec then
      local path = assetPath(rec.path)
      if path then return path, true end
    end
    return inner(data, classId)
  end
end

-- Player's back view: the engine picks the female path itself, so the path
-- it hands over tells which of the two to answer with.
mod.hooks:wrap("player.sprite", function(next, path, ctx)
  local out = next(path, ctx)
  if not (ctx and ctx.side == "back" and ctx.kind == "battle") or ctx.demo then
    return out
  end
  local hud = ctx.data and ctx.data.gen2MenuGfx and ctx.data.gen2MenuGfx.battleHud
  local female = hud and hud.playerBackFemale and path == hud.playerBackFemale
  local rec = ART.player[female and "KRIS_BACK" or "GOLD_BACK"]
  if not rec then return out end
  local resolvedPath = assetPath(rec.path)
  if not resolvedPath then return out end
  ctx.trueColor = true
  return resolvedPath
end)
