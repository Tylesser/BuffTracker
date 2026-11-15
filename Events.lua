local addonName, ns = ...

local TICK_SECONDS = 0.2

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player") -- weapon enchants, where nothing else fires
pcall(eventFrame.RegisterEvent, eventFrame, "WEAPON_ENCHANT_CHANGED") -- Retail only

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
  ns.T.AddCompartment({ text = ns.TITLE, onClick = ns.OpenOptions, tooltip = { "Click to open the options." } })
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
  if event == "GET_ITEM_INFO_RECEIVED" then
    if not ns.ItemPending(loadedName) then -- loadedName is the item ID here
      return
    end
    ns.ScanBags()
  elseif event == "BAG_UPDATE_DELAYED" then
    ns.ScanBags()
  elseif event == "SPELLS_CHANGED" then
    ns.RefreshKnown() -- before the click overlays are laid out again: they depend on known spells
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
  elseif command == "basics" then
    ns.AddPreset()
  elseif command == "item" then
    -- /btrack item <buff> = <item name, ID or link>; without "= item" it goes back to none
    local name, item = rest:match("^(.-)%s*=%s*(.-)$")
    name = strtrim(name or rest)
    local entry = ns.FindTracked(name)
    if not entry then
      print(ns.PREFIX .. (name ~= "" and name or "that buff") .. " is not tracked.")
    elseif not item or item == "" then
      ns.SetItem(entry, nil)
      print(ns.PREFIX .. entry.name .. " no longer uses an item.")
    else
      local id = ns.ResolveItem(item)
      if id and ns.IsEquippable(id) then
        print(ns.PREFIX .. "that item is worn, not used: clicking it would equip it.")
      elseif id then
        ns.SetItem(entry, id)
        print(ns.PREFIX .. "clicking " .. entry.name .. " now uses " .. (ns.ItemName(id) or ("item " .. id)) .. ".")
      else
        print(ns.PREFIX .. "no item called " .. item .. " found. Try its item ID, or shift-click it into the line.")
      end
    end
  elseif command == "party" then
    ns.OpenPartyOptions()
  elseif command == "debug" then
    ns.PartyDebug()
  elseif command == "feedback" then
    ns.T.ShowFeedback()
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
    print("  /btrack basics: track the basic buffs of your class")
    print("  /btrack item <buff> = <item>: the item a click on that icon uses")
    print("  /btrack lock, /btrack unlock, /btrack reset (put the icons back in place)")
    print("  /btrack debug: show what the party buttons see")
    print("  /btrack feedback: report a bug or suggest an idea")
  end
end
