# fr0z3nUI_LootIt — Changelog

Format: `YYMMDD-###` (sanity stamp) — short summary.

## 260312-059
- Loot UI: moved the bottom “supported message lines” scroll + the Other-tab format examples into an `Info` popout opened from the LootIt tab.
- Loot UI: moved Achievement/Experience/Professions controls (toggles + routing dropdowns + Bonus + XP Before/After) to the bottom of the LootIt tab.
- Loot UI: moved the Experience Debug toggle to the bottom of the LootIt tab.
- UI: moved Alias tab contents into an `Alias` popout opened from the LootIt tab, and hid the Alias tab.
- Files: `fr0z3nUI_LootItLoot.lua`, `fr0z3nUI_LootItUI.lua`, `fr0z3nUI_LootItOther.lua`.

## 260312-060
- Loot UI: tightened LootIt tab spacing so the moved Achievement/Experience/Professions controls sit with the rest of the tab (less dead gap).
- Loot UI: Experience Debug button now matches the Tax tab Debug button style/behavior (short button, label stays `Debug`, green=on / gray=off) and no longer overlaps Reload UI.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-061
- Loot UI: Info popout now uses the standard right-docked popout style (with a close button) instead of a centered modal.
- Loot UI: `Alias` and `Info` buttons are now aligned with `Reset Defaults` (Alias left, Info right) to prevent overlaps.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-062
- Loot UI: Achievement/Experience/Professions output dropdowns are now compact to match the main `Output` dropdown (same width), with border removed, left-aligned text, and full-clickable area.
- Loot UI: Output dropdown label is now sanitized (e.g., strips trailing parenthetical info) to avoid awkward truncation like "Balanced (20 F...".
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-063
- Loot UI: main `Output` dropdown now also uses the compact dropdown styling (borderless, left-aligned, click-anywhere), matching the other output dropdowns.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-064
- Loot UI: moved the Achievement/Experience/Professions controls back to sit directly under `Reset Defaults` (prevents overlap without pushing them to the very bottom).
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-065
- Loot UI: shortened all output dropdowns (Output/Achievement/Experience/Professions) by ~10% on each side (narrower dropdown column).
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-066
- Loot UI: moved the Achievement/Experience/Professions row slightly lower under `Reset Defaults`.
- Loot UI: aligned Achievement/Experience/Professions button text with the dropdown text (without left-justifying the button labels).
- Loot UI: shortened all output dropdowns again (narrower by another ~10% on each side).
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-067
- Loot UI: reverted left-justified Achievement/Experience/Professions labels; text remains centered, with vertical alignment matched to the dropdown text.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-068
- Loot UI: moved the output dropdown column slightly left.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260313-001
- Loot UI: nudged Achievement/Experience/Professions buttons down slightly so their labels align with the dropdown text.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260313-002
- Loot UI: removed borders from the `Loot In Line` and `Prefix` input boxes.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260313-003
- Loot UI: added mouseover highlight to all output dropdowns and made click toggle the dropdown open/close.
- Loot UI: added mouseover highlight to the borderless `Loot In Line` and `Prefix` input boxes.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260313-004
- Loot UI: moved Achievement/Experience/Professions and Experience `Bonus`/`Before` buttons down slightly so button text aligns with dropdown text.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260313-005
- Loot UI: moved Experience `Bonus` left slightly without moving the `Before/After` button.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260313-006
- Loot UI: moved Experience `Bonus` to the right (without moving the `Before/After` button).
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260313-007
- Loot UI: nudged Achievement/Experience/Professions and Experience `Bonus`/`Before` buttons down a bit more for cleaner text alignment with dropdowns.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260313-008
- XP chat: pad XP numbers to a fixed width so values (and the `*` marker) line up vertically.
- Files: `fr0z3nUI_LootItLootChat.lua`, `fr0z3nUI_LootIt.toc`.

## 260313-008
- Loot UI: fixed dropdowns toggling open+closed on a single click (double-toggle); dropdowns now toggle once per click.
- Files: `fr0z3nUI_LootItLoot.lua`.

