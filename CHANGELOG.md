# Changelog

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
