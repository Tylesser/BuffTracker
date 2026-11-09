local addonName, ns = ...

local TICK_SECONDS = 0.2

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")

local function Setup()
  BuffTrackerDB = BuffTrackerDB or {}
  for key, value in pairs(ns.defaults) do
    if BuffTrackerDB[key] == nil then
      BuffTrackerDB[key] = value
    end
  end
  BuffTrackerDB.tracked = BuffTrackerDB.tracked or {}
  ns.db = BuffTrackerDB
  ns.SetupParty()
  ns.CreateDisplay()
  ns.CreateOptions()
  ns.CreatePartyOptions()
end

eventFrame:SetScript("OnEvent", function(self, event, loadedName)
  if event == "ADDON_LOADED" then
    if loadedName == addonName then
      Setup()
      self:UnregisterEvent("ADDON_LOADED")
    end
    return
  end
  if not ns.db then
    return
  end
  if event == "PLAYER_ENTERING_WORLD" and #ns.db.tracked == 0 and not ns.db.welcomed then
    ns.db.welcomed = true
    print(ns.PREFIX .. "type /btrack to choose the buffs to track.")
  end
  ns.Changed()
end)

local sinceTick = 0
eventFrame:SetScript("OnUpdate", function(_, elapsed)
  sinceTick = sinceTick + elapsed
  if sinceTick >= TICK_SECONDS and ns.db then
    ns.Tick(sinceTick)
    ns.PartyTick(sinceTick)
    sinceTick = 0
  end
end)

local function PrintList()
  if #ns.db.tracked == 0 then
    print(ns.PREFIX .. "nothing tracked yet.")
    return
  end
  print(ns.PREFIX .. "tracked buffs:")
  for _, entry in ipairs(ns.db.tracked) do
    local state = ns.StateOf(entry)
    local current = "|cffaaaaaaunknown|r"
    if state and state.active then
      current = "|cff20ff20on|r"
    elseif state and state.known then
      current = "|cffff4040missing|r"
    end
    print("  " .. entry.name .. ": " .. current .. " (show: " .. ns.MODE_LABELS[entry.mode] .. ")")
  end
  if not ns.scanComplete then
    print("  The game is hiding your buffs right now, so these may be out of date.")
  end
end

SLASH_BUFFTRACKER1 = "/btrack"
SLASH_BUFFTRACKER2 = "/bufftracker"
SlashCmdList.BUFFTRACKER = function(msg)
  msg = strtrim(msg or "")
  local command, rest = msg:match("^(%S+)%s*(.*)$")
  command = command and command:lower() or ""

  if command == "" then
    ns.OpenOptions()
  elseif command == "add" then
    local entry, reason = ns.AddBuff(rest)
    if entry then
      print(ns.PREFIX .. "now tracking " .. entry.name .. ".")
    else
      print(ns.PREFIX .. reason)
    end
  elseif command == "remove" then
    if ns.RemoveBuff(rest) then
      print(ns.PREFIX .. "stopped tracking " .. rest .. ".")
    else
      print(ns.PREFIX .. rest .. " is not tracked.")
    end
  elseif command == "party" then
    ns.OpenPartyOptions()
  elseif command == "list" then
    PrintList()
  elseif command == "lock" or command == "unlock" then
    ns.SetLocked(command == "lock")
  elseif command == "reset" then
    ns.ResetPosition()
  else
    print(ns.PREFIX .. "commands:")
    print("  /btrack: open the options, /btrack party: party buff buttons and blessings")
    print("  /btrack add <name or spell ID>, /btrack remove <name>, /btrack list")
    print("  /btrack lock, /btrack unlock, /btrack reset (put the icons back in place)")
  end
end
