# BuffTracker ("Tylesser - Buff Tracker")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from BuffTracker.toc)

- `Tylesser.lua`: the shared Tylesser "Runestone" look (`ns.T`: stone panels, gold borders, studs, Cinzel, buttons,
  check boxes, options page header, chat prefix). Loaded first. The same file is in every Tylesser addon: edit them together
  (see the workspace CLAUDE.md).
- `Core.lua`: defaults for `BuffTrackerDB` (`SavedVariablesPerCharacter`: `tracked`, `locked`, `iconSize`, `clickToCast`, `iconShape`, and `x`, `y` once the row has been moved; before that it sits at the top center of the screen), reading
  the player's buffs, `ns.state` per lowercase buff name, adding and removing buffs, and the spellbook list for the
  options page. A tracked entry is `{ name, icon, mode }`, where mode is `always`, `active` or `missing`, plus optional
  fields (nil for entries saved by older versions, so no migration): `item` (item ID a click uses), `alert` (true: sound
  and flash when it drops in combat) and `slot` (16/17: a weapon enchant entry named "Main-hand weapon enchant" /
  "Off-hand weapon enchant", read with `GetWeaponEnchantInfo` in `ns.ScanWeapons`, also every second from `ns.Tick`).
  State changes go through `SetState`, which calls `ns.BuffDropped` (only with `alert` and `InCombatLockdown()`: one
  `PlaySound(SOUNDKIT.RAID_WARNING or 8959)` per second at most, and the key into `ns.pendingFlash`). Items: `ns.ScanBags`
  (on `BAG_UPDATE_DELAYED`, and `GET_ITEM_INFO_RECEIVED` for bag items whose name was missing) lists bag items with a use
  spell, leaving out equippable items (`ns.IsEquippable`: a secure item click would equip a trinket; `/btrack item`
  refuses them too); `ns.ItemFor(entry)` is the attached item, else (spell not known, not a weapon) the bag item whose use spell has
  the buff's name; `ns.ClickAction(entry)` is that item while you have it, else the known spell. Class basics:
  `ns.PRESETS` (a nested list = replacements, first known wins; `"blessing"` = the player's own `ns.BlessingFor`
  choice), `ns.PresetBuffs` / `ns.AddPreset` (`/btrack basics`).
- `Display.lua`: the row of icons, centered on a draggable anchor, and `ns.Tick` (countdown and rescans). While
  `EditModeManagerFrame` is shown (hooked OnShow/OnHide, only on clients that have it) the row acts unlocked without
  changing `locked`. The position stays in `x`, `y`, not in Edit Mode layouts. An icon whose entry uses an item shows
  the item count (red 0 when gone). Alerts flash the plain icon with an Alpha animation group (`Flash`), never the
  secure overlay. Also the shape helpers shared with
  `Party.lua`: `ns.ApplyShape(frame, round)` (mask `TempPortraitAlphaMask` on `frame.roundParts` and the highlight, ring
  `Media/Ring.tga` in place of the double border) and `ns.SetFrameColor`. `iconShape` is `square` or `circle`.
  `Media/Ring.tga` is BuffTracker's own (white, colored with SetVertexColor), built by `branding/source/ring-art.js`
  (`node ring-art.js <depsDir> Media`).
