local ADDON_NAME = ...
local ThirstTrap = _G[ADDON_NAME]

function ThirstTrap:ToggleMinimapIcon(show)
  local LibDBIcon = LibStub("LibDBIcon-1.0")
  self.db.profile.minimap.hide = not show
  if show then LibDBIcon:Show(ADDON_NAME) else LibDBIcon:Hide(ADDON_NAME) end
end
