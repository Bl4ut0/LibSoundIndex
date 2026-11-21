
-- LibSoundIndex-1.0.lua
-- Look up and mute WoW sound files by FileDataID. See API.md for usage.

local MAJOR, MINOR = "LibSoundIndex-1.0", 3
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

-- CallbackHandler
if not lib.callbacks then
    lib.callbacks = LibStub("CallbackHandler-1.0"):New(lib)
end


-- Each library operation owns its file mutes independently.
lib.mutedFiles = lib.mutedFiles or {}
lib.mutedCategories = lib.mutedCategories or {}
lib.fileOwners = lib.fileOwners or {}
lib.categoryOwners = lib.categoryOwners or {}
lib.durationTimers = {}

for id in pairs(lib.mutedFiles) do
    lib.fileOwners[id] = lib.fileOwners[id] or { direct = true }
end

local function IsID(value)
    return (not issecretvalue or not issecretvalue(value))
        and type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

local function HasMuteAPI()
    return type(MuteSoundFile) == "function" and type(UnmuteSoundFile) == "function"
end

local function MuteFile(id, owner)
    if not IsID(id) or not HasMuteAPI() then return false end

    local owners = lib.fileOwners[id]
    if owners then
        owners[owner] = true
    else
        local ok, result = pcall(MuteSoundFile, id)
        if not ok or result == false then return false end
        lib.fileOwners[id] = { [owner] = true }
        lib.mutedFiles[id] = true
        lib.callbacks:Fire("OnSoundMuted", id)
    end
    return true
end

local function UnmuteFile(id, owner)
    if not IsID(id) then return end
    local owners = lib.fileOwners[id]
    if not owners or not owners[owner] then return end
    owners[owner] = nil
    if next(owners) then return end

    local ok, result = pcall(UnmuteSoundFile, id)
    if not ok or result == false then
        owners[owner] = true
        return
    end
    lib.fileOwners[id] = nil
    lib.mutedFiles[id] = nil
    lib.callbacks:Fire("OnSoundUnmuted", id)
end

local interface = type(GetBuildInfo) == "function" and select(4, GetBuildInfo())
lib.interfaceVersion = interface
local project = WOW_PROJECT_ID

function lib:GetClientKey()
    -- Forever can report the mainline project ID. Read the interface number first.
    if type(interface) == "number" then
        if interface == 11601 or (interface >= 16000 and interface < 17000) then return "Forever" end
        if interface >= 10000 and interface < 20000 then return "Vanilla" end
        if interface >= 20000 and interface < 30000 then return "TBC" end
        if interface >= 50500 and interface < 50600 then return "MoP" end
        if interface >= 100000 then return "Retail" end
        return "Unknown"
    end
    if project and project == WOW_PROJECT_CLASSIC then return "Vanilla" end
    if project and project == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then return "TBC" end
    if project and project == WOW_PROJECT_MAINLINE then return "Retail" end
    return "Unknown"
end

local clientKey = lib:GetClientKey()

local function GetArrayForCurrentClient(node)
    return node and node[clientKey] or {}
end

