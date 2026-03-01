-- TradeDB_Examples.lua
--
-- This file is NOT required by the addon. It is a reference sheet that documents the
-- saved-variable layout used by the Trade tab for each trade section:
--   - Deposit
--   - Buy
--   - Sell
-- and how Account / Realm / Character scope and disable flags are stored.
--
-- Notes:
-- - The real tables live inside saved variables (DB and CHARDB) created in
--   fr0z3nUI_LootIt.lua.
-- - Keys are itemIDs (numbers). Some saved variable tables may serialize keys as
--   strings; the addon code normalizes with tonumber().
-- - For Deposit rules, values are boolean true (presence means enabled).
-- - For Buy/Sell rules, values are rule tables: { count = <number>, restock = <bool> }.
-- - Per-item Keep (Deposit mode) is stored in DB.deposit.keepByItem[itemID] = number.
--

--[[
================================================================================
ACCOUNT-WIDE (DB.deposit)  -- global/account saved variables
================================================================================

DB.deposit = {
  -- UI state
  tradeMode = "deposit" | "buy" | "sell",

  -- Deposit target selection
  -- "bank" = personal bank, "guild" = guild bank, "warbank" = warband bank
  target = "bank" | "guild" | "warbank",

  -- Guild tab selection
  guildTab = 0..8,                  -- 0 = current tab, otherwise tab index
  guildTabByRealm = { ["Realm"] = 0..8 },

  -- Per-item Keep (Deposit mode)
  -- If bags have less than Keep for an item, the addon may withdraw up to Keep.
  -- Keep does NOT apply globally; it is per itemID.
  keepByItem = {
    [19019] = 1,      -- Thunderfury (example)
    [1710]  = 40,     -- Greater Healing Potion (example)
  },

  -- Per-item Keep Scope (Deposit mode)
  -- "K" (default when unset): Keep in Bags
  --   - Deposits down to Keep in bags (so you keep the amount on your character)
  --   - May withdraw from the chosen target to top bags back up to Keep
  -- "S": Store in Bank
  --   - Deposits up to Keep into the chosen target
  --   - If the chosen target already has more than Keep, it will attempt to withdraw the excess back to bags
  -- Notes:
  -- - If keepScopeByItem[itemID] is nil/absent, behavior defaults to "K".
  -- - Store-scope excess withdraw requires free bag space.
  keepScopeByItem = {
    [1710] = "K",
    [19019] = "S",
  },

  ------------------------------------------------------------------------------
  -- DEPOSIT RULES (Account scope)
  ------------------------------------------------------------------------------
  -- Account deposit allow-list
  itemsAcc = {
    [1710]  = true,
    [5512]  = true,
  },

  -- Explicitly disable the Account rule everywhere
  itemsAccDisabled = {
    [5512] = true,
  },

  -- Disable the Account rule on specific realms
  -- (This table is used as DB.deposit.itemsAccDisableRealm[realmKey][itemID] = true)
  itemsAccDisableRealm = {
    ["Area 52"] = {
      [1710] = true,
    },
  },

  -- Realm-scoped deposit allow-lists (stored under the current realm key)
  -- (Realm scope is additive, and can be disabled per realm)
  itemsRealm = {
    ["Area 52"] = {
      [6948] = true,
    },
  },
  itemsRealmDisabled = {
    ["Area 52"] = {
      [6948] = true,
    },
  },

  ------------------------------------------------------------------------------
  -- BUY RULES (Account scope)
  ------------------------------------------------------------------------------
  -- Values are { count = number, restock = bool }
  buyItemsAcc = {
    [1710] = { count = 40, restock = true },
    [3775] = { count = 10, restock = false },
  },

  -- Disable an Account buy rule everywhere
  buyItemsAccDisabled = {
    [3775] = true,
  },

  -- Disable Account buy rules on specific realms
  buyItemsAccDisableRealm = {
    ["Area 52"] = {
      [1710] = true,
    },
  },

  -- Realm-scoped buy rules
  buyItemsRealm = {
    ["Area 52"] = {
      [1710] = { count = 20, restock = true },
    },
  },
  buyItemsRealmDisabled = {
    ["Area 52"] = {
      [1710] = true,
    },
  },

  ------------------------------------------------------------------------------
  -- SELL RULES (Account scope)
  ------------------------------------------------------------------------------
  -- Values are { count = number, restock = bool }
  -- (Count is the target you want to keep; excess can be sold, depending on logic.)
  sellItemsAcc = {
    [2459] = { count = 0, restock = false },
  },

  sellItemsAccDisabled = {
    [2459] = true,
  },

  sellItemsAccDisableRealm = {
    ["Area 52"] = {
      [2459] = true,
    },
  },

  sellItemsRealm = {
    ["Area 52"] = {
      [2459] = { count = 5, restock = false },
    },
  },
  sellItemsRealmDisabled = {
    ["Area 52"] = {
      [2459] = true,
    },
  },

  ------------------------------------------------------------------------------
  -- OPTIONAL: Guild deposit enabled/disabled per guild
  ------------------------------------------------------------------------------
  -- guildEnabled[guildKey] = false disables guild deposit entirely for that guild.
  -- The guildKey format is produced by addon helper(s) (guildName+realm, etc.).
  guildEnabled = {
    ["MyGuild-Area 52"] = true,
  },
}


================================================================================
CHARACTER-SCOPED (CHARDB.deposit)  -- per-character saved variables
================================================================================

CHARDB.deposit = {
  ------------------------------------------------------------------------------
  -- DEPOSIT RULES (Character scope)
  ------------------------------------------------------------------------------
  itemsChar = {
    [1710] = true,
  },
  itemsCharDisabled = {
    [1710] = true,
  },

  -- Disable inherited Account/Realm deposit rules on this character
  disableAcc = {
    [5512] = true,
  },
  disableRealm = {
    [6948] = true,
  },

  ------------------------------------------------------------------------------
  -- BUY RULES (Character scope)
  ------------------------------------------------------------------------------
  buyItemsChar = {
    [1710] = { count = 20, restock = true },
  },
  buyItemsCharDisabled = {
    [1710] = true,
  },

  -- Disable inherited Account/Realm buy rules on this character
  buyDisableAcc = {
    [3775] = true,
  },
  buyDisableRealm = {
    [1710] = true,
  },

  ------------------------------------------------------------------------------
  -- SELL RULES (Character scope)
  ------------------------------------------------------------------------------
  sellItemsChar = {
    [2459] = { count = 0, restock = false },
  },
  sellItemsCharDisabled = {
    [2459] = true,
  },

  -- Disable inherited Account/Realm sell rules on this character
  sellDisableAcc = {
    [2459] = true,
  },
  sellDisableRealm = {
    [2459] = true,
  },
}


================================================================================
SCOPE RESOLUTION QUICK GUIDE (what the UI is toggling)
================================================================================

- Account rule present (enabled)        => item is in DB.deposit.<mode>ItemsAcc
- Account rule disabled (global)        => DB.deposit.<mode>ItemsAccDisabled[itemID] = true
- Account rule disabled on realm        => DB.deposit.<mode>ItemsAccDisableRealm[realm][itemID] = true

- Realm rule present (enabled)          => DB.deposit.<mode>ItemsRealm[realm][itemID] = rule/true
- Realm rule disabled (on that realm)   => DB.deposit.<mode>ItemsRealmDisabled[realm][itemID] = true
- Realm rule disabled on character      => CHARDB.deposit.<mode>DisableRealm[itemID] = true

- Character rule present (enabled)      => CHARDB.deposit.<mode>ItemsChar[itemID] = rule/true
- Character rule disabled               => CHARDB.deposit.<mode>ItemsCharDisabled[itemID] = true
- Character disables inherited account  => CHARDB.deposit.<mode>DisableAcc[itemID] = true

Where <mode> is one of:
- deposit: "items*" tables with boolean true values
- buy:     "buyItems*" tables with {count, restock}
- sell:    "sellItems*" tables with {count, restock}

Per-item Keep (Deposit only):
- DB.deposit.keepByItem[itemID] = keepNumber

]]