## 260312-022
- Other: Achievement/Experience are now text toggle buttons (Tax/Vendor style), and output routing is split into separate (shorter) dropdowns for Achievement vs Experience.

## 260312-023
- Debug: `/fli status` and `/fli chatdebug dump` now print the addon `## Version`.

## 260312-024
- Debug: `/fli capture status` and `/fli capture dump` now also print the addon `## Version`.

## 260312-025
- Other: output dropdowns now display the selected chat frame label (no more “Custom”), and the Experience Debug button is now a Tax-style text toggle (on/off, no prints).

## 260312-026
- Other: Experience Debug button now matches the Tax tab Debug button look (same button template + green/gray text state).

## 260312-027
- Other: Experience Debug toggle now shows explicit state as `Debug On` / `Debug Off` (still no chat printing).

## 260312-028
- Other/Experience: when Debug is On, XP events now print a minimal `[LootIt XP]` line (match/no-match + output frame) to help diagnose why XP rewrite output isn’t showing.

## 260312-029
- Other/Experience: `[LootIt XP]` debug lines now print to the Experience output chat frame (matches the Experience dropdown).

## 260312-030
- Other/Experience: XP parser now tolerates locale number separators (spaces/dots/apostrophes) and strips common chat formatting; XP debug no-match now includes a short message snippet.

## 260312-031
- Other/Experience: XP parser now matches discovery XP lines ("Discovered ...: N experience gained") and is more tolerant of separators in the fallback patterns.

## 260312-032
- Other/Experience: XP parsing now normalizes common Unicode spaces (NBSP variants) so visually-correct XP lines match reliably.

## 260312-033
- Other/Experience: fallback XP match patterns now tolerate non-standard punctuation around "dies," and trailing "experience." so common XP lines match even with lookalike Unicode punctuation.

## 260312-034
- Other/Experience: XP output now uses the normal LootIt self-name formatting (no more `< >` around the character name).

## 260312-035
- Other/Experience: XP fallback patterns no longer swallow the rested-bonus parentheses (fixes no-match on lines like "X dies, you gain N experience. (+M exp Rested bonus)"); CHAT_MSG_SYSTEM parsing now ignores unrelated system lines to reduce debug noise.

## 260312-036
- Other/Experience: added `PLAYER_XP_UPDATE` fallback so if an XP gain line fails to parse, LootIt can still reprint the correct XP delta without relying on localized text.

## 260312-037
- Other/Experience: bonus/rested parsing is more tolerant of parenthetical formats (e.g. "(425 rested bonus)" without "+"/"exp") and now probes additional Blizzard XP global-string variants when present.

## 260312-038
- Other/Experience: XP parsing now normalizes fullwidth/lookalike parentheses (e.g. "（...）") so rested/bonus suffixes match reliably.

## 260312-039
- Other/Experience: added a more tolerant fallback XP matcher (case-insensitive "you gain N experience" + optional "<mob> dies" extraction) to avoid persistent no-match on visually-correct kill XP lines.

## 260312-040
- Other/Experience: de-duplicated XP reprints when the same gain fires on multiple chat events (prevents double-prints per kill).

## 260312-041
- Other: added Professions as a new Other-tab option (toggle + output dropdown). It captures `CHAT_MSG_SKILL` lines (e.g. skill-ups / learned profession) and reprints them in LootIt format.

## 260312-042
- Other/Professions: now also matches common profession learn/skill-up lines when they arrive on `CHAT_MSG_SYSTEM` (some clients) and includes tolerant fallback patterns if the Blizzard global string keys differ.

## 260312-043
- Other/Professions: rank-up reprint format is now `Skill +1 (8)` style (prints `+Δ (Rank)` when previous rank is known).

## 260312-044
- Other/Experience: added a `Bonus` toggle next to the Experience output dropdown to show/hide the bonus chunk; when hidden, bonus is indicated by a `*` marker.
- Other/Experience + Other/Professions: added light coloring to the reprinted lines using Blizzard font color codes.

