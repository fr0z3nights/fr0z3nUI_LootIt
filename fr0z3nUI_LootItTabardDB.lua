-- Static lookup data for LootIt Tabard module.
-- This file must not be empty (WoW will emit a LUA_WARNING for empty Lua files).

local ADDON = ...

-- Keep this as a separate global to avoid clobbering LootIt's SavedVariables table
-- named `fr0z3nUI_LootItDB`.
_G.fr0z3nUI_LootItTabardDB = _G.fr0z3nUI_LootItTabardDB or {}
local DB = _G.fr0z3nUI_LootItTabardDB

-- NOTE:
-- The full datasets can be large; we keep what the tabard module needs:
-- - `reputationXRef`: tabard -> faction (or faction name -> ID mapping helpers)
-- - `tabardXRef`: tabard itemID -> factionID (fast path)
-- - `tabardGroup`: named lists used by the heuristics (city/dungeon/raid)
-- - `raidFaction`: raid mapID -> factionID hints
-- - `maps`: minimal map classification used for context/tier detection

DB.reputationXRef = DB.reputationXRef or {}
DB.tabardXRef = DB.tabardXRef or {}
DB.tabardGroup = DB.tabardGroup or {}
DB.raidFaction = DB.raidFaction or {}
DB.maps = DB.maps or {}

-- Minimal maps table ("just enough" classifier).
-- You can expand this later if you want finer-grained selection.
DB.maps = {
	-- Cities
	city = "84 87 90 103 109 110 111 125 126 128 129 130 132 133 134 135 136 140 141 142 143 144 145 146 147 148 149 150 151 152 153 154 155 156 157 158 159 160 161 162 163 164 165 166 167 168 169 170 171 172 173 174 175 176 177 178 179 180 181 182 183 184 185 186 187 188 189 190 191 192 193 194 195 196 197 198 199 200",

	-- PvP (very small; just enough so the module can detect "pvp" context in common zones)
	pvp = "466 30 489 529 566 607 617 628 726 727 761 968 998 1105 1134 1280",

	-- Dungeons/Raids are primarily detected via GetInstanceInfo() in the module.
}

-- Group lists used by the heuristic picker.
-- These are intentionally minimal; the module can still tooltip-scan tabards for faction if needed.
DB.tabardGroup = {
	all = "",
	cities = "",
	dungeons = "",
	raids = "",
	D85tabards = "",
}

-- If you previously had a populated dataset from the standalone addon, paste it here.
-- Leaving the tables present (even if empty) avoids nil errors and keeps the module functional
-- via tooltip scanning + dynamic caching.
