local _, root = ...
-- Buff Tracker's ns, or Codex's codex.buffs (its `codex` field is Codex's ns): this file is the same in both
local inCodex = type(root.buffs) == "table" and root.buffs.codex == root
local ns = inCodex and root.buffs or root
local L = root.L

-- One key for the next missing buff (2026-11-28, the user's request): a hidden secure button that casts the first
-- missing buff of the icon row on you, or uses its item, exactly as a click on that icon does (ns.ClickAction).
-- The key is an override binding set from the options (the player's own binding of that key comes back when it's
-- cleared), and macros can use "/click <button name>". Secure attributes change out of combat only: the button
-- is laid out with the icon overlays (Display.lua LayoutClicks) and cleared when combat starts, like the overlays,
-- so in a fight the key does nothing.

ns.NEXT_BUTTON_NAME = inCodex and "CodexBuffsNextBuff" or "BuffTrackerNextBuff"

local button
local keyPending = false

local function Locked()
  return InCombatLockdown and InCombatLockdown() or false
end

-- The button (made on first use, out of combat).
function ns.NextBuffButton()
  if button or Locked() then
    return button
  end
  button = CreateFrame("Button", ns.NEXT_BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
  -- newer clients run secure clicks on key down or up depending on a setting; they need both
  if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("ActionButtonUseKeyDown") ~= nil then
    button:RegisterForClicks("AnyUp", "AnyDown")
  else
    button:RegisterForClicks("AnyUp")
  end
  button:SetAttribute("unit", "player")
  button:Hide()
  return button
end

-- The first entry of `shown` (the row's icons, in order) that is missing and has something to click, and its action.
function ns.NextMissing(shown)
  for _, entry in ipairs(shown or {}) do
    local state = ns.StateOf(entry)
    if state and state.known and not state.active and not ns.Unwanted(entry, state) then
      local action = ns.ClickAction(entry)
      if action then
        return entry, action
      end
    end
  end
  return nil
end

-- Out of combat only (Display.lua calls it with the icons it shows; unlocked = nothing).
function ns.LayoutNextBuff(shown)
  if Locked() or ns.combatStarting then
    return
  end
  local entry, action = nil, nil
  if shown then
    entry, action = ns.NextMissing(shown)
  end
  ns.nextEntry = entry
  if not (button or action or ns.db.nextKey) then
    return -- made the first time there is something to cast (or a key): no secure frame before that
  end
  local secure = ns.NextBuffButton()
  if not secure then
    return
  end
  if not action then
    secure:SetAttribute("type", nil)
    secure:SetAttribute("spell", nil)
    secure:SetAttribute("item", nil)
    secure:SetAttribute("target-slot", nil)
  elseif action.item then
    secure:SetAttribute("type", "item")
    secure:SetAttribute("spell", nil)
    secure:SetAttribute("item", "item:" .. action.item)
    secure:SetAttribute("target-slot", action.slot)
  else
    secure:SetAttribute("type", "spell")
    secure:SetAttribute("item", nil)
    secure:SetAttribute("target-slot", nil)
    secure:SetAttribute("spell", action.spell)
  end
end

-- Combat starts (PLAYER_REGEN_DISABLED, still allowed): the key does nothing until it ends.
function ns.ClearNextBuff()
  if button and not Locked() then
    button:SetAttribute("type", nil)
  end
  ns.nextEntry = nil
end

-- A key press as the game names bindings ("SHIFT-F9"); nil for a modifier alone; false for Escape (clear).
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
  LMETA = true, RMETA = true, UNKNOWN = true }
function ns.KeyName(key)
  if type(key) ~= "string" or MODIFIERS[key] then
    return nil
  end
  if key == "ESCAPE" then
    return false
  end
  local name = key
  if IsShiftKeyDown() then
    name = "SHIFT-" .. name
  end
  if IsControlKeyDown() then
    name = "CTRL-" .. name
  end
  if IsAltKeyDown() then
    name = "ALT-" .. name
  end
  return name
end

-- Sets the override binding for db.nextKey (not in combat: then after it).
function ns.ApplyNextKey()
  if Locked() then
    keyPending = true
    return
  end
  keyPending = false
  local key = ns.db and ns.db.nextKey
  if not (button or key) then
    return
  end
  local secure = ns.NextBuffButton()
  if ClearOverrideBindings then
    ClearOverrideBindings(secure)
  end
  if key and SetOverrideBindingClick then
    SetOverrideBindingClick(secure, true, key, ns.NEXT_BUTTON_NAME, "LeftButton")
  end
end

-- Sets the key (nil clears). Returns what the key did before, if anything.
function ns.SetNextKey(key)
  local before
  if key and GetBindingAction then
    local ok, action = pcall(GetBindingAction, key)
    before = ok and type(action) == "string" and action ~= "" and action or nil
  end
  ns.db.nextKey = key or nil
  ns.ApplyNextKey()
  ns.UpdateDisplay()
  return before
end

function ns.NextKeyPending()
  return keyPending
end

-- The key button's tooltip (both options pages).
function ns.NextKeyTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Key: next missing buff"])
  GameTooltip:AddLine(L["Casts the first missing buff of your icon row on you, or uses its item, like a click on its icon. Out of combat only."],
    1, 1, 1, true)
  GameTooltip:AddLine(L["In a macro: %s"]:format("/click " .. ns.NEXT_BUTTON_NAME), 0.6, 0.6, 0.6)
  local entry = ns.nextEntry
  if entry then
    GameTooltip:AddLine(L["Now: %s"]:format(ns.EntryName(entry)), 0.4, 1, 0.4)
  else
    GameTooltip:AddLine(L["Now: nothing missing"], 0.6, 0.6, 0.6)
  end
  GameTooltip:AddLine(L["Click, then press a key. Escape or right-click clears it."], 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

-- Wires a key button of an options page: click to capture, right-click clears; refresh() redraws the page.
function ns.SetupNextKeyButton(keyButton, refresh)
  keyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  keyButton:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then
      self.capturing = false
      self:EnableKeyboard(false)
      ns.SetNextKey(nil)
    else
      self.capturing = not self.capturing
      self:EnableKeyboard(self.capturing)
    end
    refresh()
  end)
  keyButton:SetScript("OnKeyDown", function(self, key)
    if not self.capturing then
      return
    end
    local name = ns.KeyName(key)
    if name == nil then
      return -- a modifier alone: wait for the key
    end
    self.capturing = false
    self:EnableKeyboard(false)
    local before = ns.SetNextKey(name or nil)
    if before then
      print(ns.PREFIX .. L["%s did \"%s\"; that comes back when you clear the key here."]:format(name, before))
    end
    refresh()
  end)
  -- (hooked: the button's own look may use these)
  keyButton:HookScript("OnEnter", ns.NextKeyTooltip)
  keyButton:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

-- The key button's text.
function ns.NextKeyText(keyButton)
  if keyButton.capturing then
    return L["Press a key"]
  end
  return ns.db.nextKey or L["Not set"]
end
