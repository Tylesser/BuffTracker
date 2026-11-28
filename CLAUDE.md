# BuffTracker ("Tylesser - Buff Tracker")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from BuffTracker.toc)

- `Tylesser.lua`: the shared Tylesser "Runestone" look (`ns.T`: stone panels, gold borders, studs, Cinzel, buttons,
  check boxes, options page header, chat prefix). Loaded first. The same file is in every Tylesser addon: edit them together
  (see the workspace CLAUDE.md).
- `Locales.lua` (2026-11-27): the German, French, Spanish, Russian and Portuguese texts for every `L["..."]` (rules in
  `tools/harness/L10N.md`). Spell names never go through L (`ns.LocalSpell`); weapon enchant entries keep their English
  `name` as the saved key and show `ns.EntryName(entry)`; debuff types stay English keys and are shown through
  Dispel.lua's labels; the condition summary builds from per-language phrases (`text` fields, `L["%s and %s"]`).
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
- Unwanted buffs (2026-11-21, the user: "if those conditions are not met and the player has it, warn him to remove
  it, but optional"): `db.warnUnwanted` (default false, one check in the conditions window). `ns.Unwanted(entry,
  state)` = option on, the buff has rules (`ConditionsText` not "Everywhere"), they aren't met, and it is on. The row
  shows it (ShouldShow) red with "remove" as its time text, prints once per spell until it stops being unwanted
  (`ns.warnedUnwanted`), and its secure overlay is `type = "cancelaura"` with `spell` (or `target-slot` 16/17 for a
  weapon enchant; forever SecureTemplates.lua SECURE_ACTIONS.cancelaura), also with "Click icons to cast" off.
  `ns.RowIcon(entry)` / `ns.RowClick(entry)` give the shown icon / overlay (tests). Same in Codex Modules/Buffs.
- `Conditions.lua` (2026-11-20, the user's "hide my tracked buffs in dungeons and raids, show them in a party
  out in the world"): where and when the row shows, on top of each buff's mode. A set is `{ places = { [key] = false },
  groups = { [key] = false }, combat = "in" | "out" | nil }` (false = hidden there, nil = shown, so old saves show
  everywhere): places `ns.PLACES` world / rest (IsResting) / dungeon (instance "party", "scenario") / raid / pvp
  (battleground, arena) from `ns.CurrentPlace`, groups `ns.GROUPS` solo / party / raid from `ns.CurrentGroup`,
  combat via `ns.InCombatNow` (also true while PLAYER_REGEN_DISABLED runs: `ns.combatStarting`). The row's set is
  `db.conditions`, a buff's own `entry.conditions` (`ns.EntryConditions`; `ns.SetOwnConditions` copies the row's to
  start), `ns.SetCondition(target, kind, key, value)`, `ns.ConditionsText` for the summaries. `ShouldShow` in
  Display.lua tests them first (unlocked = everything shows); at PLAYER_REGEN_DISABLED the row is redrawn with
  `ns.combatStarting` set, so LayoutClicks keeps the secure overlays hidden. ZONE_CHANGED_NEW_AREA /
  PLAYER_UPDATE_RESTING / GROUP_ROSTER_UPDATE only redraw (no rescan). `ns.shownEntries` = what the row shows (tests).
  Lua trap met here: `value == false and false or nil` is always nil. `ConditionsOptions.lua`: the window (Where /
  Group / Combat check boxes, "Its own rules" for a buff, summary), opened by "Where the row shows" above the list and
  each row's "Where" button (green text = own rules). The twin copy is in Codex's Modules/Buffs (same body).
  Talents (2026-11-22): `talents = { primary / secondary = false }`, `ns.TALENTS`, `ns.CurrentTalents()`
  (C_SpecializationInfo.GetActiveSpecGroup, else GetActiveTalentGroup; a secret or missing answer = primary),
  `ns.HasTalentGroups()` (false on Retail: there a talent group is a specialization, and the window has no Talents
  section); ACTIVE_TALENT_GROUP_CHANGED redraws (registered in pcall).
  Role (2026-11-26, the user's request): `roles = { tank / healer / damage / none = false }`, `ns.ROLES`,
  `ns.CurrentRole()` (UnitGroupRolesAssigned("player"): TANK / HEALER / DAMAGER / NONE; secret or unknown = nil,
  which hides nothing), `ns.HasRoles()` (the function exists); the window's Role section sits under Group
  (`ROLES_HEIGHT`); PLAYER_ROLES_ASSIGNED redraws. Codex's Modules/Buffs/Conditions.lua is this file.
- Camp buffs (Party.lua `ns.CAMP_BUFFS`, 2026-11-22): WoW Forever's camp features give "Boosted ..." auras that don't
  stack with a class buff (Forever wiki, Camping). By spell ID (two are named "Boosted Stats"): ReadBuffs keeps
  `spellId`, ScanUnit fills `camps[unit]`, `Remaining()` counts a camp buff as its family (not `HasAnyBlessing`: a
  camp buff isn't another paladin's blessing). IDs from Forever's SpellName / SpellEffect tables (wago.tools `wowf`).
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
  Resurrection (2026-11-21, the user's request; the same code in Codex's copy): `ns.NeedsRes(unit)` = online, not
  you, `UnitIsDead` and not `UnitIsGhost` (a released spirit can't be raised by a spell; secret answers = no);
  such a member gets one button (`button.res`) with `ns.ResSpell()` (first known of `ns.RES_SPELLS`) instead of
  buffs / dispels. Dimmed (0.4, grey) while `UnitHasIncomingResurrection`; `INCOMING_RESURRECT_CHANGED` redraws.
  Option `party.res` (nil = on, "Resurrect the dead"). Deaths are seen by the 1 sec refresh; in combat nothing
  secure changes, as for every button. Codex's copy colours with `ns.GREY` / nil (it has no `ns.T` colours).
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
- `Share.lua` (2026-11-28, the user's request: paladins share blessing assignments like PallyPower; **the same file
  in Codex's Modules/Buffs**: `ns = root.buffs` when `root.buffs.codex == root`, else root, since Buff Tracker's
  `ns.buffs` is the player's buff list): prefix `ns.SHARE_PREFIX` "TylesserBless", messages `1:H:CLASS=code,...`
  (resets the sender), `1:M:Name-Realm=code,...` (group members only), `1:Q`, `1:X`; codes M W K S L Y N (none or
  not known). Channel RAID / PARTY / INSTANCE_CHAT. Nothing is sent while `InCombatLockdown`, forever
  `C_ChatInfo.InChatMessagingLockdown` or `AreOutgoingAddonChatMessagesRestricted` (sent at PLAYER_REGEN_ENABLED);
  CHAT_MSG_ADDON is `SecretInChatMessagingLockdown`, so secret prefix / text / sender are dropped before any compare.
  Sends only when the state changed (or forced: joining, a new member, a query), coalesced by `Later` (C_Timer).
  Received from group members only, never yourself (`SameName`: first word of the name, Forever names may carry
  a surname, plus the realm); `ns.shared[lower Name-Realm] = { full = sender's spelling, name, classes, members }`,
  forgotten on GROUP_ROSTER_UPDATE when they leave (all when you leave). Party.lua `BlessingsFor` (only with
  `allBlessings`): extras skip a blessing another sharer gives that member (`ns.TakenByOther(unit, key)`), and the
  chosen one is given up to a sharer with the same choice whose Name-Realm sorts first (`chosen = true`; both
  sides decide alike, so exactly one keeps it). `ns.ShareConflicts()` (every class + group members with an own
  choice on either side), chat once per clash that matters in the group (`WarnConflicts`), `ns.ShareLines()` for
  the page (third column "Other paladins" in PartyOptions.lua, Codex: under the member list). `party.share` (nil =
  on, "Share my blessings"). Events from Events.lua's `shareFrame` (`ns.SHARE_EVENTS`); `ns.PartyDirty()` lays out
  without a new frame search; `ns.PartyChanged()` calls `ns.ShareChanged()`.
- `NextBuff.lua` (2026-11-28, the same file in Codex): one key for the next missing buff. Hidden secure button
  `ns.NEXT_BUTTON_NAME` (BuffTrackerNextBuff / CodexBuffsNextBuff, so `/click` works), made the first time there is
  something to cast or a key; `ns.LayoutNextBuff(shown)` from Display.lua's LayoutClicks (same `ns.ClickAction`
  as the icon: first shown entry that is known missing, not unwanted, with an action; nil while unlocked),
  `ns.ClearNextBuff()` at PLAYER_REGEN_DISABLED (the key does nothing in a fight, like the icons). Key `db.nextKey`
  = override binding (`ns.ApplyNextKey`, waits for combat's end: `ns.NextKeyPending`), picker `ns.SetupNextKeyButton`
  (Options.lua's third column; Codex: under the size and shape buttons).
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
- **Hidden debuffs in combat (2026-11-27, the user's screenshot: no dispel icon in a fight):** on Forever a debuff's
  `name` / `dispelName` are secret in a fight, so `ReadDebuffs` skipped every one. Now, when anything was hidden (index
  secret, aura table / name / type secret, or `ShouldAurasBeSecret`), `C_UnitAuras.GetUnitAuraInstanceIDs(unit,
  "HARMFUL|RAID")` (plain IDs; "RAID" + HARMFUL = what the player can dispel, forever AuraUtil.AuraFilters) adds a
  `{ hidden = true }` per ID not read (readable ones by `auraInstanceID`). `RemovableDebuffs`: hidden -> the only known
  dispel, or `ns.ANY_DISPEL` with several (a combat icon after the others, never a lit button: the spell is unknown;
  `ns.DispelSpellFor` gives range/mana from the first dispel). Icons for hidden ones = the spell's (`ns.DebuffIcon`);
  nothing secret is kept. Tooltip and debug lines cope with no name/type. Tests: `codex_buffs_test` "hidden:".
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
