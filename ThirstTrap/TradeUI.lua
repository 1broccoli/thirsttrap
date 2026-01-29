local ADDON_NAME = ...
local ThirstTrap = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local MAX_TRADABLE_ITEMS = 6

local function IsMage()
  local _, class = UnitClass("player")
  return class == "MAGE"
end

local function IsWarlock()
  local _, class = UnitClass("player")
  return class == "WARLOCK"
end

local function ClearTradeWindow()
  for i=1, MAX_TRADABLE_ITEMS do
    ClearCursor()
    ClickTradeButton(i)
  end
  ClearCursor()
end

local function PlaceStack(bag, slot, index)
  ClearCursor()
  if C_Container and C_Container.PickupContainerItem then
    C_Container.PickupContainerItem(bag, slot)
  else
    PickupContainerItem(bag, slot)
  end
  local btn = _G["TradePlayerItem"..index.."ItemButton"]
  if btn then btn:Click() end
  ClearCursor()
end

function ThirstTrap:CreateTradePanel()
  if self.tradePanel then return self.tradePanel end

  local panel = CreateFrame("Frame", ADDON_NAME.."TradePanel", UIParent)
  panel:SetSize(160, 160)
  panel:SetFrameStrata("HIGH")
  panel:Hide()

  local function addButton(name, text, onClick, iconTexture)
    local btn = CreateFrame("Button", ADDON_NAME..name, panel, "UIPanelButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    if iconTexture then
      local t = btn:CreateTexture(nil, "ARTWORK")
      t:SetSize(18,18)
      t:SetPoint("LEFT", btn, "LEFT", 6, 0)
      t:SetTexture(iconTexture)
      btn.Icon = t
      btn:GetFontString():SetPoint("LEFT", t, "RIGHT", 6, 0)
    end
    return btn
  end

  local function addSpellButton(name)
    local btn = CreateFrame("Button", ADDON_NAME..name, panel, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    btn:SetSize(140, 22)
    btn:SetAttribute("type", "spell")
    btn:Hide()
    return btn
  end

  panel.clearBtn = addButton("ClearBtn", "Clear", function()
    if InCombatLockdown() then return end
    ClearTradeWindow()
  end, "Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  panel.clearBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)

  panel.fillBtn = addButton("FillBtn", "Fill", function()
    if InCombatLockdown() then return end
    -- Replacement method: always clear then place up to 6 waters
    ClearTradeWindow()
    local stacks = ThirstTrap:GetBagStacks().water
    local placed = 0
    for i=1, MAX_TRADABLE_ITEMS do
      if placed >= MAX_TRADABLE_ITEMS then break end
      local entry = stacks and stacks[1]
      if not entry then break end
      PlaceStack(entry.bag, entry.slot, placed+1)
      table.remove(stacks, 1)
      placed = placed + 1
    end
  end, "Interface\\ICONS\\INV_Drink_18")
  panel.fillBtn:SetPoint("TOPLEFT", panel.clearBtn, "BOTTOMLEFT", 0, -6)

  panel.configBtn = addButton("ConfigBtn", "Config", function()
    ThirstTrap:OpenConfig()
  end)
  panel.configBtn:SetPoint("TOPLEFT", panel.fillBtn, "BOTTOMLEFT", 0, -6)

  panel.acceptBtn = addButton("AcceptBtn", "Accept trade", function()
    if InCombatLockdown() then return end
    if AcceptTrade then
      AcceptTrade()
    elseif TradeFrameTradeButton then
      TradeFrameTradeButton:Click()
    end
  end)
  panel.acceptBtn:SetPoint("TOPLEFT", panel.configBtn, "BOTTOMLEFT", 0, -8)

  panel.spellWaterBtn = addSpellButton("SpellWaterBtn")
  panel.spellWaterBtn:SetPoint("TOPLEFT", panel.acceptBtn, "BOTTOMLEFT", 0, -8)

  panel.spellFoodBtn = addSpellButton("SpellFoodBtn")
  panel.spellFoodBtn:SetPoint("TOPLEFT", panel.spellWaterBtn, "BOTTOMLEFT", 0, -2)

  panel.spellStoneBtn = addSpellButton("SpellStoneBtn")
  panel.spellStoneBtn:SetPoint("TOPLEFT", panel.spellFoodBtn, "BOTTOMLEFT", 0, -2)

  self.tradePanel = panel
  return panel
end

function ThirstTrap:UpdateTradePanelSpells()
  local panel = self.tradePanel or self:CreateTradePanel()
  if not panel then return end

  panel.spellWaterBtn:Hide()
  panel.spellFoodBtn:Hide()
  panel.spellStoneBtn:Hide()

  if IsMage() then
    local w = self:GetConjureSpell("water")
    local f = self:GetConjureSpell("food")
    if w then
      panel.spellWaterBtn:SetAttribute("spell", w)
      panel.spellWaterBtn:SetText(w)
      panel.spellWaterBtn:SetScript("PreClick", function(btn, mouseButton)
        if mouseButton ~= "LeftButton" then btn:SetAttribute("type", nil); btn:SetAttribute("spell", nil); return end
        if ThirstTrap.db and ThirstTrap.db.profile and ThirstTrap.db.profile.quick then
          btn:SetAttribute("type", "spell"); btn:SetAttribute("spell", w); return
        end
        local targetClass = (TradeFrame and TradeFrame:IsShown()) and select(2, UnitClass("target")) or nil
        local _, waterAmt, _ = ThirstTrap:GetConfiguredAmounts(targetClass)
        local stacks = ThirstTrap:GetBagStacks().water
        local have = stacks and #stacks or 0
        if have >= (waterAmt or 0) and waterAmt > 0 then
          local placed = 0
          for i=1, waterAmt do
            if placed >= MAX_TRADABLE_ITEMS then break end
            local entry = stacks[1]; if not entry then break end
            PlaceStack(entry.bag, entry.slot, placed+1)
            table.remove(stacks, 1)
            placed = placed + 1
          end
          btn:SetAttribute("type", nil); btn:SetAttribute("spell", nil); return
        else
          btn:SetAttribute("type", "spell"); btn:SetAttribute("spell", w); return
        end
      end)
      panel.spellWaterBtn:Show()
    end
    if f then
      panel.spellFoodBtn:SetAttribute("spell", f)
      panel.spellFoodBtn:SetText(f)
      panel.spellFoodBtn:SetScript("PreClick", function(btn, mouseButton)
        if mouseButton ~= "LeftButton" then btn:SetAttribute("type", nil); btn:SetAttribute("spell", nil); return end
        if ThirstTrap.db and ThirstTrap.db.profile and ThirstTrap.db.profile.quick then
          btn:SetAttribute("type", "spell"); btn:SetAttribute("spell", f); return
        end
        local targetClass = (TradeFrame and TradeFrame:IsShown()) and select(2, UnitClass("target")) or nil
        local _, _, foodAmt = ThirstTrap:GetConfiguredAmounts(targetClass)
        local stacks = ThirstTrap:GetBagStacks().food
        local have = stacks and #stacks or 0
        if have >= (foodAmt or 0) and foodAmt > 0 then
          local placed = 0
          for i=1, foodAmt do
            if placed >= MAX_TRADABLE_ITEMS then break end
            local entry = stacks[1]; if not entry then break end
            PlaceStack(entry.bag, entry.slot, placed+1)
            table.remove(stacks, 1)
            placed = placed + 1
          end
          btn:SetAttribute("type", nil); btn:SetAttribute("spell", nil); return
        else
          btn:SetAttribute("type", "spell"); btn:SetAttribute("spell", f); return
        end
      end)
      panel.spellFoodBtn:Show()
    end
  elseif IsWarlock() then
    local s = self:GetConjureStoneSpell()
    if s then
      panel.spellStoneBtn:SetAttribute("spell", s)
      panel.spellStoneBtn:SetText(s)
      panel.spellStoneBtn:Show()
    end
  end
end

function ThirstTrap:ShowTradePanel()
  local panel = self.tradePanel or self:CreateTradePanel()
  if not TradeFrame then return end
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", 6, -10)
  self:UpdateTradePanelSpells()
  panel:Show()
end

function ThirstTrap:HideTradePanel()
  if self.tradePanel then self.tradePanel:Hide() end
end
