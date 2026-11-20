# Changelog

## 1.8.0

- **Resurrect the dead.** When a party or raid member dies (and hasn't released), their buff buttons give way to one button with your class's resurrection spell (Resurrection, Redemption, Ancestral Spirit, Rebirth...): click it to raise them. It dims while someone else is already resurrecting them. Like every party button it appears out of combat. Untick **Resurrect the dead** on the Party buffs page to turn it off.

## 1.7.0

- **Choose where and when the row shows.** Click **Where the row shows** above the tracked list and tick the places (open world, cities and inns, dungeons, raids, battlegrounds and arenas), the group (solo, in a party, in a raid group) and the combat state (in and out of combat, only in combat, only out of combat) to show the icons in. For example: hidden in dungeons and raids, but shown in a party out in the world. A buff can have its own rules: click **Where** under it (its button turns green). While you move the row, every icon shows.

## 1.6.1

- **Blessings:** a party member with another paladin's blessing now gets your blessing button again. Before, another paladin's blessing could be taken for yours, and then no blessing button showed at all.

## 1.6.0

- **Dispel icons in combat:** the game doesn't let addons add clickable buttons during a fight, so a debuff you can remove that shows up in combat now gets a plain icon in the button's place instead, next to the party frame, in the corner of the raid frame, or under your icon row. It takes no clicks, so a click there reaches the frame under it. The empty spots that used to be made as combat started are gone. Dispel buttons now work in raids too (out of combat, like the buff buttons). New setting **Show dispel icons in combat** on the Dispels page, on by default.
- **Tracking buffs:** Find Minerals, Find Herbs and the other tracking abilities now count as active when they're on, and clicking their icon turns them on. Before, they always showed as missing and the click did nothing.

## 1.5.0

- **Dispel buttons:** when a party member has a debuff you can remove, like a poison or a curse, a button with its icon appears next to their party frame. Click it to cast your dispel on them. The same buttons for your own debuffs sit under your icon row.
- They follow the spells you know: a paladin with Purify gets Poison and Disease, and Magic too once they learn Cleanse. Works for paladins, priests, druids, shamans and mages, and from Mists of Pandaria on for every class with a dispel.
- They also work in combat: as a fight starts each member gets an empty spot for your dispels, which shows the debuff as soon as one you can remove appears.
- A new **Dispels** options page (`/btrack dispel`) turns the party and personal buttons on or off and lists your dispels.

## 1.4.0

- **Consumables:** click an icon to use an item. Items you wear, like trinkets, aren't offered, as a click would equip them. A buff you don't have the spell for, like an elixir or a scroll, uses the bag item of the same name. You can also choose the item yourself for any tracked buff on the options page (for example a food for Well Fed), or with `/btrack item <buff> = <item>`. The icon shows how many you have left.
- **Weapon enchants:** track your main-hand and off-hand weapon enchant (oils, poisons, sharpening stones), and click the icon to put your chosen item on that weapon.
- **Alert:** tick Alert under a tracked buff to hear a sound and see its icon flash when it drops during combat.
- **Raids:** the buff buttons now work for every raid member: small buttons in the top right corner of each raid frame. They hide during combat, so they never catch a click meant for healing. Turn them off with "Buttons on raid frames" on the Party buffs page.
- **Low reagent warning:** a chat message when a reagent of your group buffs (Arcane Powder, candles, Wild Berries and the like, Symbol of Kings) goes down to 5 or fewer, and the count shows in orange in the button tooltip. Set the number, or turn it off, on the Party buffs page.
- The reagents match your game version: Wild Quillvine on TBC, Wild Spineleaf and Devout Candle on Wrath, and none from Mists of Pandaria on.
- **Class basics:** a button on the options page (and `/btrack basics`) tracks the basic buffs of your class that you know, like Arcane Intellect and your best armor for mages.
- Buff Tracker is in the addon menu by the minimap, on clients that have it.

## 1.3.1

- A **More addons** button on the options page, and the feedback window points to tylesser.com for the other Tylesser addons.

## 1.3.0

- A Feedback button on the options page and a `/btrack feedback` command: they show the link to tylesser.com/feedback, where you can report a bug or suggest an idea.
- Icons can be shown as circles: the Shape button on the options page switches the icon row and the party buttons between squares and circles.
- The icon row can be moved in Edit Mode: while Edit Mode is open it shows all tracked icons and can be dragged.
- Click an icon in the row to cast that buff on yourself, for buffs you know the spell for. Works out of combat; can be turned off on the options page.
- Paladins: when a party member has no blessing, or another paladin already gave them the chosen one, a button shows for each blessing they're missing. On by default; turn it off on the Party buffs page.
- Up to 8 buttons per party member (was 4), to make room for the blessings.

## 1.2.0

- Party buff buttons hide for members farther than 60 yards. Closer members keep them, red while out of spell range. The distance can be set to 30, 40, 60, 80 or 100 yards, or turned off.
- `/btrack debug` also shows how far each member is.

## 1.1.0

- Party buff buttons now work with FlareUI, and with the party frames of most other unit frame addons.
- "Also show buffs that end within" is now on by default, and its time can be set: 10 sec, 30 sec, 1 min, 2 min or 5 min.
- `/btrack debug` shows what the party buttons see, for bug reports.

## 1.0.0

- First version.
- The Tylesser look shared by all Tylesser addons: stone and gold options pages, and icons and party buttons with gold borders (ruby when a buff is missing).
- Choose the buffs to track from the buffs on you or your spellbook, or by typing a name or spell ID.
- A row of icons at the top of the screen, which you can move, with time left and stacks. Each buff shows only when missing (the default), only when active, or always.
- The tracked list, position and icon size are saved per character.
- Party buff buttons: next to each party frame, a button for every group buff the member is missing. Click it to cast the buff on them.
- The group spell is used when you can cast it, otherwise the single-target spell (for example Arcane Brilliance without Arcane Powder becomes Arcane Intellect).
- Paladins choose a blessing per class and per party member.
- "Party buffs" options page: turn each group buff on or off, and optionally show buffs that end within a minute.
- Slash commands: `/btrack`, with `party`, `add`, `remove`, `list`, `lock`, `unlock` and `reset`.
