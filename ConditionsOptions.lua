local _, ns = ...
local L = ns.L

-- The "Where buffs show" window (Conditions.lua has the rules): opened from "Where the row shows" above the tracked
-- list (the whole row) and from each tracked buff's "Where" button (that buff: its own rules, or the row's).
-- Where / Talents (dual spec) / Group / Role (group roles): tick what to show in; Combat: one of three. A buff
-- following the row shows the row's choices greyed.

local WIDTH, HEIGHT = 420, 318
local TALENTS_HEIGHT = 62 -- the Talents section, where the game has dual spec
local ROLES_HEIGHT = 96 -- the Role section (group roles), under Group
local window

local function Hide()
  GameTooltip:Hide()
end

local function Target()
  return window and window.target
end

local function Conditions()
  local target = Target()
  if target == "row" then
    return ns.db.conditions
  end
  return ns.EntryConditions(target)
end

local function Editable()
  local target = Target()
  return target == "row" or (type(target) == "table" and target.conditions ~= nil)
end

local function MakeCheck(parent, label, onClick)
  local check = ns.T.Check(parent, label, "GameFontHighlightSmall")
  check:SetHitRectInsets(0, -(check.Text:GetStringWidth() + 4), 0, 0)
  check:SetScript("OnClick", onClick)
  return check
end

local function Build()
  window = CreateFrame("Frame", "BuffTrackerConditions", UIParent)
  window:SetSize(WIDTH, HEIGHT + (ns.HasTalentGroups() and TALENTS_HEIGHT or 0) + (ns.HasRoles() and ROLES_HEIGHT or 0))
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  ns.T.Stone(window)
  window.title = ns.T.TitleBar(window, L["Where buffs show"])
  local close = ns.T.CloseButton(window)
  close:SetPoint("TOPRIGHT", -6, -6)
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "BuffTrackerConditions")
  end

  -- the buff's name (or "The whole row"), in normal case under the title band
  window.name = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  window.name:SetPoint("TOPLEFT", 16, -42)
  window.name:SetPoint("RIGHT", -16, 0)
  window.name:SetJustifyH("LEFT")

  window.own = MakeCheck(window, L["Its own rules (unticked: the same as the whole row)"], function(self)
    if type(Target()) == "table" then
      ns.SetOwnConditions(Target(), self:GetChecked() and true or false)
    end
  end)
  window.own:SetPoint("TOPLEFT", 12, -60)

  local left = ns.T.Heading(window, L["Where"], 180)
  left:SetPoint("TOPLEFT", 16, -90)
  window.places = {}
  local last = left
  for _, place in ipairs(ns.PLACES) do
    local check = MakeCheck(window, place.label, function(self)
      ns.SetCondition(Target(), "place", place.key, self:GetChecked() and true or false)
    end)
    check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, last == left and -4 or 2)
    check.key = place.key
    window.places[#window.places + 1] = check
    last = check
  end

  -- dual spec (Conditions.lua ns.TALENTS), under Where; only where the game has two talent groups
  window.talents = {}
  if ns.HasTalentGroups() then
    local talents = ns.T.Heading(window, L["Talents"], 180)
    talents:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -10)
    last = talents
    for _, choice in ipairs(ns.TALENTS) do
      local check = MakeCheck(window, choice.label, function(self)
        ns.SetCondition(Target(), "talents", choice.key, self:GetChecked() and true or false)
      end)
      check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, last == talents and -4 or 2)
      check.key = choice.key
      window.talents[#window.talents + 1] = check
      last = check
    end
  end

  local right = ns.T.Heading(window, L["Group"], 180)
  right:SetPoint("TOPLEFT", 222, -90)
  window.groups = {}
  last = right
  for _, group in ipairs(ns.GROUPS) do
    local check = MakeCheck(window, group.label, function(self)
      ns.SetCondition(Target(), "group", group.key, self:GetChecked() and true or false)
    end)
    check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, last == right and -4 or 2)
    check.key = group.key
    window.groups[#window.groups + 1] = check
    last = check
  end

  -- group role (Conditions.lua ns.ROLES), under Group; only where the game has roles
  window.roles = {}
  if ns.HasRoles() then
    local roles = ns.T.Heading(window, L["Role"], 180)
    roles:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -8)
    last = roles
    for _, role in ipairs(ns.ROLES) do
      local check = MakeCheck(window, role.label, function(self)
        ns.SetCondition(Target(), "role", role.key, self:GetChecked() and true or false)
      end)
      check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, last == roles and -4 or 2)
      check.key = role.key
      window.roles[#window.roles + 1] = check
      last = check
    end
  end

  local combat = ns.T.Heading(window, L["Combat"], 180)
  combat:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -8)
  window.combat = {}
  last = combat
  for _, choice in ipairs(ns.COMBAT) do
    local check = MakeCheck(window, choice.label, function()
      ns.SetCondition(Target(), "combat", choice.key)
    end)
    check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, last == combat and -4 or 2)
    check.key = choice.key
    window.combat[#window.combat + 1] = check
    last = check
  end

  -- one setting for every buff (Conditions.lua ns.Unwanted): off by default
  window.warn = MakeCheck(window, L["Warn me when a buff with rules is on where they say no"], function(self)
    ns.SetWarnUnwanted(self:GetChecked() and true or false)
  end)
  window.warn:SetPoint("BOTTOMLEFT", 12, 32)
  window.warn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Warn me to remove it"])
    GameTooltip:AddLine(L["A tracked buff with rules (its own or the row's) that is on where they say no shows in the row with \"remove\" under it, and chat names it once. Click the icon to remove the buff (out of combat). For all buffs."],
      1, 1, 1, true)
    GameTooltip:Show()
  end)
  window.warn:SetScript("OnLeave", Hide)

  window.summary = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  window.summary:SetPoint("BOTTOMLEFT", 16, 14)
  window.summary:SetPoint("BOTTOMRIGHT", -16, 14)
  window.summary:SetJustifyH("LEFT")
  window:Hide()