- `Party.lua`: party and raid buff buttons. Units come from `GroupUnits()`: player + party1-4, or in a raid
  raid1..raidN (`GetNumGroupMembers`). Buttons are made lazily per unit (`GetButton(unit, slot)`, out of combat, in
  `buttons[unit]`), never all up front. Raid buttons (units `raidN`) are children of `raidHolder`, a
  `SecureHandlerStateTemplate` frame with `RegisterStateDriver(holder, "visibility", "[combat] hide; show")`: the game
  hides them in combat, so they never take a click meant for the raid frame. They sit in the frame's top right corner,
  12-14 px, in at most a third of its width (`InsideFit`); party buttons sit beside the frame as before. Option
  `party.raid` ("Buttons on raid frames", default on) turns raid buttons off. A layout sets attributes and points only
  when unit, spell, frame, size or side changed (fields on the button), so the 1 sec refresh only recolors.
  `UpdateLooks` dims a button (0.25, grey) when its frame now shows another unit (secure headers reshuffle in combat).
  Frame names to check are built once (`PARTY_FRAME_NAMES`, `RAID_FRAME_NAMES` incl. ElvUI Raid1-3). In a raid only
  units with `UNIT_AURA` are read again (`MarkStale`; player/partyN map to raidN through `raidOf`, built once per roster
  update), plus all of them every 5 sec and on roster changes / combat end; dirty layouts wait at least 0.5 sec, and a
  roster update resets the frame search wait only when the raid size changed (or on `PLAYER_ENTERING_WORLD`).
  Reagent item IDs are chosen per client from the interface number (`REAGENTS`: Classic Era/Forever the classic IDs, TBC
  Wild Quillvine, Wrath Wild Spineleaf + Devout Candle, MoP+ none). Low reagent warning: `ns.CheckReagents` (on
  `BAG_UPDATE_DELAYED` and `SPELLS_CHANGED`) watches each reagent item ID once and prints "N <reagent> left." when it
  drops to a new lower count at or below `party.reagentWarn`; the first count seen is only remembered. Never warn or
  flag low (`ns.ReagentLow`, orange tooltip line) when the count is 0 but the spell is usable: the IDs are then wrong. `ns.GROUP_BUFFS` and `ns.BLESSINGS` list each buff "family" (group spell first,
  then the single-target one; English spell names; reagent item IDs for the tooltip and the warning). `ns.ChooseSpell` takes the
  first known spell that `IsUsableSpell` allows (low mana doesn't count). Buttons are `SecureActionButtonTemplate`
  (type spell, unit partyN or raidN), up to 8 per unit, anchored to the unit's frame found by scanning Blizzard party frames,
  raid-style/raid frames, the `PartyFrame` pool, ElvUI and FlareUI (`FlareUI_Party0`-`4`) by name first. Party members
  still without a frame are searched with `EnumerateFrames` (visible frame with `unit` attribute exactly `partyN` or the
  same person's `raidN`, at least 30x12, never our own buttons; in a raid only an exact `raidN`), cached, and retried
  with a growing wait (3 to 60 sec, reset as described above). ElvUI raid frames are checked by name in a raid. `PlayerFrame` is never used and the search skips the player. Saved in `BuffTrackerDB.party`:
  `enabled`, `refresh` (default on) + `refreshSeconds` (`ns.REFRESH_CHOICES`, default 60; 1.0.0's `soon` is dropped),
  `allBlessings` (default on: `BlessingsFor` adds every known missing blessing as `extra` when the member has no
  blessing, or the chosen one is from another paladin; a blessing from you then counts as done and only that one is
  offered for refresh. Who cast a buff: `buff.mine` = true only when `sourceUnit` / `UnitAura`'s caster is you,
  false when it is someone else or `isFromPlayerOrPlayerPet == false` (an NPC), nil otherwise.
  `isFromPlayerOrPlayerPet == true` means *any* player, so it never proves "mine". `fromMe[unit][name]` is true or
  "unknown"; a blessing of unknown caster gives the old rule: the chosen blessing only, no extras, and dims extras in
  combat only in rows laid out with extras (`button.everyBlessing`)),
  `range` (default on) + `rangeYards` (`ns.RANGE_CHOICES`, default 60: `TooFar` uses `UnitPosition` when it gives a
  position on the same map, else only `UnitIsVisible` (~100 yd) and `UnitInRange` (~40 yd); out of combat far members get
  no buttons, in combat their buttons go to alpha 0), `off[family]`, `classes[CLASS]` and `members[name]` (blessing key or "none"; members win),
  `reagentWarn` (`ns.REAGENT_CHOICES`, default 5, 0 = off), `raid` (default on).
- `Dispel.lua`: dispel buttons. `ns.DISPELS` (per client: Classic Era/Forever/TBC/Wrath vs MoP+; English names, best
  first, `types` + `typeList`), `ns.DISPEL_FILTER` (`HARMFUL`, or `HARMFUL|RAID` on MoP+ where talents decide and the game
  filters), `ns.DispelSpells()` (known dispels that add a type not covered by an earlier one; cached per `ns.known`
  table), `ns.RemovableDebuffs(debuffs)` (`{ [spell] = { debuff... } }`, keyed by the `ns.DISPELS` entries), the
  shared tooltip, `BuffTrackerDB.dispel` (`party`, `self`, `combat`, all default on) and the player's own row: secure buttons
  (`ns.NewSecureButton` from Party.lua, unit player) on UIParent at coordinates under the row anchor (`ns.RowAnchor`,
  hidden while `ns.IsRowUnlocked`), laid out from `ns.UpdateDisplay`; in combat plain `selfIcons` (`ns.NewDispelIcon`)
  at the same spots for debuffs no shown button covers. Debuffs are read with `ns.ReadDebuffs(unit,
  filter)` in Core.lua (typed debuffs only, same secret checks as `ReadBuffs`). In Party.lua dispel slots come after the
  buff buttons in a member's row (so buff buttons never move when dispel slots come and go) (`need.dispel`, `button.dispel`), party and raid (raid buttons on the holder), and `DispelLooks` sets icon (the
  debuff's), border (type color), alpha.
- `Options.lua`: canvas page in Blizzard's settings: tracked buffs on the left (two-line rows: name, "when" and X; then
  the "Use item" cycle button, right-click clears, and the Alert box), buffs, spells and the two weapon enchant entries
  to add on the right, and "Add <class> basics" above the tracked list (hidden for classes without `ns.PRESETS`).
- `DispelOptions.lua`: "Dispels" sub-page (`/btrack dispel`): the two check boxes and the dispels you know.
- `PartyOptions.lua`: "Party buffs" sub-page: group buff on/off boxes, blessing per class and per party member
  (cycle buttons, no dropdowns; the member list is your own party, also in a raid), "Buttons on raid frames", and the
  low reagent warning level.
- `Events.lua`: `ADDON_LOADED` setup (ends with `ns.T.AddCompartment`: the addon menu by the minimap), `UNIT_AURA`, bag
  and weapon updates, the 0.2 second tick and the slash commands `/btrack` and `/bufftracker` (`debug` prints
  `ns.PartyDebug()`: frame, buffs and buttons per group member; `basics`; `item <buff> = <item>`).

## Rules

- New buffs default to "When missing": the user wants the icons as a reminder of what's not on them.
- Buffs are matched by name, never by spell ID, so every rank of a spell counts. A typed spell ID is turned into its name.
- **Secret values:** Retail hides aura data from addons at times, and addons installed on Forever check for this too
  (`issecretvalue`, `C_Secrets`). When Forever actually hides buffs still needs checking in game. Asking for auras while `C_Secrets.ShouldAurasBeSecret()` is true is an error, and comparing a secret value is an error.
  Keep every aura read behind the checks in `ReadBuffs`. A buff that can't be read keeps its last state, and a timer
  that ends while buffs are hidden means "unknown" (grey), never "missing" (red).
- The on-screen icons are plain frames, so they can change in combat. Click to cast (`clickToCast`, default on) is a
  separate pool of `SecureActionButtonTemplate` buttons in `Display.lua` (type spell, unit player), laid over the icons of
  known spells out of combat only. They're anchored to UIParent at the icon's center, never to the icon, as that would
  lock the icon in combat. They're hidden on `PLAYER_REGEN_DISABLED` (still allowed then) and laid out again on
  `PLAYER_REGEN_ENABLED`, and never shown while unlocked. An overlay casts (`type spell`) or uses an item (`type item`,
  `item = "item:<id>"`, plus `target-slot` 16/17 for weapon enchants); every layout sets or clears all of `spell`,
  `item` and `target-slot`, as overlays are reused. Icons with neither a known spell nor an item in the bags take no clicks.
  Weapon enchant overlays keep `unit = "player"`; if applying an oil or poison fails in game, clear `unit` for slot
  entries first. `SPELLS_CHANGED` in `Events.lua` calls `ns.RefreshKnown()` before `ns.Changed()`.
- Alerts depend on reading buffs in combat. While `ReadBuffs` can't (secret values) a drop isn't seen, so no alert.
- Party buttons are secure: never call Show, Hide, SetPoint or SetAttribute on them in combat
  (`InCombatLockdown()`). `ns.UpdateParty` only recolors in combat and lays out again on `PLAYER_REGEN_ENABLED`.
- Dispels matter in combat, when buttons can't appear. A needed dispel without a shown button then gets a plain
  **combat icon**: `ns.NewDispelIcon()` (Party.lua: a `Frame` on UIParent with the button look from the shared `Dress`,
  `EnableMouse(false)` so clicks fall through, a small `count` text, `combatDispel = true`; `unit`/`spell` set when
  used). Party.lua "Combat icons" (`combatIcons[unit][slot]`, `UpdateCombatIcons` from `ns.UpdateParty` in combat)
  places them with the same `Place` as the buttons: after the member's last shown button in a party, at the raid
  frame's corner in a raid (the holder hides raid buttons in combat). A dispel button made before combat still works
  and shows its debuff itself (`DispelLooks`: alpha 0 = nothing to remove), so it gets no icon (`HasDispelButton`).
  Icons are made lazily, hide when the debuff goes, out of combat (`HideCombatIcons`) and when `dispel.combat`
  ("Show dispel icons in combat", default on) is off. Nothing is pre-made at `PLAYER_REGEN_DISABLED` any more. With
  dispels on, `ns.PartyTick` updates right after events in combat (raids at most every 0.5 s), so a debuff shows
  within a tick; without, the once-a-second refresh stays.
- Avoid UI templates that differ per client (sliders, dropdowns). The icon size uses plain buttons for this reason.
