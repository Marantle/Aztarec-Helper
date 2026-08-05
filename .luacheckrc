std = "lua51"
max_line_length = false

-- Globals the addon writes to
globals = {
    "AztarecHelperDB",
    "SLASH_AZT1",
    "SlashCmdList",
    "AztarecHelper_Capture",
    "AztarecHelper_OnCompartment",
    "BINDING_HEADER_AZTARECHELPER",
    "BINDING_NAME_AZTARECHELPER_CAPTURE",
}

-- WoW API globals we read but never assign to
read_globals = {
    -- Namespaced APIs
    "C_Timer",
    "C_Spell",
    "C_ChatInfo",
    "C_Map",
    "C_ScenarioInfo",
    "C_Texture",
    "Settings",
    -- Frame creation
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    -- Font templates
    "GameFontNormal",
    "GameFontNormalSmall",
    "ChatFontNormal",
    -- Unit
    "UnitName",
    "UnitGUID",
    "UnitExists",
    "UnitIsUnit",
    "UnitPosition",
    "UnitCanAttack",
    "UnitHealth",
    "UnitHealthMax",
    "UnitCastingInfo",
    "UnitChannelInfo",
    "GetPlayerFacing",
    "GetInstanceInfo",
    "GetZoneText",
    "GetSubZoneText",
    "CreateVector2D",
    "issecretvalue",
    "wipe",
    "date",
    "PlaySound",
    "PlaySoundFile",
    "SOUNDKIT",
    -- Group
    "IsInGroup",
    "IsInRaid",
    "GetRaidRosterInfo",
    "LE_PARTY_CATEGORY_INSTANCE",
    -- Combat / encounter
    "IsEncounterInProgress",
    "InCombatLockdown",
    -- Misc
    "GetTime",
    "RAID_CLASS_COLORS",
    "CLASS_SORT_ORDER",
    "Minimap",
    "GetCursorPosition",
}