end

function ns.RefreshConditions()
  if not (window and window:IsShown()) then
    return
  end
  local target = Target()
  local conditions = Conditions() or {}
  local editable = Editable()
  local isEntry = type(target) == "table"
  window.own:SetShown(isEntry)
  window.own:SetChecked(isEntry and target.conditions ~= nil)
  window.name:SetText(isEntry and ns.EntryName(target) or L["The whole row (every tracked buff without its own rules)"])
  local function Ready(check, on)
    check:SetChecked(on)
    check:SetEnabled(editable)
    local grey = editable and 1 or 0.5
    check.Text:SetTextColor(grey, grey, grey)
  end
  for _, check in ipairs(window.places) do
    Ready(check, not (conditions.places and conditions.places[check.key] == false))
  end
  for _, check in ipairs(window.groups) do
    Ready(check, not (conditions.groups and conditions.groups[check.key] == false))
  end
  for _, check in ipairs(window.talents) do
    Ready(check, not (conditions.talents and conditions.talents[check.key] == false))
  end
  for _, check in ipairs(window.roles) do
    Ready(check, not (conditions.roles and conditions.roles[check.key] == false))
  end
  local combat = conditions.combat or "any"
  for _, check in ipairs(window.combat) do
    Ready(check, check.key == combat)
  end
  window.warn:SetChecked(ns.db.warnUnwanted and true or false)
  local text = ns.ConditionsText(Conditions())
  window.summary:SetText(isEntry and not editable and L["Same as the whole row: %s"]:format(text) or text)
end

-- Opens the window for "row" or a tracked entry, beside `anchor`.
function ns.OpenConditions(target, anchor)
  if not window then
    Build()
  end
  window.target = target
  window:ClearAllPoints()
  if anchor then
    window:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
  else
    window:SetPoint("CENTER")
  end
  window:Show()
  ns.RefreshConditions()
end

-- Tooltip for a "Where" button.
function ns.ConditionsTooltip(self, target)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if target == "row" then
    GameTooltip:AddLine(L["Where the row shows"])
    GameTooltip:AddLine(ns.ConditionsText(ns.db.conditions), 1, 1, 1, true)
  else
    GameTooltip:AddLine(L["Where %s shows"]:format(ns.EntryName(target)))
    local text = ns.ConditionsText(ns.EntryConditions(target))
    GameTooltip:AddLine(target.conditions and text or L["Same as the whole row: %s"]:format(text), 1, 1, 1, true)
  end
  GameTooltip:AddLine(L["On top of Always / When active / When missing. Click to change."], 0.7, 0.7, 0.7, true)

  GameTooltip:Show()
end
ns.HideTooltip = Hide
