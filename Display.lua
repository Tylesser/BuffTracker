local _, ns = ...

-- The row of icons on screen: centered on an anchor that can be dragged while unlocked.

local GAP = 6
local WARN_SECONDS = 60
local RESCAN_SECONDS = 1
local TOP_OFFSET = 44 -- default position: the row's center, below the top edge of the screen

local anchor, anchorLabel, anchorBackground
local icons = {}

local function FormatTime(seconds)
  if seconds >= 3600 then
    return string.format("%dh", math.ceil(seconds / 3600))
  elseif seconds >= 60 then
    return string.format("%dm", math.ceil(seconds / 60))
  end
  return string.format("%d", math.ceil(seconds))
end

-- Top center of the screen until the row is moved. A moved row is saved as an offset from the
-- screen center, so it stays centered as icons come and go.
local function SavePosition()
  local x, y = anchor:GetCenter()
  local centerX, centerY = UIParent:GetCenter()
  ns.db.x, ns.db.y = x - centerX, y - centerY
end

local function ApplyPosition()
  anchor:ClearAllPoints()
  if ns.db.x and ns.db.y then
    anchor:SetPoint("CENTER", UIParent, "CENTER", ns.db.x, ns.db.y)
  else
    anchor:SetPoint("CENTER", UIParent, "TOP", 0, -TOP_OFFSET)
  end
end

function ns.CreateDisplay()
  anchor = CreateFrame("Frame", nil, UIParent)
  anchor:SetSize(ns.db.iconSize, ns.db.iconSize)
  anchor:SetClampedToScreen(true)
  anchor:SetMovable(true)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", anchor.StartMoving)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
    ApplyPosition()
  end)

  anchorBackground = anchor:CreateTexture(nil, "BACKGROUND")
  anchorBackground:SetPoint("TOPLEFT", -6, 6)
  anchorBackground:SetPoint("BOTTOMRIGHT", 6, -20)
  anchorBackground:SetColorTexture(0.1, 0.5, 0.9, 0.35)

  anchorLabel = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  anchorLabel:SetPoint("BOTTOM", anchor, "TOP", 0, 10)
  anchorLabel:SetText("Buff Tracker: drag to move")

  ApplyPosition()
end

local function GetIcon(index)
  local icon = icons[index]
  if icon then
    return icon
  end
  icon = CreateFrame("Frame", nil, anchor)
  icon.border = icon:CreateTexture(nil, "BACKGROUND")
  icon.border:SetAllPoints()
  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetPoint("TOPLEFT", 2, -2)
  icon.texture:SetPoint("BOTTOMRIGHT", -2, 2)
  icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  icon.count:SetPoint("BOTTOMRIGHT", -2, 2)
  icon.time = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
  icon.time:SetPoint("TOP", icon, "BOTTOM", 0, -2)
  icons[index] = icon
  return icon
end

local function ShouldShow(entry, state)
  if entry.mode == "always" or not ns.db.locked then
    return true
  end
  if not (state and state.known) then
    return false
  end
  if entry.mode == "active" then
    return state.active
  end
  return not state.active
end

local function UpdateTime(icon)
  local state = icon.state
  local expires = state and state.active and state.expires or 0
  if expires > 0 then
    local remaining = math.max(expires - GetTime(), 0)
    icon.time:SetText(FormatTime(remaining))
    if remaining < WARN_SECONDS then
      icon.time:SetTextColor(1, 0.3, 0.3)
    else
      icon.time:SetTextColor(1, 1, 1)
    end
  else
    icon.time:SetText("")
  end
end

function ns.UpdateDisplay()
  if not anchor then
    return
  end
  local size = ns.db.iconSize
  local shown = {}
  for _, entry in ipairs(ns.db.tracked) do
    if ShouldShow(entry, ns.StateOf(entry)) then
      shown[#shown + 1] = entry
    end
  end

  local rowWidth = math.max(#shown * size + math.max(#shown - 1, 0) * GAP, size)
  anchor:SetSize(rowWidth, size)

  for index, entry in ipairs(shown) do
    local icon = GetIcon(index)
    local state = ns.StateOf(entry)
    local active = state and state.active
    local missing = state and state.known and not active

    icon:SetSize(size, size)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", anchor, "CENTER", (index - (#shown + 1) / 2) * (size + GAP), 0)
    icon.state = state
    icon.texture:SetTexture(entry.icon or ns.DEFAULT_ICON)
    icon.texture:SetDesaturated(not active)
    if missing then
      icon.border:SetColorTexture(0.9, 0.1, 0.1, 1)
      icon.texture:SetVertexColor(1, 0.5, 0.5)
    elseif active then
      icon.border:SetColorTexture(0, 0, 0, 1)
      icon.texture:SetVertexColor(1, 1, 1)
    else
      -- Not read yet, so it may or may not be on.
      icon.border:SetColorTexture(0.3, 0.3, 0.3, 1)
      icon.texture:SetVertexColor(0.7, 0.7, 0.7)
    end
    local count = active and state.count or 0
    icon.count:SetText(count > 1 and count or "")
    UpdateTime(icon)
    icon:Show()
  end
  for index = #shown + 1, #icons do
    icons[index].state = nil
    icons[index]:Hide()
  end

  local unlocked = not ns.db.locked
  anchor:EnableMouse(unlocked)
  anchorBackground:SetShown(unlocked)
  anchorLabel:SetShown(unlocked)
end

-- Runs a few times per second: counts down, and checks again while the game hides buffs. A timer
-- that runs out while they're hidden means "unknown", as the buff may have been refreshed.
local sinceRescan = 0
function ns.Tick(elapsed)
  if not ns.scanComplete then
    sinceRescan = sinceRescan + elapsed
    if sinceRescan >= RESCAN_SECONDS then
      sinceRescan = 0
      ns.Scan()
      ns.UpdateDisplay()
      if ns.scanComplete then
        ns.RefreshOptions()
      end
      return
    end
  end

  local now = GetTime()
  local changed = false
  for _, state in pairs(ns.state) do
    if state.active and state.expires and state.expires > 0 and state.expires <= now then
      state.known = ns.scanComplete
      state.active = false
      state.count = 0
      state.expires = 0
      changed = true
    end
  end
  if changed then
    ns.UpdateDisplay()
    return
  end
  for _, icon in ipairs(icons) do
    if icon:IsShown() then
      UpdateTime(icon)
    end
  end
end

function ns.SetLocked(locked)
  ns.db.locked = locked
  ns.UpdateDisplay()
  ns.RefreshOptions()
end

function ns.SetIconSize(size)
  ns.db.iconSize = math.min(math.max(size, ns.MIN_ICON_SIZE), ns.MAX_ICON_SIZE)
  ns.UpdateDisplay()
  ns.RefreshOptions()
end

function ns.ResetPosition()
  ns.db.x, ns.db.y = nil, nil
  ApplyPosition()
end
