local ADDON_NAME = ...
local ThirstTrap = _G[ADDON_NAME]

function ThirstTrap:GetOptions()
  local classes = { WARRIOR=true, PALADIN=true, HUNTER=true, ROGUE=true, PRIEST=true, SHAMAN=true, MAGE=true, WARLOCK=true, DRUID=true }
  local perClassArgs = {}
  for class,_ in pairs(classes) do
    perClassArgs[class] = {
      type = "group",
      name = class,
      args = {
        water = { type="range", name="Water stacks", min=0, max=6, step=1, get=function() return ThirstTrap.db.profile.perClass[class].water end, set=function(_,v) ThirstTrap.db.profile.perClass[class].water = v end },
        food  = { type="range", name="Food stacks",  min=0, max=6, step=1, get=function() return ThirstTrap.db.profile.perClass[class].food end, set=function(_,v) ThirstTrap.db.profile.perClass[class].food = v end },
      }
    }
  end

  local options = {
    type = "group",
    name = ADDON_NAME,
    childGroups = "tabs",
    args = {
      General = {
        type = "group", name = "General", order = 1,
        args = {
          auto = { type="toggle", name="Auto mode", desc="Preselect amounts based on class/whisper", get=function() return ThirstTrap.db.profile.auto end, set=function(_,v) ThirstTrap.db.profile.auto = v ThirstTrap:UpdateTradeButtonGlow() end },
          fallbackConjure = { type="toggle", name="Fallback conjure", desc="If insufficient stacks, click casts Conjure Water/Food instead of placing.", get=function() return ThirstTrap.db.profile.fallbackConjure end, set=function(_,v) ThirstTrap.db.profile.fallbackConjure = v ThirstTrap:UpdateTradeButtonGlow() end },
          prefer = { type="select", name="Prefer", values={ water="Water", food="Food" }, get=function() return ThirstTrap.db.profile.prefer end, set=function(_,v) ThirstTrap.db.profile.prefer = v ThirstTrap:UpdateTradeButtonIcon() end },
        }
      },
      PerClass = {
        type = "group", name = "Per Class", order = 2,
        args = perClassArgs,
      },
      BG_Arena = {
        type = "group", name = "BG/Arena", order = 3,
        args = {
          enabled = { type="toggle", name="Enable override", get=function() return ThirstTrap.db.profile.bgArenaOverride.enabled end, set=function(_,v) ThirstTrap.db.profile.bgArenaOverride.enabled = v end },
          water   = { type="range",  name="Water stacks", min=0, max=6, step=1, get=function() return ThirstTrap.db.profile.bgArenaOverride.water end, set=function(_,v) ThirstTrap.db.profile.bgArenaOverride.water = v end },
          food    = { type="range",  name="Food stacks",  min=0, max=6, step=1, get=function() return ThirstTrap.db.profile.bgArenaOverride.food end, set=function(_,v) ThirstTrap.db.profile.bgArenaOverride.food = v end },
        }
      },
      Statistics = {
        type = "group", name = "Statistics", order = 4,
        args = {
          lifetimeWater = { type="description", name=function() return string.format("Lifetime water: %d", ThirstTrap.stats.lifetime.water or 0) end },
          lifetimeFood  = { type="description", name=function() return string.format("Lifetime food: %d", ThirstTrap.stats.lifetime.food or 0) end },
          lifetimeStone = { type="description", name=function() return string.format("Lifetime stones: %d", ThirstTrap.stats.lifetime.stone or 0) end },
          dailyWater    = { type="description", name=function() return string.format("Today water: %d", ThirstTrap.stats.daily.water or 0) end },
          dailyFood     = { type="description", name=function() return string.format("Today food: %d", ThirstTrap.stats.daily.food or 0) end },
          dailyStone    = { type="description", name=function() return string.format("Today stones: %d", ThirstTrap.stats.daily.stone or 0) end },
        }
      },
    }
  }
  return options
end