## 260312-045
- Other/Experience: added a tooltip to the `Bonus` toggle.

## 260312-046
- Other/Experience + Other/Professions: fixed missing color by adding safe fallbacks for Blizzard color codes; profession rank-up output now shows `+? (Rank)` instead of bare `(Rank)` when the previous rank is unknown.

## 260312-047
- Other/Experience + Other/Professions: force the highlight color to use Blizzard gold (and fall back to `|cffffd100`) so XP/profession text can’t silently degrade to white.

## 260312-048
- Other/Professions: persist last known skill rank per character so the first skill-up after `/reload` can show `+Δ (Rank)` instead of `+? (Rank)`.

## 260312-049
- Other/Experience: XP amount is now green; bonus indicator is gold (either `*` when hidden or `(+N XP)` when shown).

## 260312-050
- Loot: normalize profession-quality (rank) icons in gathered item links so they stay vertically centered and don’t increase chat line height.

## 260312-051
- Loot: print the profession-quality (rank) icon before the item name so `xN` quantities appear directly after the item.

## 260312-052
- Loot UI: added a `Quality` toggle next to “Show Loot Only Line” to show/hide the profession-quality icon on gathered items.
- Loot UI: added a `Before`/`After` toggle (shown only when Quality is enabled) to control whether the icon prints before or after the item name.

## 260312-053
- Other/Experience: keep the literal `XP` text gold while the XP number is green (matches professions style).

## 260312-054
- Loot/Quality: fix Before/After placement and normalize the quality icon size so it no longer increases chat line height.

## 260312-055
- Loot/Quality: broaden quality icon detection so the Before/After toggle works across more Blizzard icon variants.

## 260312-056
- Debug: `/fli capture dump raw` now prints dumps with escaped pipes so you can see literal `|A:...|a` / `|T...|t` markup (instead of it rendering icons/links).
- Loot/Quality: made quality icon extraction tolerant of more atlas/texture parameter variants and less strict about token naming, fixing Before/After placement and the extra chat line height gap.

## 260312-057
- Loot: tolerate new Retail loot hyperlink prefixes like `|cnIQ1:` and recover quantity suffixes formatted as `|rx2` (no space), improving consistent rewrite/suppression for gathered-item quality lines.

## 260312-058
- Other/Experience UI: added a `Before`/`After` toggle next to `Bonus` to control whether the literal `XP` label prints before or after the green XP number.
- Other/Experience: XP label position also applies inside the bonus chunk (e.g. `(+47 XP)` vs `(+XP 47)`); bonus marker/chunk remains after the main number.

## 260312-021
- Other/Experience: added a bottom-left Debug button that runs `/fli capture` dumps filtered for XP/experience lines (quickly shows what the parser is seeing/outputting).

## 260312-007
- Trade Purchase UI: Target count now commits on focus-loss (click-away), not only on Enter (fixes “rules show up but never buy” when Target wasn’t applied).

## 260312-008
- Trade debug: Debug button now safely initializes `LI` (prevents silent errors) and merchant restock prints a one-time summary when debug is enabled (helps diagnose “no purchases”).

## 260312-009
- Trade debug: merchant restock now also prints the selected buy itemID + merchant index (and common blockers) for the first evaluated rule.

## 260312-010
- Trade debug: Debug toggle now forces merchant debug summary to print immediately (no more Off→On kick needed).
- Restock buying: removed the "must be usable right now" gate (level requirement still enforced), to avoid false blocks (combat/state/etc.).
- Vendor pickup: tooltip parsing now strips color/texture codes and tolerates leading text before `Use:` to improve food/drink matching.
- Trade debug: merchant restock now prints why fallback-to-exact-item was blocked (cache/reqLevel/playerLevel/usable).

## 260312-016
- Trade UI: Items popout open/close is now deterministic (fixes “opens once then won’t reopen until switching scopes” by preventing a stuck 0-width/shown state).

## 260312-017
- Other: added Experience capture/output (routes XP gain lines to the Other output chat frame and rewrites to formats like `<Character> 1234 XP` and `<Character> 94 XP (+47 XP) Mob`).

