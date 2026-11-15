<img src="branding/bufftracker-icon-512.png" width="96" align="right" alt="">

# Tylesser - Buff Tracker

A World of Warcraft addon that **reminds you when a buff is missing**. Choose the buffs you care about, like Righteous Fury, your blessings or an elixir, and an icon appears on screen whenever one of them isn't on you. In a group, **buttons appear next to your party and raid frames** for the buffs your group is missing: click one to cast it on that member.

## Features

- **You choose what to track.** Pick from the buffs on you right now or from the spells in your spellbook, search by name, or type a name or spell ID.
- **Class basics in one click.** The **Add <class> basics** button (or `/btrack basics`) tracks the basic buffs of your class that you know: Arcane Intellect and your best armor for mages, Power Word: Fortitude, Inner Fire and Divine Spirit for priests, Mark of the Wild and Thorns for druids, your best armor for warlocks, Battle Shout for warriors, Trueshot Aura and your aspect for hunters, your shield for shamans, and Devotion Aura and your blessing for paladins.
- **Every rank counts.** Buffs are matched by name, so any rank of a spell counts as that buff.
- **Choose when each buff shows:**
  - **When missing** (the default): only while it's not on you.
  - **When active:** only while it's on you.
  - **Always:** in full color while it's on you, dimmed with a red border while it's missing.
- **Click to cast.** Click the icon of a buff you know the spell for, like Arcane Intellect or a blessing, to cast it on yourself. This works out of combat: the game doesn't let addons change clickable buttons in combat, so the icons can't be clicked then. Turn it off on the options page if you'd rather the icons never take a click.
- **Click to use items.** For a buff you don't have the spell for, like an elixir or a scroll, clicking the icon uses the item of the same name from your bags. You can also choose the item yourself: click **Use item** under a tracked buff on the options page to go through the usable items in your bags (right-click for none; items you wear, like trinkets, aren't offered), or type `/btrack item Well Fed = Spiced Wolf Meat`. The icon shows how many you have left, with a red 0 and no click once they're gone.
- **Weapon enchants.** Track **Main-hand weapon enchant** or **Off-hand weapon enchant** (at the end of the list on the right) to see when your oil, poison or sharpening stone is missing. Choose the item under it, and a click puts it on that weapon.
- **Alert in combat.** Tick **Alert** under a tracked buff to hear the raid warning sound and see its icon flash when that buff drops during combat. This only works while the game lets addons see your buffs in combat (see below).
- **Time left and stacks** on icons of active buffs. The time turns red in the last minute.
- **Move and resize.** The icons start at the top of the screen. Drag the row wherever you want it, in Edit Mode or after unticking Lock position, and set the icon size.
- **Square or round.** Show the icons, and the buttons next to party frames, as squares with a gold border or as circles with a gold ring.
- **Saved per character,** because each class watches different buffs.

## Party buff buttons

When a party member is missing one of your group buffs, a small button with the buff's icon appears next to their party frame. Click it to cast the buff on them. The button goes away once they have it.

- **Group spell first, then the single one.** The button uses the group spell when you can cast it, and the single-target spell when you can't, usually because you're out of the reagent:
  - Arcane Brilliance (Arcane Powder) → Arcane Intellect
  - Prayer of Fortitude (Holy or Sacred Candle) → Power Word: Fortitude
  - Prayer of Spirit → Divine Spirit, Prayer of Shadow Protection → Shadow Protection (Sacred Candle)
  - Gift of the Wild (Wild Berries or Wild Thornroot) → Mark of the Wild
  - Greater Blessing (Symbol of Kings) → Blessing
