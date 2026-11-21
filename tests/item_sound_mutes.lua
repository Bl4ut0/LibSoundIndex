strmatch = string.match

local function LoadClient(suffix, interface, project)
    LibStub = nil
    SlashCmdList = {}
    WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC, WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 1, 2, 5
    WOW_PROJECT_ID = project
    GetBuildInfo = function() return "", "", "", interface end
    SOUNDKIT = { IG_BACKPACK_OPEN = 862 }
    local toc = "LibSoundIndex/LibSoundIndex_" .. suffix .. ".toc"
    for line in io.lines(toc) do
        if line:find("%.lua$") then
            dofile("LibSoundIndex/" .. line:gsub("\\", "/"))
        end
    end
    return LibStub("LibSoundIndex-1.0")
end

local function HasFile(files, expected)
    for _, actual in ipairs(files) do
        if expected == actual then return true end
    end
    return false
end

local clients = {
    { "Vanilla", 11508, 2, "Vanilla", "1.15.8.67156" },
    { "Vanilla", 11509, 2, "Vanilla", "1.15.9.70576" },
    { "TBC", 20505, 5, "TBC", "2.5.5.68575" },
    { "TBC", 20506, 5, "TBC", "2.5.6.70577" },
    { "Camelot", 11601, 1, "Forever", "1.60.1.71037" },
    { "Camelot", 16001, 1, "Forever", "1.60.1.71037" },
}
for _, client in ipairs(clients) do
    local lsi = LoadClient(client[1], client[2], client[3])
    assert(lsi:GetClientKey() == client[4] and lsi.ItemSoundData.build == client[5])
    local files = lsi:GetItemSoundFileDataIDs("|cffa335ee|Hitem:19019:0:0|h[Thunderfury]|h|r")
    assert(#files == 4 and HasFile(files, 567498) and HasFile(files, 567473))
    assert(not HasFile(files, 567461), "unrelated bag sound must be absent")
    assert(#lsi:GetItemSoundFileDataIDs("19019:0:0:rune:123") == #files)
    files[1] = -1
    assert(not HasFile(lsi:GetItemSoundFileDataIDs(19019), -1), "lookup must return a copy")
    assert(#lsi:GetItemSoundFileDataIDs(2147483647) == 0)
    assert(lsi:GetSoundKitByName("IG_BACKPACK_OPEN") == 862)
    assert(lsi:GetSoundKitName(862) == "IG_BACKPACK_OPEN")
    assert(HasFile(lsi:GetFileDataIDs("IG_BACKPACK_OPEN"), 567461))
    if client[2] == 20505 then
        assert(#lsi:GetItemSoundFileDataIDs(281924) == 0, "old Anniversary must skip newer items")
    elseif client[2] == 20506 then
        assert(#lsi:GetItemSoundFileDataIDs(281924) > 0, "current Anniversary must resolve newer items")
    end
end
assert(LoadClient("Mists", 50503, 19):GetClientKey() == "MoP")
assert(LoadClient("Mainline", 120001, 1):GetClientKey() == "Retail")

local lsi = LoadClient("TBC", 20506, 5)
local trinket = lsi:GetItemSoundFileDataIDs(30293)
assert(#trinket == 2 and HasFile(trinket, 567542) and HasFile(trinket, 567551))
assert(HasFile(lsi:GetMaterialSoundIDs("JEWELRY_EQUIP"), 567542))
local otherTrinket = lsi:GetItemSoundFileDataIDs(22954)
assert(#otherTrinket == 2 and not HasFile(otherTrinket, 567542))

local timers, backend = {}, {}
C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = callback
    assert(delay > 0)
end }
function MuteSoundFile(id)
    assert(not backend[id], "duplicate native mute")
    if id == 111 then error("native failure") end
    backend[id] = true
end
function UnmuteSoundFile(id)
    assert(backend[id], "unmute must release an active native mute")
    backend[id] = nil
end
assert(lsi:CanMuteItemSounds())
local receiver, callbacks, callbackErrors = {}, {}, 0
geterrorhandler = function()
    return function() callbackErrors = callbackErrors + 1 end
end
lsi.RegisterCallback(receiver, "OnSoundMuted", function(event, id)
    callbacks[#callbacks + 1] = {event, id}
    error("consumer callback failure")
end)
lsi.RegisterCallback(receiver, "OnSoundUnmuted", function(event, id)
    callbacks[#callbacks + 1] = {event, id}
end)
assert(lsi:MuteItemSwapSounds(0, nil) == 0 and #timers == 0)
assert(lsi:MuteItemSwapSounds(30293, 30293, -1) == 0 and #timers == 0)
assert(lsi:MuteItemSwapSounds(30293, nil, 0 / 0) == 0 and #timers == 0)
assert(lsi:MuteFileDataIDsForDuration({ 111, 222, 222, 0, "3" }) == 1)
assert(backend[222] and not backend[111])
timers[1]()
assert(not backend[222])
assert(callbackErrors == 1 and callbacks[1][1] == "OnSoundMuted" and callbacks[1][2] == 222)
assert(callbacks[2][1] == "OnSoundUnmuted" and callbacks[2][2] == 222)
lsi.UnregisterAllCallbacks(receiver)

lsi:MuteFileDataID(trinket[1])
assert(lsi:MuteItemSwapSounds(30293, 30293) == 2, "shared sound files must be deduplicated")
assert(lsi:MuteItemSwapSounds(22954, 30293) == 4)
timers[2]()
assert(backend[trinket[2]], "the first window must preserve a later claim")
timers[3]()
assert(backend[trinket[1]] and not backend[trinket[2]], "a timed window must preserve a direct mute")
lsi:UnmuteFileDataID(trinket[1])
assert(not next(backend))

lsi:MuteMaterial("LIQUID_SHEATHE")
lsi:MuteEquipCategory("PLATE")
assert(backend[567395])
lsi:UnmuteMaterial("LIQUID_SHEATHE")
assert(backend[567395], "two material groups can share a file")
lsi:UnmuteEquipCategory("PLATE")
assert(not next(backend))

lsi:MuteCategory("BAGS")
lsi:MuteForDuration("BAGS")
lsi:MuteForDuration("BAGS")
timers[4]()
timers[5]()
assert(lsi:IsCategoryMuted("BAGS") and backend[567461])
lsi:UnmuteCategory("BAGS")
assert(not next(backend))

lsi:MuteItemSwapSounds(30293)
lsi:UnmuteAll()
lsi:MuteFileDataID(trinket[2])
timers[6]()
assert(backend[trinket[2]], "an old timer must not release a newer mute")
lsi:UnmuteAll()
assert(not next(backend))

MuteSoundFile = nil
assert(not lsi:CanMuteItemSounds())
assert(lsi:MuteItemSwapSounds(30293) == 0 and #timers == 6)
print("LibSoundIndex client, item data, and mute ownership checks passed.")