## 260312-018
- Other: Experience now also captures the creature-kill XP line reliably (some clients emit it as `CHAT_MSG_COMBAT_MISC_INFO` instead of `CHAT_MSG_COMBAT_XP_GAIN`), and rested-bonus parsing is more tolerant.

## 260312-019
- Other: Experience capture now uses Blizzard's `COMBATLOG_XPGAIN_*` global-string patterns (localized, more reliable) and also listens on `CHAT_MSG_SYSTEM` as a fallback.

## 260312-020
- Other: Experience now writes its incoming/outgoing lines into `/fli capture` (including the real event name and a no-match marker) so we can debug the exact message source without guessing.

## 260312-012
- Trade Purchase (restock): restock-group seed selection now prefers usable/lower-level rules (prevents one high-level item from blocking the entire restock group).

## 260312-013
- Trade debug: Debug toggle now persists across /reload (stored in account settings).

## 260312-014
- Trade Purchase (restock): if no equivalent vendor food/drink match is found, now attempts to buy the exact configured item when this merchant sells it (prevents `buyID=nil`).

## 260312-015
- Trade Purchase (restock): food/drink tooltip parser now accepts instant % restores (no duration text), improving vendor item matching.

## 260312-006
- Trade Purchase UI: widened the Items popout (Purchase only) and added columns for required level + food/drink health% + mana%.

## 260312-005
- Trade Purchase (restock): fixed required-level detection (was incorrectly reading itemLevel from `GetItemInfo`, which could block all buying).

## 260312-004
- Trade Purchase (restock): required-level gating now correctly treats "no level requirement" as usable (fixes restock not buying anything when items have requiredLevel=0).

## 260312-003
- Trade Purchase lists: when adding an item to buy/restock, now prewarms item cache (Use: tooltip parse + required level) so restock works immediately and won’t buy items above your level.

## 260312-002
- Trade Purchase (restock): when item info is uncached, now requests item data and keeps the merchant ticker alive until it can evaluate required level (fixes “not buying anything now” after adding the level gate).

## 260312-001
- Trade Purchase (restock): if item tooltip/item info isn’t cached yet, restock can fall back to buying the configured itemID instead of buying nothing (but will NOT buy items you can’t use yet).
- Trade Purchase: merchant scan ticker now idles longer before stopping (helps cache warm up).

## 260311-001
- Tax UI: renamed WarBank “EB” toggle to “XS” and updated tooltip text (“Pays Excess to WarBank”).

## 260311-002
- Tax UI: Min Gold input shortened (~33%) and XS moved closer to WarBank.

## 260311-003
- Tax UI: XS now uses the short button width (same as Debug) and sits flush against the left side of the Min Gold input.

## 260310-001
- Tax UI: added WarBank “EB” (Everything But Min) toggle between WarBank and Min Gold (only shown when WarBank is enabled; default off).
- Tax (WarBank): when EB is enabled, deposits owed first, then deposits any remaining gold above Min Gold into the WarBank.

## 260309-001
- Tax UI: removed Pay Now/Auto Pay controls (auto-pay only); moved owed-scope text into the owed tooltip.
- Tax: added optional WarBank tracking + auto-pay on account bank open; WarBank uses character-only owed with its own Clear Due.

## 260305-001
- Tax tab UI revamp: borderless Tax% input, centered due/total, text-toggle sources, unified buttons, added Reload UI.
- Added per-character Min Gold (default 2000g): keeps a minimum in bags; deposits only above Min Gold; can auto-borrow from guild bank to reach Min Gold and adds that amount to Due.
- System money parsing now reuses LootChat's money detection/parsing when available.

## 260305-002
- Tax: added Account/Character scope button (character remembers its own scope + settings).
- Tax: Guild enable list is now separate from Trade (uses detected guilds list, but stores its own enabled flags).
- Tax UI polish: centered Vendor/Looted/Mail/System row; centered Auto Pay/Pay Now row; System label simplified with tooltip warnings.

