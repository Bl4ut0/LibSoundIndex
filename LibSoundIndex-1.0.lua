-- LibSoundIndex-1.0.lua
-- Universal sound index and muting library for WoW addons (Classic Era & TBC Anniversary)
-- Provides FileDataID lookups and surgical MuteSoundFile() control
--
-- API:
--   lib:GetFileDataIDs(soundKitID)       → table of FileDataIDs
--   lib:GetCategories()                  → table of category names
--   lib:GetCategoryIDs(category)         → table of FileDataIDs
--   lib:GetMaterialSoundIDs(materialKey) → table of FileDataIDs
--   lib:GetSoundKitName(soundKitID)      → string name
--
--   lib:MuteCategory(category)           → mute all sounds in a category
--   lib:UnmuteCategory(category)         → unmute all sounds in a category
--   lib:MuteSoundKit(soundKitID)         → mute a specific SoundKit
--   lib:UnmuteSoundKit(soundKitID)       → unmute a specific SoundKit
--   lib:MuteFileDataID(fileDataID)       → mute a single FileDataID
--   lib:UnmuteFileDataID(fileDataID)     → unmute a single FileDataID
--   lib:MuteMaterial(materialKey)        → mute a material sound group
--   lib:UnmuteMaterial(materialKey)      → unmute a material sound group
--   lib:MuteEquipCategory(equipCat)      → mute a convenience equip category
--   lib:UnmuteEquipCategory(equipCat)    → unmute a convenience equip category
--   lib:MuteForDuration(category, secs)  → mute, auto-unmute after duration
--   lib:MuteAll()                        → mute everything indexed
--   lib:UnmuteAll()                      → unmute everything indexed
--   lib:IsMuted(fileDataID)              → boolean
--   lib:IsCategoryMuted(category)        → boolean
--
-- Callbacks:
--   OnCategoryMuted(category)
--   OnCategoryUnmuted(category)
--   OnSoundMuted(fileDataID)
--   OnSoundUnmuted(fileDataID)

local MAJOR, MINOR = "LibSoundIndex-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- CallbackHandler
if not lib.callbacks then
    lib.callbacks = LibStub("CallbackHandler-1.0"):New(lib)
end

-- State tracking
lib.mutedFiles = lib.mutedFiles or {} -- [fileDataID] = true if currently muted
lib.mutedCategories = lib.mutedCategories or {} -- [category] = true
lib.durationTimers = lib.durationTimers or {} -- [category] = timerHandle

-- =============================================================================
-- INTERNAL HELPERS
-- =============================================================================

local function MuteFile(fileDataID)
    if not lib.mutedFiles[fileDataID] then
        MuteSoundFile(fileDataID)
        lib.mutedFiles[fileDataID] = true
        lib.callbacks:Fire("OnSoundMuted", fileDataID)
    end
end

local function UnmuteFile(fileDataID)
    if lib.mutedFiles[fileDataID] then
        UnmuteSoundFile(fileDataID)
        lib.mutedFiles[fileDataID] = nil
        lib.callbacks:Fire("OnSoundUnmuted", fileDataID)
    end
end

local WOW_PROJECT_ID = _G.WOW_PROJECT_ID or _G.WOW_PROJECT_MAINLINE

local function GetClientKey()
    if WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC then return "Vanilla" end
    if WOW_PROJECT_ID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC then return "TBC" end
    -- Fallback assuming future MoP classic expansion IDs etc. will check in correctly
    if WOW_PROJECT_ID == 14 then return "MoP" end -- Internal designation for MoP Classic
    return "Retail" -- Default fallback
end

