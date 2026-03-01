# fr0z3nUI LootIt

Loot chat cleaner + a small config UI. Also includes a Tax helper tab.

## Install
1. Copy the folder `fr0z3nUI_LootIt` into:
	- `World of Warcraft/_retail_/Interface/AddOns/`
2. Launch WoW and enable the addon.

## Slash Commands
- `/fli` or `/lootit` — open options
- `/fli ?` or `/fli help` — print command list

### Common toggles
- `/fli on|off|toggle` — enable/disable (account-wide)
- `/fli status` — print current status
- `/fli hide on|off` — hide matching loot text
- `/fli echo on|off` — echo your own loot lines
- `/fli selfname on|off` — always show your character name
- `/fli prefix <text>|default` — set/restore echo prefix (blank clears)

### Mail notifier
- `/fli mail on|acc|off|toggle|test`
- `/fli mail model player`
- `/fli mail model katy|dalaran|plagued`
- `/fli mail model npc <id>`
- `/fli mail model display <id>`
- `/fli mail model file <id>`

### Link aliasing
- `/fli alias list` — show aliases
- `/fli alias set [acc|char] <itemID> <text>`
- `/fli alias del [acc|char] <itemID>`

### Capture/debug
- `/fli capture on|off|status|dump [n] [filter]|clear|max <n>|stacks`
- `/fli repair` — reapply filters
- `/fli debugfilters` — print chat-filter install status

## Tax tab
- Configure the rate and sources in the “Tax” tab inside LootIt options.
- Optional auto-pay can deposit the due amount when opening the guild bank.

## SavedVariables
- Account: `fr0z3nUI_LootItDB`
- Character: `fr0z3nUI_LootItCharDB`
