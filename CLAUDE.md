# BuffTracker ("Tylesser - Buff Tracker")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from BuffTracker.toc)

- `Tylesser.lua`: the shared Tylesser "Runestone" look (`ns.T`: stone panels, gold borders, studs, Cinzel, buttons,
  check boxes, options page header, chat prefix). Loaded first. The same file is in every Tylesser addon: edit them together
  (see the workspace CLAUDE.md).
- `Core.lua`: defaults for `BuffTrackerDB` (`SavedVariablesPerCharacter`: `tracked`, `locked`, `iconSize`, and `x`, `y` once the row has been moved; before that it sits at the top center of the screen), reading
  the player's buffs, `ns.state` per lowercase buff name, adding and removing buffs, and the spellbook list for the
  options page. A tracked entry is `{ name, icon, mode }`, where mode is `always`, `active` or `missing`.
- `Display.lua`: the row of icons, centered on a draggable anchor, and `ns.Tick` (countdown and rescans).
- `Party.lua`: party buff buttons. `ns.GROUP_BUFFS` and `ns.BLESSINGS` list each buff "family" (group spell first,
  then the single-target one; English spell names; reagent item IDs only for the tooltip). `ns.ChooseSpell` takes the
  first known spell that `IsUsableSpell` allows (low mana doesn't count). Buttons are `SecureActionButtonTemplate`
  (type spell, unit partyN), 4 per unit, anchored beside the unit's frame found by scanning Blizzard party frames,
  raid-style/raid frames, the `PartyFrame` pool, ElvUI and FlareUI (`FlareUI_Party0`-`4`) by name first. Party members
  still without a frame are searched with `EnumerateFrames` (visible frame with `unit` attribute exactly `partyN` or the
  same person's `raidN`, at least 30x12, never our own buttons), cached, and retried with a growing wait (3 to 60 sec,
  reset on roster changes). `PlayerFrame` is never used and the search skips the player. Saved in `BuffTrackerDB.party`:
  `enabled`, `refresh` (default on) + `refreshSeconds` (`ns.REFRESH_CHOICES`, default 60; 1.0.0's `soon` is dropped), `off[family]`, `classes[CLASS]` and `members[name]` (blessing key or "none"; members win).
- `Options.lua`: canvas page in Blizzard's settings: tracked buffs on the left, buffs and spells to add on the right.
- `PartyOptions.lua`: "Party buffs" sub-page: group buff on/off boxes, blessing per class and per party member
  (cycle buttons, no dropdowns).
- `Events.lua`: `ADDON_LOADED` setup, `UNIT_AURA` updates, the 0.2 second tick and the slash commands `/btrack` and
  `/bufftracker` (`debug` prints `ns.PartyDebug()`: frame, buffs and buttons per party member).

## Rules

- New buffs default to "When missing": the user wants the icons as a reminder of what's not on them.
- Buffs are matched by name, never by spell ID, so every rank of a spell counts. A typed spell ID is turned into its name.
- **Secret values:** Retail hides aura data from addons at times, and addons installed on Forever check for this too
  (`issecretvalue`, `C_Secrets`). When Forever actually hides buffs still needs checking in game. Asking for auras while `C_Secrets.ShouldAurasBeSecret()` is true is an error, and comparing a secret value is an error.
  Keep every aura read behind the checks in `ReadBuffs`. A buff that can't be read keeps its last state, and a timer
  that ends while buffs are hidden means "unknown" (grey), never "missing" (red).
- The on-screen icons don't take mouse clicks unless unlocked, so they can't block clicks in the world.
- The icon row is plain frames, not secure buttons: it can't cast spells and needs no combat handling.
- Party buttons are secure: never call Show, Hide, SetPoint or SetAttribute on them in combat
  (`InCombatLockdown()`). `ns.UpdateParty` only recolors in combat and lays out again on `PLAYER_REGEN_ENABLED`.
- Avoid UI templates that differ per client (sliders, dropdowns). The icon size uses plain buttons for this reason.