- **Only where it helps.** Arcane Intellect and Divine Spirit aren't offered to warriors and rogues. Members who are dead or offline get no buttons.
- **Paladin blessings:** choose a blessing for each class, like Might for warriors and Wisdom for casters, and change it for single party members. A member's own choice is kept by name.
- **Every blessing when it helps (paladins):** when a member has no blessing at all, or another paladin already gave them the one you chose, a button appears for each blessing they don't have yet, so you can pick one that isn't taken. Once they have a blessing from you, the others go away. Turn this off on the options page to only see the chosen blessing.
- **The tooltip** shows who is missing the buff, how many reagents you have (in orange when you're running low), and when the single-target spell is used instead.
- **Low reagent warning:** a chat message such as "3 Symbol of Kings left." each time a reagent you use goes down to 5 or fewer. Pick 1, 3, 5, 10 or 20 on the Party buffs page, or Off. The reagents follow your game version: Wild Quillvine for Gift of the Wild on TBC, Wild Spineleaf and Devout Candle on Wrath, and no reagents from Mists of Pandaria on.
- **Colors:** red icon = out of range, blue icon = not enough mana.
- **Distance limit:** members farther than 60 yards get no buttons, so you only see buffs you can walk over and give. Closer members keep theirs, red while out of spell range. Pick 30, 40, 60, 80 or 100 yards on the options page, or untick the box to always show them. In dungeons and raids the game doesn't give addons exact positions, so there a member is hidden only once they're out of sight (about 100 yards), or past about 40 yards with a 30 or 40 yard limit.
- **Ending soon:** buffs that end within a minute also get a button, so you can refresh them in time. Click the time on the options page to pick 10 sec, 30 sec, 1 min, 2 min or 5 min, or untick the box to only show missing buffs.
- Works with Blizzard's party frames, raid-style party frames, ElvUI and FlareUI, and finds the party frames of most other unit frame addons too. Your own buffs are in the icon row, so your own frame gets no buttons, except in raid-style party frames.
- **In a raid** every member is covered, with small buttons in the top right corner of each raid frame (at most a third of its width). **Raid buttons hide during combat**, so a click on a raid frame always reaches the frame, for healing. Untick **Buttons on raid frames** on the Party buffs page to have none in raids.

**In combat** the game doesn't let addons add, move or remove these buttons. Buttons that are already there keep working, and a buff that lands only dims its button. Everything updates as soon as combat ends.

Turn each group buff on or off and set the blessings at Esc > Options > AddOns > Tylesser - Buff Tracker > Party buffs, or with `/btrack party`.

## Usage

Type `/btrack` to open the options, go to Esc > Options > AddOns > Tylesser - Buff Tracker, or pick Buff Tracker in the addon menu by the minimap. Click a buff on the right to track it, then use the button next to it to choose when it shows. To move the icons, open Edit Mode (Esc > Edit Mode) and drag the Buff Tracker row, or untick **Lock position** and drag them.

- `/btrack`: open the options
- `/btrack party`: open the party buff options (group buffs and blessings)
- `/btrack add <name or spell ID>`: track a buff
- `/btrack basics`: track the basic buffs of your class
- `/btrack item <buff> = <item>`: the item a click on that icon uses (name, item ID or shift-clicked link); `/btrack item <buff>` for none
- `/btrack remove <name>`: stop tracking a buff
- `/btrack list`: show the tracked buffs and their state
- `/btrack lock` / `/btrack unlock`: lock or move the icons
- `/btrack reset`: put the icons back at the top of the screen
- `/btrack debug`: show what the party buttons see (which frame each member has, and which buffs they're missing), useful for bug reports
- `/btrack feedback`: get the link to report a bug or suggest an idea

A name you type must match the buff's name, but capitals don't matter. If the game doesn't know the spell yet, the icon is a question mark until the buff first appears on you.

Related buffs count separately. Gift of the Wild doesn't count as Mark of the Wild, so track the one you use.

## When the game hides buffs

WoW Forever and Retail can hide buff details from addons at times, such as during combat. While buffs are hidden, each icon keeps what it last knew and keeps counting down. If the time runs out, the icon turns grey, because the addon can't tell whether the buff was refreshed. Everything updates again as soon as the game stops hiding buffs. While buffs are hidden the addon can't see one drop, so **Alert** can't go off then.

## Feedback

Found a bug or have an idea? Click **Feedback** on the options page or type `/btrack feedback` in game to get the link, or go straight to [tylesser.com/feedback](https://tylesser.com/feedback/#bufftracker).

## Installation

Install from CurseForge, or download the latest zip from [Releases](https://github.com/Tylesser/BuffTracker/releases) and extract it to `Interface/AddOns`. The folder must be named `BuffTracker`.

## Releasing (maintainers)

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager). Push a version tag to publish to GitHub Releases and CurseForge:

```
git tag v1.0.0
git push origin v1.0.0
```

## License

[MIT](LICENSE)
