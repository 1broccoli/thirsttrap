-- Classic item database (locale-safe via itemIDs)
ThirstTrapItems = {
  water = {
    5350,
    2288,
    2136,
    3772,
    8077,
    8078,
    8079,
  },
  food = {
    5349,
    1113,
    1114,
    1487,
    8075,
    8076,
  },
  stone = {
    5512,
    5511,
    5509,
    5510,
    9421,
  },
}
local function buildSet(list)
  local s = {}
  for i=1,#list do s[list[i]] = true end
  return s
end
ThirstTrapItems.waterSet = buildSet(ThirstTrapItems.water)
ThirstTrapItems.foodSet  = buildSet(ThirstTrapItems.food)
ThirstTrapItems.stoneSet = buildSet(ThirstTrapItems.stone)
function ThirstTrapItems:IsWater(itemID) return itemID and self.waterSet[itemID] or false end
function ThirstTrapItems:IsFood(itemID)  return itemID and self.foodSet[itemID]  or false end
function ThirstTrapItems:IsStone(itemID) return itemID and self.stoneSet[itemID] or false end

-- Spell IDs (Classic) with annotations
ThirstTrapItems.spells = {
  mage = {
    conjureWater = {
      10140, -- Conjure Water (Rank 7)
      10139, -- Conjure Water (Rank 6)
      10138, -- Conjure Water (Rank 5)
      6127,  -- Conjure Water (Rank 4)
      5506,  -- Conjure Water (Rank 3)
      5505,  -- Conjure Water (Rank 2)
      5504,  -- Conjure Water (Rank 1)
    },
    conjureFood = {
      10145, -- Conjure Food (Rank 6)
      10144, -- Conjure Food (Rank 5)
      6129,  -- Conjure Food (Rank 4)
      990,   -- Conjure Food (Rank 3)
      597,   -- Conjure Food (Rank 2)
      587,   -- Conjure Food (Rank 1)
    },
  },
  warlock = {
    createHealthstone = {
      11729, -- Create Major Healthstone
      11728, -- Create Greater Healthstone
      5699,  -- Create Healthstone
      6202,  -- Create Lesser Healthstone
      6201,  -- Create Minor Healthstone
    },
  },
}
