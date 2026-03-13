---@diagnostic disable: undefined-global
local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.Other = LI.Other or {}

function LI.Other.BuildTab(otherPanel, env)
  if not otherPanel then return end

  -- Other-tab UI was relocated:
  -- - Achievement/Experience/Professions toggles + output dropdowns now live at the bottom of the LootIt tab.
  -- - Format examples moved into the LootIt tab Info popout.
  -- Keep this tab intentionally empty.
  otherPanel.Refresh = function() end
end
