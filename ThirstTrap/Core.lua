local ADDON_NAME = ...
local ThirstTrap = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LibDBIcon = LibStub("LibDBIcon-1.0")
local LDB = LibStub("LibDataBroker-1.1", true)
local LBG = LibStub("LibButtonGlow-1.0", true)

local MAX_TRADE_STACKS = 6
local ShouldConjure -- forward declaration for secure-click logic

-- Container API compatibility (Classic uses C_Container)
local function BagNumSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag)
  end
  return GetContainerNumSlots(bag)
end

local function BagItemID(bag, slot)
  if C_Container and C_Container.GetContainerItemID then
    return C_Container.GetContainerItemID(bag, slot)
  end
  return GetContainerItemID(bag, slot)
end

local function BagItemCount(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    return info and info.stackCount or nil
  end
  local _, count = GetContainerItemInfo(bag, slot)
  return count
end

local function PickupBagItem(bag, slot)
  if C_Container and C_Container.PickupContainerItem then
    return C_Container.PickupContainerItem(bag, slot)
  end
  return PickupContainerItem(bag, slot)
end

ThirstTrap.defaults = {
  profile = {
    auto = true,
    minimap = { hide = false },
    fallbackConjure = true,
    position = { point = "LEFT", relativePoint = "RIGHT", x = 8, y = -28 },
    perClass = {
      WARRIOR = { water = 0, food = 4 },
      PALADIN = { water = 3, food = 1 },
      HUNTER  = { water = 3, food = 1 },
      ROGUE   = { water = 0, food = 4 },
      PRIEST  = { water = 4, food = 0 },
      SHAMAN  = { water = 3, food = 1 },
      MAGE    = { water = 6, food = 0 },
      WARLOCK = { water = 4, food = 0 },
      DRUID   = { water = 3, food = 1 },
    },
    bgArenaOverride = { enabled = false, water = 2, food = 0 },
    prefer = "water", -- or "food"
  }
}

ThirstTrap.requestOverride = { water = nil, food = nil, prefer = nil }
ThirstTrap.stats = {
  lifetime = { water = 0, food = 0, stone = 0 },
  daily = { date = nil, water = 0, food = 0, stone = 0 }
}

local inv = {
  water = { itemID = nil, stacks = 0, total = 0 },
  food  = { itemID = nil, stacks = 0, total = 0 },
  stone = { itemID = nil, stacks = 0, total = 0 },
}

local TRADE_BTN
local function IsMage()
  local _, class = UnitClass("player")
  return class == "MAGE"
end

local function IsWarlock()
  local _, class = UnitClass("player")
  return class == "WARLOCK"
end

local function InBGOrArena()
  local inInstance, instanceType = IsInInstance()
  return inInstance and (instanceType == "pvp" or instanceType == "arena")
end

local function Clamp(n, min, max)
  if n < min then return min end
  if n > max then return max end
  return n
end

local function GetTradePartnerName()
  if TradeFrame and TradeFrame:IsShown() and TradeFrameRecipientNameText then
    return TradeFrameRecipientNameText:GetText()
  end
end

local function GetTradePartnerClass()
  local name = GetTradePartnerName()
  if not name then return nil end
  -- Best-effort: try target, else nil
  if UnitName("target") == name then
    local _, class = UnitClass("target")
    return class
  end
  return nil
end

function ThirstTrap:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("ThirstTrapDB", self.defaults, true)
  ThirstTrapStats = ThirstTrapStats or { lifetime = { water = 0, food = 0 }, daily = { date = nil, water = 0, food = 0 } }
  self.stats = ThirstTrapStats
  self:EnsureDailyDate()

  AceConfig:RegisterOptionsTable(ADDON_NAME, self:GetOptions())
  self.configDialog = AceConfigDialog

  local ldbObj
  if LDB then
    ldbObj = LDB:NewDataObject(ADDON_NAME, {
      type = "launcher",
      icon = 132795,
      OnClick = function(frame, button)
        if button == "LeftButton" then
          self:OpenConfig()
        else
          self.db.profile.auto = not self.db.profile.auto
          self:UpdateTradeButtonGlow()
          self:Print("Auto trade: " .. (self.db.profile.auto and "ON" or "OFF"))
        end
      end,
      OnTooltipShow = function(tt)
        tt:AddLine(ADDON_NAME)
        tt:AddLine("Left: Config\nRight: Toggle Auto", 1,1,1)
      end,
    })
  end
  LibDBIcon:Register(ADDON_NAME, ldbObj or { icon = 132795 }, self.db.profile.minimap)

  self:RegisterEvent("PLAYER_LOGIN", "OnLogin")
  self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagUpdate")
  self:RegisterEvent("TRADE_SHOW", "OnTradeShow")
  self:RegisterEvent("TRADE_CLOSED", "OnTradeClosed")
  self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
end

function ThirstTrap:OnEnable()
  self:ScanInventory()
end

function ThirstTrap:OpenConfig()
  self.configDialog:Open(ADDON_NAME)
end

function ThirstTrap:EnsureDailyDate()
  local today = date("%Y-%m-%d")
  if self.stats.daily.date ~= today then
    self.stats.daily.date = today
    self.stats.daily.water = 0
    self.stats.daily.food = 0
    self.stats.daily.stone = 0
  end
end

function ThirstTrap:OnLogin()
  self:CreateTradeButton()
  self:ScanInventory()
end

function ThirstTrap:OnBagUpdate()
  self:ScanInventory()
  self:UpdateTradeButtonIcon()
  self:UpdateTradeButtonGlow()
end

function ThirstTrap:OnTradeShow()
  -- Ensure the button exists once TradeFrame is actually loaded
  self:CreateTradeButton()
  if TRADE_BTN then TRADE_BTN:Show() end
  self:UpdateTradeButtonState()
  self:UpdateTradeButtonGlow()
end

function ThirstTrap:OnTradeClosed()
  self.requestOverride.water = nil
  self.requestOverride.food = nil
  self.requestOverride.prefer = nil
  if TRADE_BTN then TRADE_BTN:Hide() end
end

function ThirstTrap:OnWhisper(msg, sender)
  -- Parse simple overrides
  local stacks = tonumber(msg:match("(%d+)%s*stack")) or tonumber(msg:match("(%d+)%s*stacks"))
  local waterOnly = msg:lower():match("water%W+only") or msg:lower():match("^water$") or msg:lower():match("water pls")
  local foodOnly = msg:lower():match("food%W+only") or msg:lower():match("^food$") or msg:lower():match("food pls")
  local stoneReq = msg:lower():match("healthstone") or msg:lower():match("%f[%a]hs%f[%A]")

  if stacks then
    self.requestOverride.water = stacks
    self.requestOverride.food = 0
  end
  if waterOnly then
    self.requestOverride.prefer = "water"
    self.requestOverride.food = 0
  elseif foodOnly then
    self.requestOverride.prefer = "food"
    self.requestOverride.water = 0
  end
  if stoneReq then
    self.requestOverride.prefer = "stone"
  end

  self:UpdateTradeButtonGlow()
end

function ThirstTrap:UpdateTradeButtonGlow()
  if not TRADE_BTN then return end
  local needConjure = false
  if IsMage() then
    local targetClass = GetTradePartnerClass()
    local prefer, waterAmt, foodAmt = self:GetConfiguredAmounts(targetClass)
    local bagStacks = self:GetBagStacks()
    needConjure = self:NeedsConjure(prefer, waterAmt, foodAmt, bagStacks)
  elseif IsWarlock() then
    needConjure = self:NeedsConjureWarlock()
  end
  if self.db.profile.fallbackConjure and needConjure then
    if LBG then LBG.ShowOverlayGlow(TRADE_BTN) else TRADE_BTN.border:SetVertexColor(1, 0.3, 0.3) end
  else
    if LBG then LBG.HideOverlayGlow(TRADE_BTN) end
    if self.db.profile.auto or self.requestOverride.prefer then
      TRADE_BTN.border:SetVertexColor(0, 1, 1)
    else
      TRADE_BTN.border:SetVertexColor(1, 1, 1)
    end
  end
end
  TRADE_BTN:SetScript("PreClick", function(btn, mouseButton)
    -- All protected actions must happen here during the secure click
    if mouseButton ~= "LeftButton" then
      btn:SetAttribute("type", nil)
      btn:SetAttribute("spell", nil)
      return
    end
    if not (IsMage() or IsWarlock()) then
      btn:SetAttribute("type", nil)
      btn:SetAttribute("spell", nil)
      return
    end
    if IsMage() then
      local targetClass = GetTradePartnerClass()
      local prefer, waterAmt, foodAmt = ThirstTrap:GetConfiguredAmounts(targetClass)
      local bagStacks = ThirstTrap:GetBagStacks()
      local needConjure, needKind = ShouldConjure(prefer, waterAmt, foodAmt, bagStacks)
      if ThirstTrap.db.profile.fallbackConjure and needConjure then
        local spell = ThirstTrap:GetConjureSpell(needKind)
        if spell then
          btn:SetAttribute("type", "spell")
          btn:SetAttribute("spell", spell)
          return
        end
      end
      -- Place stacks directly during the secure click
      local toPlace = {}
      if prefer == "water" then
        for i=1, waterAmt do toPlace[#toPlace+1] = "water" end
        for i=1, foodAmt  do toPlace[#toPlace+1] = "food" end
      else
        for i=1, foodAmt  do toPlace[#toPlace+1] = "food" end
        for i=1, waterAmt do toPlace[#toPlace+1] = "water" end
      end
      if #toPlace > MAX_TRADE_STACKS then
        while #toPlace > MAX_TRADE_STACKS do table.remove(toPlace) end
      end
      local placed = 0
      for idx=1, #toPlace do
        if placed >= MAX_TRADE_STACKS then break end
        local kind = toPlace[idx]
        local stacks = bagStacks[kind]
        local entry = stacks and stacks[1]
        if entry then
          ClearCursor()
          PickupBagItem(entry.bag, entry.slot)
          local tradeBtn = _G["TradePlayerItem"..(placed+1).."ItemButton"]
          if tradeBtn then tradeBtn:Click() end
          ClearCursor()
          table.remove(stacks, 1)
          placed = placed + 1
          ThirstTrap:IncrementStats(kind, entry.count or 1)
        end
      end
    elseif IsWarlock() then
      local needConjure = ThirstTrap:NeedsConjureWarlock()
      if ThirstTrap.db.profile.fallbackConjure and needConjure then
        local spell = ThirstTrap:GetConjureStoneSpell()
        if spell then
          btn:SetAttribute("type", "spell")
          btn:SetAttribute("spell", spell)
          return
        end
      end
      -- Warlock: place one healthstone if available
      local stacks = ThirstTrap:GetBagStacks().stone
      local entry = stacks and stacks[1]
      if entry then
        ClearCursor()
        PickupBagItem(entry.bag, entry.slot)
        local tradeBtn = _G["TradePlayerItem1ItemButton"]
        if tradeBtn then tradeBtn:Click() end
        ClearCursor()
        ThirstTrap:IncrementStats("stone", entry.count or 1)
      end
    end
    btn:SetAttribute("type", nil)
    btn:SetAttribute("spell", nil)
  end)

  TRADE_BTN:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ADDON_NAME)
    GameTooltip:AddLine("Left-click: place configured stacks", 1,1,1)
    GameTooltip:AddLine("Right-click: open config", 1,1,1)
    local needLine = ThirstTrap:GetNeedsTooltipLine()
    if needLine then
      GameTooltip:AddLine(needLine, 1,0.8,0.8)
    end
    GameTooltip:Show()
  end)
  TRADE_BTN:SetScript("OnLeave", function() GameTooltip:Hide() end)

  TRADE_BTN:SetScript("OnClick", function(btn, mouseButton)
    if mouseButton == "RightButton" then
      ThirstTrap:OpenConfig()
    end
    -- All placement happens in PreClick; OnClick only handles right-click config
  end)

  self:UpdateTradeButtonIcon()
  self:UpdateTradeButtonState()
  self:UpdateTradeButtonGlow()
end

function ThirstTrap:UpdateTradeButtonPosition()
  if not TRADE_BTN or not TradeFrame then return end
  local pos = self.db and self.db.profile and self.db.profile.position or { point = "LEFT", relativePoint = "RIGHT", x = 8, y = -28 }
  TRADE_BTN:ClearAllPoints()
  TRADE_BTN:SetPoint(pos.point or "LEFT", TradeFrame, pos.relativePoint or "RIGHT", pos.x or 8, pos.y or -28)
end

function ThirstTrap:UpdateTradeButtonState()
  if not TRADE_BTN then return end
  local enabled = (IsMage() or IsWarlock())
  TRADE_BTN:SetEnabled(enabled)
  TRADE_BTN:SetAlpha(enabled and 1 or 0.4)
end

function ThirstTrap:GetConfiguredAmounts(targetClass)
  local p = self.db.profile
  local cfg = p.perClass[targetClass or "MAGE"] or { water = 0, food = 0 }
  if InBGOrArena() and p.bgArenaOverride.enabled then
    cfg = { water = p.bgArenaOverride.water or 0, food = p.bgArenaOverride.food or 0 }
  end
  local prefer = self.requestOverride.prefer or p.prefer
  local water = self.requestOverride.water ~= nil and self.requestOverride.water or cfg.water
  local food  = self.requestOverride.food  ~= nil and self.requestOverride.food  or cfg.food
  return prefer, Clamp(water, 0, MAX_TRADE_STACKS), Clamp(food, 0, MAX_TRADE_STACKS)
end

function ThirstTrap:NeedsConjure(prefer, waterAmt, foodAmt, bagStacks)
  local waterStacks = (bagStacks.water and #bagStacks.water or 0)
  local foodStacks  = (bagStacks.food  and #bagStacks.food  or 0)
  local needWater = waterAmt > waterStacks
  local needFood  = foodAmt  > foodStacks
  if needWater then return true, "water" end
  if needFood then return true, "food" end
  return false, nil
end

ShouldConjure = function(prefer, waterAmt, foodAmt, bagStacks)
  local waterStacks = (bagStacks.water and #bagStacks.water or 0)
  local foodStacks  = (bagStacks.food  and #bagStacks.food  or 0)
  if waterAmt > waterStacks and waterStacks == 0 then return true, "water" end
  if foodAmt  > foodStacks  and foodStacks  == 0 then return true, "food" end
  return false, nil
end

function ThirstTrap:GetConjureSpell(kind)
  local lists = ThirstTrapItems and ThirstTrapItems.spells and ThirstTrapItems.spells.mage
  if kind == "water" and lists and lists.conjureWater then
    for i=1,#lists.conjureWater do
      local name = GetSpellInfo(lists.conjureWater[i])
      if name then return name end
    end
    return GetSpellInfo("Conjure Water")
  elseif kind == "food" and lists and lists.conjureFood then
    for i=1,#lists.conjureFood do
      local name = GetSpellInfo(lists.conjureFood[i])
      if name then return name end
    end
    return GetSpellInfo("Conjure Food")
  end
end

function ThirstTrap:GetNeedsTooltipLine()
  if IsWarlock() then
    if (inv.stone.stacks or 0) == 0 then
      return "Needs: Healthstone"
    else
      return nil
    end
  end
  if IsMage() then
    local targetClass = GetTradePartnerClass()
    local prefer, waterAmt, foodAmt = self:GetConfiguredAmounts(targetClass)
    local bagStacks = self:GetBagStacks()
    local waterStacks = (bagStacks.water and #bagStacks.water or 0)
    local foodStacks  = (bagStacks.food  and #bagStacks.food  or 0)
    local needWater = math.max(0, waterAmt - waterStacks)
    local needFood  = math.max(0, foodAmt  - foodStacks)
    if needWater > 0 or needFood > 0 then
      return string.format("Needs: %d water%s%s", needWater, (needFood>0 and " / " .. needFood .. " food" or ""), "")
    end
  end
  return nil
end

local function TradeSlotButton(slot)
  return _G["TradePlayerItem"..slot.."ItemButton"]
end

local function PlaceStackFromBagToTrade(bag, slot, tradeSlot)
  ClearCursor()
  PickupBagItem(bag, slot)
  local btn = TradeSlotButton(tradeSlot)
  if btn then
    btn:Click()
  else
    if ThirstTrap.db and ThirstTrap.db.profile and ThirstTrap.db.profile.debug then
      ThirstTrap:Print("Trade slot button missing for slot "..tostring(tradeSlot))
    end
  end
  ClearCursor()
end

function ThirstTrap:ExecuteTrade()
  local targetClass = GetTradePartnerClass()
  local prefer, waterAmt, foodAmt = self:GetConfiguredAmounts(targetClass)

  local toPlace = {}
  if prefer == "water" then
    for i=1, waterAmt do toPlace[#toPlace+1] = "water" end
    for i=1, foodAmt  do toPlace[#toPlace+1] = "food" end
  else
    for i=1, foodAmt  do toPlace[#toPlace+1] = "food" end
    for i=1, waterAmt do toPlace[#toPlace+1] = "water" end
  end
  if #toPlace > MAX_TRADE_STACKS then
    while #toPlace > MAX_TRADE_STACKS do table.remove(toPlace) end
  end

  local bagStacks = self:GetBagStacks()
  local placed = 0
  for idx=1, #toPlace do
    if placed >= MAX_TRADE_STACKS then break end
    local kind = toPlace[idx]
    local stacks = bagStacks[kind]
    local entry = stacks and stacks[1]
    if entry then
      PlaceStackFromBagToTrade(entry.bag, entry.slot, placed+1)
      table.remove(stacks, 1)
      placed = placed + 1
      self:IncrementStats(kind, entry.count)
    end
  end

  if placed == 0 then
    local who = GetTradePartnerName() or "friend"
    self:Print("No stacks available to trade.")
    SendChatMessage("Need to conjure more "..(prefer or "water")..", one moment.", "WHISPER", nil, who)
  end
end

function ThirstTrap:IncrementStats(kind, count)
  if kind == "water" then
    self.stats.lifetime.water = (self.stats.lifetime.water or 0) + count
    self.stats.daily.water = (self.stats.daily.water or 0) + count
  elseif kind == "food" then
    self.stats.lifetime.food = (self.stats.lifetime.food or 0) + count
    self.stats.daily.food = (self.stats.daily.food or 0) + count
  elseif kind == "stone" then
    self.stats.lifetime.stone = (self.stats.lifetime.stone or 0) + count
    self.stats.daily.stone = (self.stats.daily.stone or 0) + count
  end
end

function ThirstTrap:UpdateTradeButtonIcon()
  if not TRADE_BTN then return end
  local icon
  if IsWarlock() then
    icon = (inv.stone.itemID and (GetItemIcon and GetItemIcon(inv.stone.itemID))) or select(10, GetItemInfo(inv.stone.itemID)) or nil
  else
    icon = (inv.water.itemID and (GetItemIcon and GetItemIcon(inv.water.itemID))) or select(10, GetItemInfo(inv.water.itemID)) or nil
    if self.db.profile.prefer == "food" then
      icon = (inv.food.itemID and (GetItemIcon and GetItemIcon(inv.food.itemID))) or select(10, GetItemInfo(inv.food.itemID)) or icon
    else
      icon = (inv.water.itemID and (GetItemIcon and GetItemIcon(inv.water.itemID))) or select(10, GetItemInfo(inv.water.itemID)) or icon
    end
  end
  if icon then
    TRADE_BTN.icon:SetTexture(icon)
  else
    if IsWarlock() then
      TRADE_BTN.icon:SetTexture(135230) -- healthstone icon fallback
    else
      TRADE_BTN.icon:SetTexture(134400) -- bread icon fallback
    end
  end
end

function ThirstTrap:GetBagStacks()
  local stacks = { water = {}, food = {}, stone = {} }
  for bag=0, NUM_BAG_SLOTS do
    for slot=1, BagNumSlots(bag) do
      local itemID = BagItemID(bag, slot)
      if itemID then
        local count = BagItemCount(bag, slot)
        if ThirstTrapItems:IsWater(itemID) then
          table.insert(stacks.water, { bag=bag, slot=slot, count=count or 20 })
        elseif ThirstTrapItems:IsFood(itemID) then
          table.insert(stacks.food, { bag=bag, slot=slot, count=count or 20 })
        elseif ThirstTrapItems:IsStone(itemID) then
          table.insert(stacks.stone, { bag=bag, slot=slot, count=count or 1 })
        end
      end
    end
  end
  table.sort(stacks.water, function(a,b) return a.count > b.count end)
  table.sort(stacks.food,  function(a,b) return a.count > b.count end)
  table.sort(stacks.stone, function(a,b) return a.count > b.count end)
  return stacks
end

function ThirstTrap:ScanInventory()
  inv.water.itemID, inv.water.stacks, inv.water.total = nil, 0, 0
  inv.food.itemID,  inv.food.stacks,  inv.food.total  = nil, 0, 0
  inv.stone.itemID, inv.stone.stacks, inv.stone.total = nil, 0, 0

  local bestWaterCount, bestWaterID = 0, nil
  local bestFoodCount, bestFoodID = 0, nil
  local bestStoneCount, bestStoneID = 0, nil

  for bag=0, NUM_BAG_SLOTS do
    for slot=1, BagNumSlots(bag) do
      local itemID = BagItemID(bag, slot)
      if itemID then
        local count = BagItemCount(bag, slot)
        if ThirstTrapItems:IsWater(itemID) then
          inv.water.total = inv.water.total + (count or 0)
          inv.water.stacks = inv.water.stacks + 1
          if (count or 0) > bestWaterCount then
            bestWaterCount = count or 0
            bestWaterID = itemID
          end
        elseif ThirstTrapItems:IsFood(itemID) then
          inv.food.total = inv.food.total + (count or 0)
          inv.food.stacks = inv.food.stacks + 1
          if (count or 0) > bestFoodCount then
            bestFoodCount = count or 0
            bestFoodID = itemID
          end
        elseif ThirstTrapItems:IsStone(itemID) then
          inv.stone.total = inv.stone.total + (count or 0)
          inv.stone.stacks = inv.stone.stacks + 1
          if (count or 0) > bestStoneCount then
            bestStoneCount = count or 0
            bestStoneID = itemID
          end
        end
      end
    end
  end
  inv.water.itemID = bestWaterID
  inv.food.itemID = bestFoodID
  inv.stone.itemID = bestStoneID

  self:UpdateTradeButtonState()
  self:UpdateTradeButtonIcon()
end

-- Name-based detection removed; all detection uses itemIDs via ThirstTrapItems.

function ThirstTrap:NeedsConjureWarlock()
  return (inv.stone.stacks or 0) == 0
end

function ThirstTrap:GetConjureStoneSpell()
  local lists = ThirstTrapItems and ThirstTrapItems.spells and ThirstTrapItems.spells.warlock
  local candidates = lists and lists.createHealthstone
  if candidates then
    for i=1,#candidates do
      local name = GetSpellInfo(candidates[i])
      if name then return name end
    end
  end
end

function ThirstTrap:ExecuteTradeWarlock()
  local stacks = self:GetBagStacks().stone
  local entry = stacks and stacks[1]
  if entry then
    PlaceStackFromBagToTrade(entry.bag, entry.slot, 1)
    self:IncrementStats("stone", entry.count or 1)
  else
    local who = GetTradePartnerName() or "friend"
    self:Print("No healthstone available.")
    SendChatMessage("Need to create a healthstone, one moment.", "WHISPER", nil, who)
  end
end