local function GetArrayForCurrentClient(node)
    if not node then return {} end
    local key = GetClientKey()
    
    -- Exact match
    if node[key] then return node[key] end
    
    -- Fallbacks (e.g., if Retail isn't populated, fall back to MoP, etc. - ascending)
    if node.Retail then return node.Retail end
    if node.MoP then return node.MoP end
    if node.TBC then return node.TBC end
    if node.Vanilla then return node.Vanilla end
    
    return {}
end

local function CollectCategoryFileDataIDs(category)
    local ids = {}
    if lib.SoundKitData then
        for _, data in pairs(lib.SoundKitData) do
            if data.category == category then
                local fdids = GetArrayForCurrentClient(data)
                for _, fdid in ipairs(fdids) do
                    ids[#ids + 1] = fdid
                end
            end
        end
    end
    return ids
end

local function CollectMaterialFileDataIDs(materialKey)
    if lib.MaterialSounds and lib.MaterialSounds[materialKey] then
        return GetArrayForCurrentClient(lib.MaterialSounds[materialKey])
    end
    return {}
end

-- =============================================================================
-- QUERY API
-- =============================================================================

--- Get all FileDataIDs for a SoundKitID
-- @param soundKitID string|number - The SoundKit constant name (or ID) to look up
-- @return table|nil - Numerically indexed table of FileDataIDs, or empty table
function lib:GetFileDataIDs(soundKitID)
    -- Allow direct string lookup if they pass "IG_BACKPACK_OPEN" directly
    local key = soundKitID
    if type(soundKitID) == "number" and self.SoundKitByName then
        key = self.SoundKitByName[soundKitID]
    end

    if self.SoundKitData and key and self.SoundKitData[key] then
        return GetArrayForCurrentClient(self.SoundKitData[key])
    end
    return {}
end

--- Get all available sound categories
-- @return table - Numerically indexed table of category name strings
function lib:GetCategories()
    return self.SoundCategories or {}
end

--- Get all FileDataIDs belonging to a sound category
-- @param category string - Category name (e.g., "BAGS", "QUEST", "PVP")
-- @return table - Numerically indexed table of FileDataIDs
function lib:GetCategoryIDs(category)
    return CollectCategoryFileDataIDs(category)
end

--- Get all FileDataIDs for a material sound key
-- @param materialKey string - Material key (e.g., "PLATE_FOLEY", "METAL_SHEATHE")
-- @return table - Numerically indexed table of FileDataIDs
function lib:GetMaterialSoundIDs(materialKey)
    return CollectMaterialFileDataIDs(materialKey)
end

--- Get the human-readable name for a SoundKit indexed key
-- @param soundKitID string|number
-- @return string|nil - The constant name, or nil
function lib:GetSoundKitName(soundKitID)
    if self.SoundKitData and self.SoundKitData[soundKitID] then
        return soundKitID -- the table is now string keyed
    elseif type(soundKitID) == "number" and self.SoundKitByName then
        return self.SoundKitByName[soundKitID]
    end
    return nil
end

--- Look up a SoundKitID by its constant name
-- @param name string - The constant name (e.g., "IG_BACKPACK_OPEN")
-- @return number|nil - The SoundKitID, or nil
function lib:GetSoundKitByName(name)
    if self.SoundKitByName then
        return self.SoundKitByName[name]
    end
    return nil
end

--- Get all available material sound keys
-- @return table - Numerically indexed table of material key strings
function lib:GetMaterialKeys()
    if not self.MaterialSounds then return {} end
    local keys = {}
    for k in pairs(self.MaterialSounds) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

--- Get all available equip convenience categories
-- @return table - Numerically indexed table of equip category strings
function lib:GetEquipCategories()
    if not self.EquipCategories then return {} end
    local keys = {}
    for k in pairs(self.EquipCategories) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

-- =============================================================================
-- MUTE / UNMUTE API
-- =============================================================================

--- Mute a single FileDataID
-- @param fileDataID number - The FileDataID to mute
function lib:MuteFileDataID(fileDataID)
    MuteFile(fileDataID)
end

--- Unmute a single FileDataID
-- @param fileDataID number - The FileDataID to unmute
function lib:UnmuteFileDataID(fileDataID)
    UnmuteFile(fileDataID)
end

--- Check if a specific FileDataID is currently muted
-- @param fileDataID number - The FileDataID to check
-- @return boolean
function lib:IsMuted(fileDataID)
    return self.mutedFiles[fileDataID] == true
end

--- Mute all sounds for a SoundKitID
-- @param soundKitID number - The SoundKitID to mute
function lib:MuteSoundKit(soundKitID)
    local ids = self:GetFileDataIDs(soundKitID)
    if ids then
        for _, fdid in ipairs(ids) do
            MuteFile(fdid)
        end
    end
end

--- Unmute all sounds for a SoundKitID
-- @param soundKitID number - The SoundKitID to unmute
function lib:UnmuteSoundKit(soundKitID)
    local ids = self:GetFileDataIDs(soundKitID)
    if ids then
        for _, fdid in ipairs(ids) do
            UnmuteFile(fdid)
        end
    end
end

--- Mute all sounds in a sound category (e.g., "BAGS", "QUEST", "PVP")
-- @param category string - The category name
function lib:MuteCategory(category)
    local ids = CollectCategoryFileDataIDs(category)
    for _, fdid in ipairs(ids) do
        MuteFile(fdid)
    end
    self.mutedCategories[category] = true
    self.callbacks:Fire("OnCategoryMuted", category)
end

--- Unmute all sounds in a sound category
-- @param category string - The category name
function lib:UnmuteCategory(category)
    local ids = CollectCategoryFileDataIDs(category)
    for _, fdid in ipairs(ids) do
        UnmuteFile(fdid)
    end
    self.mutedCategories[category] = nil
    self.callbacks:Fire("OnCategoryUnmuted", category)
end

--- Check if a category is currently muted
-- @param category string - The category name
-- @return boolean
function lib:IsCategoryMuted(category)
    return self.mutedCategories[category] == true
end

--- Mute all sounds for a material key (e.g., "PLATE_FOLEY", "CHAIN_FOLEY")
-- @param materialKey string - The material sound key
function lib:MuteMaterial(materialKey)
    local ids = CollectMaterialFileDataIDs(materialKey)
    for _, fdid in ipairs(ids) do
        MuteFile(fdid)
    end
    self.mutedCategories["MATERIAL_" .. materialKey] = true
    self.callbacks:Fire("OnCategoryMuted", "MATERIAL_" .. materialKey)
end

--- Unmute all sounds for a material key
-- @param materialKey string - The material sound key
function lib:UnmuteMaterial(materialKey)
    local ids = CollectMaterialFileDataIDs(materialKey)
    for _, fdid in ipairs(ids) do
        UnmuteFile(fdid)
    end
    self.mutedCategories["MATERIAL_" .. materialKey] = nil
    self.callbacks:Fire("OnCategoryUnmuted", "MATERIAL_" .. materialKey)
end

--- Mute an equip convenience category (e.g., "ALL_EQUIP", "ALL_ARMOR_FOLEY", "PLATE", "MAIL")
-- @param equipCat string - The equip category name from EquipCategories
function lib:MuteEquipCategory(equipCat)
    if not self.EquipCategories or not self.EquipCategories[equipCat] then return end
    for _, materialKey in ipairs(self.EquipCategories[equipCat]) do
        self:MuteMaterial(materialKey)
    end
end

--- Unmute an equip convenience category
-- @param equipCat string - The equip category name
function lib:UnmuteEquipCategory(equipCat)
    if not self.EquipCategories or not self.EquipCategories[equipCat] then return end
    for _, materialKey in ipairs(self.EquipCategories[equipCat]) do
        self:UnmuteMaterial(materialKey)
    end
end

--- Mute a category for a specified duration, then auto-unmute
-- @param category string - Category name, material key, or equip category
-- @param duration number - Seconds before auto-unmute (default 1.0)
function lib:MuteForDuration(category, duration)
    duration = duration or 1.0

    -- Cancel any existing timer for this category
    if self.durationTimers[category] then
        -- C_Timer handles are not cancellable directly, but we use a flag
        self.durationTimers[category] = nil
    end

    -- Determine what type of category this is and mute it
    if self.EquipCategories and self.EquipCategories[category] then
        self:MuteEquipCategory(category)
    elseif self.MaterialSounds and self.MaterialSounds[category] then
        self:MuteMaterial(category)
    else
        self:MuteCategory(category)
    end

    -- Set up auto-unmute
    local timerID = {} -- unique reference
    self.durationTimers[category] = timerID
    C_Timer.After(duration, function()
        -- Only unmute if our timer is still the active one (not overridden)
        if lib.durationTimers[category] == timerID then
            lib.durationTimers[category] = nil
            if lib.EquipCategories and lib.EquipCategories[category] then
                lib:UnmuteEquipCategory(category)
            elseif lib.MaterialSounds and lib.MaterialSounds[category] then
                lib:UnmuteMaterial(category)
            else
                lib:UnmuteCategory(category)
            end
        end
    end)
end

--- Mute ALL indexed sounds (material + SoundKit)
function lib:MuteAll()
    -- Material sounds
    if self.MaterialSounds then
        for key in pairs(self.MaterialSounds) do
            self:MuteMaterial(key)
        end
    end
    -- SoundKit sounds
    if self.SoundKitData then
        for skid in pairs(self.SoundKitData) do
            self:MuteSoundKit(skid)
        end
    end
end

--- Unmute ALL indexed sounds
function lib:UnmuteAll()
    -- Just unmute everything we've tracked
    for fdid in pairs(self.mutedFiles) do
        UnmuteSoundFile(fdid)
        self.callbacks:Fire("OnSoundUnmuted", fdid)
    end
    wipe(self.mutedFiles)
    wipe(self.mutedCategories)
    wipe(self.durationTimers)
end

-- =============================================================================
-- UTILITY
-- =============================================================================

--- Print library info (for debugging)
function lib:PrintInfo()
    local materialCount = 0
    local materialFileCount = 0
    if self.MaterialSounds then
        for _, data in pairs(self.MaterialSounds) do
            materialCount = materialCount + 1
            materialFileCount = materialFileCount + #data.fileDataIDs
        end
    end
    local soundKitCount = 0
    local soundKitFileCount = 0
    if self.SoundKitData then
        for _, data in pairs(self.SoundKitData) do
            soundKitCount = soundKitCount + 1
            soundKitFileCount = soundKitFileCount + #data.fileDataIDs
        end
    end
    local mutedCount = 0
    for _ in pairs(self.mutedFiles) do mutedCount = mutedCount + 1 end

    print("|cff00ff00LibSoundIndex-1.0|r")
    print(("  Material sounds: %d groups, %d FileDataIDs"):format(materialCount, materialFileCount))
    print(("  SoundKit entries: %d kits, %d FileDataIDs"):format(soundKitCount, soundKitFileCount))
    print(("  Currently muted: %d FileDataIDs"):format(mutedCount))
end

-- Slash command for debugging
SLASH_LIBSOUNDINDEX1 = "/lsi"
SlashCmdList["LIBSOUNDINDEX"] = function(msg)
    msg = strtrim(msg or "")
    if msg == "" or msg == "info" then
        lib:PrintInfo()
    elseif msg == "muteall" then
        lib:MuteAll()
        print("|cff00ff00LibSoundIndex|r: All indexed sounds muted.")
    elseif msg == "unmuteall" then
        lib:UnmuteAll()
        print("|cff00ff00LibSoundIndex|r: All sounds unmuted.")
    else
        print("|cff00ff00LibSoundIndex-1.0|r commands:")
        print("  /lsi info - Show library stats")
        print("  /lsi muteall - Mute all indexed sounds")
        print("  /lsi unmuteall - Unmute all sounds")
    end
end
