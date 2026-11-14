local _, ns = ...

-- The row of icons on screen: centered on an anchor that can be dragged while unlocked, or while
-- Blizzard's Edit Mode is open.

local GAP = 6
local RING = "Interface\\AddOns\\BuffTracker\\Media\\Ring"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local WARN_SECONDS = 60
local RESCAN_SECONDS = 1
local TOP_OFFSET = 44 -- default position: the row's center, below the top edge of the screen

local anchor, anchorLabel, mover
local editMode = false -- Edit Mode open: unlocked for now, without changing the saved lock

local function IsUnlocked()
  return editMode or not ns.db.locked
end
local icons = {}
-- Secure buttons laid over the icons of buffs you can cast, so a click casts the buff on you.
-- The icons themselves stay plain frames, free to change in combat. The game doesn't let addons
-- move or change secure buttons in combat, so these are hidden as combat starts and laid out
-- again when it ends: in combat the icons can't be clicked. They're placed on UIParent, not on
-- the icons, as anchoring a secure button to an icon would lock the icon in combat too.
local clicks = {}

-- Shapes ----------------------------------------------------------------------------------------
-- Icons and party buttons are squares with the Tylesser double border, or circles: the art cut
-- round with a mask and a ring (Media/Ring, white, colored like the border) in place of the
-- border. Clients without mask textures only get squares.

function ns.IsRound()
  return ns.db.iconShape == "circle"
end

