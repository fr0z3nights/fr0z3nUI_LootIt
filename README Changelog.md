# fr0z3nUI_LootIt — Changelog

Format: `YYMMDD-###` (sanity stamp) — short summary.

## 260310-001
- Tax UI: added WarBank “EB” (Everything But Min) toggle between WarBank and Min Gold (only shown when WarBank is enabled; default off).
- Tax (WarBank): when EB is enabled, deposits owed first, then deposits any remaining gold above Min Gold into the WarBank.

## 260311-001
- Tax UI: renamed WarBank “EB” toggle to “XS” and updated tooltip text (“Pays Excess to WarBank”).

## 260311-002
- Tax UI: Min Gold input shortened (~33%) and XS moved closer to WarBank.

## 260311-003
- Tax UI: XS now uses the short button width (same as Debug) and sits flush against the left side of the Min Gold input.

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