local function CollectCategoryFileDataIDs(category)
    local ids = {}
    if lib.SoundKitData then
        for name, data in pairs(lib.SoundKitData) do
            if data.category == category then
                local fdids = lib:GetFileDataIDs(name)
                for _, fdid in ipairs(fdids) do
                    ids[#ids + 1] = fdid
                end
            end
        end
    end
    return ids
end

local function CollectMaterialFileDataIDs(materialKey)
    if materialKey == "JEWELRY_EQUIP" and lib.ItemSoundData then
        return lib.ItemSoundData.accessoryFiles
    end
    if lib.MaterialSounds and lib.MaterialSounds[materialKey] then
        return GetArrayForCurrentClient(lib.MaterialSounds[materialKey])
    end
    return {}
end

-- =============================================================================
-- QUERY API
-- =============================================================================


--- Resolve a numeric SoundKitID or a Blizzard SOUNDKIT constant name.
function lib:GetFileDataIDs(soundKitID)
    if type(soundKitID) == "string" then
        local id = self:GetSoundKitByName(soundKitID)
        if id and self.SoundKitLookup and self.SoundKitLookup[id] then
            return self.SoundKitLookup[id]
        end
        return GetArrayForCurrentClient(self.SoundKitData and self.SoundKitData[soundKitID])
    end
    if type(soundKitID) == "number" then
        return self:GetFileDataIDsBySoundKitID(soundKitID)
    end
    return {}
end

--- Get all FileDataIDs for a numeric SoundKitID directly (bypasses named constants)
-- @param soundKitID number - The numeric SoundKitID
-- @return table - Numerically indexed table of FileDataIDs, or empty table
function lib:GetFileDataIDsBySoundKitID(soundKitID)
    if self.SoundKitLookup and self.SoundKitLookup[soundKitID] then
        return self.SoundKitLookup[soundKitID]
    end
    return {}
end

--- Get the total number of indexed SoundKitIDs (named + universal lookup)
-- @return number namedCount, number lookupCount
function lib:GetSoundKitCount()
    local named = 0
    if self.SoundKitData then
        for _ in pairs(self.SoundKitData) do named = named + 1 end
    end
    local lookup = 0
    if self.SoundKitLookup then
        for _ in pairs(self.SoundKitLookup) do lookup = lookup + 1 end
    end
    return named, lookup
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


local soundKitNames = {}
for name, id in pairs(SOUNDKIT or {}) do
    local previous = soundKitNames[id]
    if not previous or name < previous then
        soundKitNames[id] = name
    end
end

function lib:GetSoundKitName(soundKitID)
    if type(soundKitID) == "string" then
        if self:GetSoundKitByName(soundKitID) or (self.SoundKitData and self.SoundKitData[soundKitID]) then
            return soundKitID
        end
    else
        return soundKitNames[soundKitID]
    end
end

function lib:GetSoundKitByName(name)
    return SOUNDKIT and SOUNDKIT[name]
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


local function SetFileMutes(ids, owner, muted)
    for _, id in ipairs(ids) do
        if muted then
            MuteFile(id, owner)
        else
            UnmuteFile(id, owner)
        end
    end
end

function lib:MuteFileDataID(id)
    MuteFile(id, "direct")
end

function lib:UnmuteFileDataID(id)
    UnmuteFile(id, "direct")
end

function lib:IsMuted(id)
    return self.mutedFiles[id] == true
end

local function SetSoundKitMute(kit, muted)
    if type(kit) ~= "string" and not IsID(kit) then return end
    local owner = "kit:" .. tostring(lib:GetSoundKitByName(kit) or kit)
    SetFileMutes(lib:GetFileDataIDs(kit), owner, muted)
end

function lib:MuteSoundKit(kit)
    SetSoundKitMute(kit, true)
end

function lib:UnmuteSoundKit(kit)
    SetSoundKitMute(kit, false)
end

local function SetCategoryMute(category, ids, owner, muted)
    local owners = lib.categoryOwners[category]
    local wasMuted = owners ~= nil
    if muted then
        local acquired = false
        for _, id in ipairs(ids) do
            if MuteFile(id, owner) then acquired = true end
        end
        if not acquired then return end
        owners = owners or {}
        owners[owner] = true
        lib.categoryOwners[category] = owners
        lib.mutedCategories[category] = true
        if not wasMuted then lib.callbacks:Fire("OnCategoryMuted", category) end
    elseif owners and owners[owner] then
        SetFileMutes(ids, owner, false)
        owners[owner] = nil
        if not next(owners) then
            lib.categoryOwners[category] = nil
            lib.mutedCategories[category] = nil
            lib.callbacks:Fire("OnCategoryUnmuted", category)
        end
    end
end

function lib:MuteCategory(category)
    SetCategoryMute(category, self:GetCategoryIDs(category), "category:" .. category, true)
end

function lib:UnmuteCategory(category)
    SetCategoryMute(category, self:GetCategoryIDs(category), "category:" .. category, false)
end

function lib:IsCategoryMuted(category)
    return self.mutedCategories[category] == true
end

local function SetMaterialMute(key, owner, muted)
    SetCategoryMute("MATERIAL_" .. key, lib:GetMaterialSoundIDs(key), owner, muted)
end

function lib:MuteMaterial(key)
    SetMaterialMute(key, "material:" .. key, true)
end

function lib:UnmuteMaterial(key)
    SetMaterialMute(key, "material:" .. key, false)
end

local function SetEquipMute(category, owner, muted)
    local keys = lib.EquipCategories and lib.EquipCategories[category] or {}
    for _, key in ipairs(keys) do
        -- Use one owner per material so releasing one cannot release a shared file early.
        SetMaterialMute(key, owner .. ":" .. key, muted)
    end
end

function lib:MuteEquipCategory(category)
    SetEquipMute(category, "equip:" .. category, true)
end

function lib:UnmuteEquipCategory(category)
    SetEquipMute(category, "equip:" .. category, false)
end

local function After(duration, callback)
    if type(duration) ~= "number" or not (duration > 0 and duration < math.huge)
        or not C_Timer or type(C_Timer.After) ~= "function" then return false end
    return pcall(C_Timer.After, duration, callback)
end

local function SetTimedCategory(category, owner, muted)
    if lib.EquipCategories and lib.EquipCategories[category] then
        SetEquipMute(category, owner, muted)
    elseif lib.MaterialSounds and lib.MaterialSounds[category] then
        SetMaterialMute(category, owner, muted)
    else
        SetCategoryMute(category, lib:GetCategoryIDs(category), owner, muted)
    end
end

function lib:MuteForDuration(category, duration)
    if type(category) ~= "string" then return end
    local timer = {}
    local owner = "timer:" .. category
    if not After(duration or 1, function()
        if lib.durationTimers[category] == timer then
            lib.durationTimers[category] = nil
            SetTimedCategory(category, owner, false)
        end
    end) then return end
    self.durationTimers[category] = timer
    SetTimedCategory(category, owner, true)
end

--- Acquire a timed mute for each distinct FileDataID and return the number acquired.
function lib:MuteFileDataIDsForDuration(ids, duration)
    if type(ids) ~= "table" or #ids == 0 or not HasMuteAPI() then return 0 end
    local files = {}
    if not After(duration or 0.35, function()
        for id in pairs(files) do
            UnmuteFile(id, files)
        end
    end) then return 0 end

    local count = 0
    for _, id in ipairs(ids) do
        if IsID(id) and not files[id] and MuteFile(id, files) then
            files[id] = true
            count = count + 1
        end
    end
    return count
end

local function GetItemID(item)
    if issecretvalue and issecretvalue(item) then return end
    if type(item) == "string" then
        item = tonumber(item:match("|Hitem:(%d+)") or item:match("^item:(%d+)")
            or item:match("^(%d+):") or item:match("^(%d+)$"))
    end
    if IsID(item) then return item end
end

--- Return a copy of the candidate sound files for an equipment item.
function lib:GetItemSoundFileDataIDs(item)
    local data = self.ItemSoundData
    local itemID = GetItemID(item)
    local key = data and itemID and data.itemSets[itemID]
    local result = {}
    if key then
        for i, id in ipairs(data.fileSets[key]) do result[i] = id end
    end
    return result
end

function lib:CanMuteItemSounds()
    return self.ItemSoundData ~= nil and HasMuteAPI()
        and C_Timer ~= nil and type(C_Timer.After) == "function"
end

--- Call immediately before submitting an equipment move.
function lib:MuteItemSwapSounds(source, destination, duration)
    local files = self:GetItemSoundFileDataIDs(source)
    for _, id in ipairs(self:GetItemSoundFileDataIDs(destination)) do
        files[#files + 1] = id
    end
    local acquired = self:MuteFileDataIDsForDuration(files, duration)
    if self.RecordProfileSwapMute then
        self:RecordProfileSwapMute(GetItemID(source), GetItemID(destination), files, acquired, duration or 0.35)
    end
    return acquired
end

--- Mute the curated material and named sound groups.
function lib:MuteAll()
    for key in pairs(self.MaterialSounds or {}) do
        self:MuteMaterial(key)
    end
    for kit in pairs(self.SoundKitData or {}) do
        self:MuteSoundKit(kit)
    end
end

function lib:UnmuteAll()
    self.durationTimers = {}
    self.categoryOwners = {}
    self.mutedCategories = {}
    for id in pairs(self.mutedFiles) do
        local ok, result = pcall(UnmuteSoundFile, id)
        if ok and result ~= false then
            self.fileOwners[id] = nil
            self.mutedFiles[id] = nil
            self.callbacks:Fire("OnSoundUnmuted", id)
        end
    end
end

function lib:DebugAnalyzeItem(item)
    local itemID = GetItemID(item)
    if not itemID then
        print("LibSoundIndex: supply an item ID or link.")
        return
    end
    local files = self:GetItemSoundFileDataIDs(itemID)
    local build = self.ItemSoundData and self.ItemSoundData.build or "unavailable"
    print(("LibSoundIndex: item %d, %s data %s, candidate files: %s"):format(
        itemID, clientKey, build, #files > 0 and table.concat(files, ", ") or "none"))
end

-- =============================================================================
-- UTILITY
-- =============================================================================

--- Print library info (for debugging)
function lib:PrintInfo()
    local materialCount = 0
    local materialFileCount = 0
    if self.MaterialSounds then
        for key in pairs(self.MaterialSounds) do
            materialCount = materialCount + 1
            materialFileCount = materialFileCount + #self:GetMaterialSoundIDs(key)
        end
    end
    local soundKitCount = 0
    local soundKitFileCount = 0
    if self.SoundKitData then
        for name in pairs(self.SoundKitData) do
            soundKitCount = soundKitCount + 1
            soundKitFileCount = soundKitFileCount + #self:GetFileDataIDs(name)
        end
    end
    local lookupCount = 0
    local lookupFileCount = 0
    if self.SoundKitLookup then
        for _, fdids in pairs(self.SoundKitLookup) do
            lookupCount = lookupCount + 1
            lookupFileCount = lookupFileCount + #fdids
        end
    end
    local mutedCount = 0
    for _ in pairs(self.mutedFiles) do mutedCount = mutedCount + 1 end

    print("|cff00ff00LibSoundIndex-1.0|r (" .. clientKey .. ")")
    print(("  Material sounds: %d groups, %d FileDataIDs"):format(materialCount, materialFileCount))
    print(("  Named SoundKits: %d kits, %d FileDataIDs"):format(soundKitCount, soundKitFileCount))
    print(("  Universal Lookup: %d SoundKitIDs, %d FileDataIDs"):format(lookupCount, lookupFileCount))
    print(("  Currently muted: %d FileDataIDs (%s)"):format(mutedCount,
        HasMuteAPI() and "file muting available" or "file muting unavailable"))
    if self.ItemSoundData then
        print("  Equipment sound data: " .. self.ItemSoundData.build)
    end
end