-- frame needs: border (ns.T.DoubleBorder), and the textures to cut round in frame.roundParts.
function ns.ApplyShape(frame, round)
  round = round and frame.CreateMaskTexture ~= nil
  if (frame.round or false) == round then
    return
  end
  if round and not frame.mask then
    frame.mask = frame:CreateMaskTexture()
    frame.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    frame.mask:SetAllPoints()
    if frame.border then -- the click overlays have no border, so no ring either
      frame.ring = frame:CreateTexture(nil, "OVERLAY", nil, 6)
      frame.ring:SetAllPoints()
      frame.ring:SetTexture(RING)
    end
  end
  frame.round = round
  local parts = {}
  for _, part in ipairs(frame.roundParts or {}) do
    parts[#parts + 1] = part
  end
  parts[#parts + 1] = frame.GetHighlightTexture and frame:GetHighlightTexture() or nil
  for _, part in ipairs(parts) do
    if round then
      part:AddMaskTexture(frame.mask)
    elseif frame.mask then
      part:RemoveMaskTexture(frame.mask)
    end
  end
  if frame.ring then
    frame.ring:SetShown(round)
  end
  if frame.border then
    for _, lines in pairs(frame.border) do
      for _, line in ipairs(lines) do
        line:SetShown(not round)
      end
    end
  end
end

-- Border color for either shape.
function ns.SetFrameColor(frame, color)
  if frame.border then
    ns.T.SetBorderColor(frame.border, color)
  end
  if frame.ring then
    frame.ring:SetVertexColor(color[1], color[2], color[3])
  end
end

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

  -- Shown while unlocked: a stone plate behind the row and a label above it.
  mover = CreateFrame("Frame", nil, anchor)
  mover:SetPoint("TOPLEFT", -10, 10)
  mover:SetPoint("BOTTOMRIGHT", 10, -24)
  mover:SetFrameLevel(math.max(anchor:GetFrameLevel() - 1, 0))
  ns.T.Stone(mover, 12)

  anchorLabel = mover:CreateFontString(nil, "OVERLAY")
  ns.T.Font(anchorLabel, 11)
  anchorLabel:SetPoint("BOTTOM", mover, "TOP", 0, 6)
  anchorLabel:SetText("BUFF TRACKER: DRAG TO MOVE")

  ApplyPosition()

  -- Clients with Edit Mode: the row can be moved there too, like Blizzard's own frames.
  local manager = EditModeManagerFrame
  if manager and manager.HookScript then
    manager:HookScript("OnShow", function()
      editMode = true
      ns.UpdateDisplay()
    end)
    manager:HookScript("OnHide", function()
      editMode = false
      ns.UpdateDisplay()
    end)
    editMode = manager:IsShown() and true or false
  end
end

local function GetIcon(index)
  local icon = icons[index]
  if icon then
    return icon
  end
  icon = CreateFrame("Frame", nil, anchor)
  icon.backdrop = icon:CreateTexture(nil, "BACKGROUND")
  icon.backdrop:SetAllPoints()
  icon.backdrop:SetColorTexture(0, 0, 0, 1)
  icon.border = ns.T.DoubleBorder(icon)
  icon.stud = ns.T.Stud(icon, 12, true)
  icon.stud:SetPoint("CENTER", icon, "TOPRIGHT", -1, -1)
  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetPoint("TOPLEFT", 3, -3)
  icon.texture:SetPoint("BOTTOMRIGHT", -3, 3)
  icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon.roundParts = { icon.texture, icon.backdrop }
  icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  icon.count:SetPoint("BOTTOMRIGHT", -2, 2)
  icon.time = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
  icon.time:SetPoint("TOP", icon, "BOTTOM", 0, -2)
  icons[index] = icon
  return icon
end

local function ShowClickTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:AddLine(self.spellName)
  GameTooltip:AddLine("Click to cast it on yourself.", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function GetClick(index)
  local click = clicks[index]
  if click then
    return click
  end
  click = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  -- Newer clients run secure clicks on key down or up depending on a setting; they need both.
  if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("ActionButtonUseKeyDown") ~= nil then
    click:RegisterForClicks("AnyUp", "AnyDown")
  else
    click:RegisterForClicks("AnyUp")
  end
  click:SetAttribute("type", "spell")
  click:SetAttribute("unit", "player")
  click:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  click.roundParts = {}
  click:SetScript("OnEnter", ShowClickTooltip)
  click:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  click:Hide()
  clicks[index] = click
  return click
end

local function HideClicks()
  for _, click in ipairs(clicks) do
    click:Hide()
  end
end

-- Out of combat only. shown: the entries shown, in icon order.
local function LayoutClicks(shown, size)
  if InCombatLockdown() then
    return
  end
  local used = 0
  if not IsUnlocked() and ns.db.clickToCast then
    for index, entry in ipairs(shown) do
      local x, y = icons[index]:GetCenter()
      if x and ns.KnowsSpell(entry.name) then
        used = used + 1
        local click = GetClick(used)
        click:SetSize(size, size)
        click:ClearAllPoints()
        click:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        click:SetFrameStrata(anchor:GetFrameStrata())
        click:SetFrameLevel(icons[index]:GetFrameLevel() + 5)
        ns.ApplyShape(click, ns.IsRound())
        click:SetAttribute("spell", entry.name)
        click.spellName = entry.name
        click:Show()
      end
    end
  end
  for index = used + 1, #clicks do
    clicks[index]:Hide()
  end
end

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    -- still allowed while this event runs: the lockdown starts right after it
    if not InCombatLockdown() then
      HideClicks()
    end
  elseif ns.db then
    ns.UpdateDisplay()
  end
end)

local function ShouldShow(entry, state)
  if entry.mode == "always" or IsUnlocked() then
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
    local round = ns.IsRound()
    ns.ApplyShape(icon, round)
    -- the stud sits on the corner of a square, and on the ring of a circle
    local studInset = round and math.floor(size * 0.15 + 0.5) or 1
    icon.stud:ClearAllPoints()
    icon.stud:SetPoint("CENTER", icon, "TOPRIGHT", -studInset, -studInset)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", anchor, "CENTER", (index - (#shown + 1) / 2) * (size + GAP), 0)
    icon.state = state
    icon.texture:SetTexture(entry.icon or ns.DEFAULT_ICON)
    icon.texture:SetDesaturated(not active)
    -- Missing: ruby border and a ruby stud. Active: gold. Not read yet (may or may not be on): grey.
    icon.stud:SetShown(missing or false)
    if missing then
      ns.SetFrameColor(icon, ns.T.RUBY)
      icon.texture:SetVertexColor(1, 0.5, 0.5)
    elseif active then
      ns.SetFrameColor(icon, ns.T.GOLD_DEEP)
      icon.texture:SetVertexColor(1, 1, 1)
    else
      ns.SetFrameColor(icon, ns.T.GREY)
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

  local unlocked = IsUnlocked()
  anchor:EnableMouse(unlocked)
  mover:SetShown(unlocked)
  LayoutClicks(shown, size)
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
  ns.UpdateDisplay()
end

function ns.CycleShape()
  local current = ns.db.iconShape
  for index, shape in ipairs(ns.SHAPES) do
    if shape == current then
      ns.db.iconShape = ns.SHAPES[index % #ns.SHAPES + 1]
      break
    end
  end
  if ns.db.iconShape == current then
    ns.db.iconShape = ns.SHAPES[1] -- unknown saved value
  end
  ns.UpdateDisplay()
  ns.PartyChanged()
  ns.RefreshOptions()
end

function ns.SetClickToCast(enabled)
  ns.db.clickToCast = enabled
  ns.UpdateDisplay()
end