## 260305-003
- Tax UI: show a "%" suffix inside the Tax% input after entry.
- Tax UI: Min Gold now shows an in-box gold "g" suffix (not an outside icon).
- Tax UI: Due display uses gold/silver/copper icon formatting with per-coin colors and double spaces after gold/silver icons.

## 260305-004
- Tax UI: Tax% now renders as inline `51%` (suffix placed immediately after the centered number, not right-aligned).
- Tax UI: Min Gold input now uses an inline gold coin icon after the number and the input text color matches the gold used in the Due display.

## 260305-005
- Tax UI: standardized Tax tab buttons to match FGO Reload UI sizing (90x22), including Vendor/Looted/Mail/System and action buttons.

## 260305-006
- Tax UI: moved Guild under Vendor and Clear Due under System, aligned on the same row as Auto Pay/Pay Now.

## 260305-007
- Tax UI: even vertical spacing for Tax% / Min Gold / Due between the Scope button and the source buttons row.

## 260305-008
- Tax: scope model refactor — Guild is now the primary scope (per-guild settings + per-guild due/paid); Character remains an override.
- Tax UI: removed the guild enable-list popout/button; added a detected guild-name textbox above the scope button.

## 260305-009
- Tax UI: owed amount now refreshes immediately after a guild bank deposit completes.
- Tax UI: scope button moved above the guild display box; Tax% / Min Gold / Owed remain evenly spaced down to the source/action buttons.

## 260305-010
- Tax UI: Auto Pay / Pay Now / Clear Due are now evenly spaced across the action row.

## 260305-011
- Tax UI: guild name display is now flush under the Scope button.
- Tax UI: Auto Pay / Pay Now / Clear Due now align under the gaps between Vendor/Looted/Mail/System.

## 260305-012
- Tax UI: moved the action buttons row down by one button height to better visually link the source toggles with the owed amount.

## 260305-013
- Tax UI: Scope button is now all-caps, gold, and slightly smaller.
- Tax UI: added a per-character "Withdraw" toggle (above System) to enable/disable withdrawing from the guild bank to meet Min Gold.
- Tax UI: improved Tax% input (numeric-only sanitization) and increased the % suffix visibility.
- Tax UI: adjusted coin icon sizing/offsets and spacing in the owed line; added extra spacing before the Min Gold icon.

## 260305-014
- Tax UI: Withdraw toggle positioned in line with the Min Gold input (without shifting the action buttons row).

## 260305-015
- Tax UI: moved Pay Now above Vendor (in line with owed) and Clear Due above System (in line with owed), styled as text toggles.
- Tax UI: moved Auto Pay to the bottom-left corner.
- Tax UI: tweaked coin icon sizing/offsets to better align with the Min Gold input and owed display text.

## 260305-016
- Tax UI: moved Min Gold + Withdraw below the source buttons and closed the vertical gap above.
- Tax UI: restored Auto Pay as a normal button (UIPanelButtonTemplate).
- Tax UI: adjusted coin icon baseline offset again for better alignment.

## 260305-017
- Tax UI: rewrote owed display to use real textures + fontstrings (better coin baseline alignment; no inline texture string).
- Tax UI: rebalanced the middle layout (sources → owed/actions → min/withdraw) for more even spacing; bottom buttons unchanged.

## 260305-018
- Tax: guild-bank withdrawals for Min Gold are now tracked as a separate debt bucket.
- Tax: debt cannot be cleared via Clear Due, accrues 11.49% APR interest over time, and is paid AFTER normal tax due.
- Tax: Pay Now works for debt repayment even if Tax% is 0.

## 260301-002
- Removed the Tabard module from LootIt (moved to GameOptions).
- Added a new “Tax” tab/module (LuxGold-like contributions with safer vendor/mail handling).

## 260301-001
- Trade DB examples: documented `DB.deposit.keepScopeByItem[itemID] = "K"|"S"` behavior.
- Store-scope (S) excess-withdraw: clearer chat warning when blocked due to full bags.
- Added sanity stamp to `/fli status`.
- Bumped TOC `## Version` to `2026.03.01`.
