strmatch = string.match
strtrim = function(text) return text:match("^%s*(.-)%s*$") end
SlashCmdList = {}
WOW_PROJECT_ID = 5
GetBuildInfo = function() return "2.5.6", "70577", "", 20506 end
GetAddOnMetadata = function(addon, field)
    if addon == "ItemRack" and field == "Version" then return "Dev" end
end
GetCVar = function() return "1" end
ItemRackSettings = { DisableSwapSound = "OFF" }

local now = 0
local timers = {}
function GetTime() return now end
C_Timer = { After = function(seconds, callback)
    timers[#timers + 1] = { due = now + seconds, callback = callback }
end }
local function Advance(seconds)
    local untilTime = now + seconds
    table.sort(timers, function(a, b) return a.due < b.due end)
    while timers[1] and timers[1].due <= untilTime do
        local timer = table.remove(timers, 1)
        now = timer.due
        timer.callback()
        table.sort(timers, function(a, b) return a.due < b.due end)
    end
    now = untilTime
end

local hooks, frames = {}, {}
local methods = {}
local function noop() end
function CreateFrame(_, name)
    local frame = setmetatable({ scripts = {}, events = {} }, {
        __index = function(_, key) return methods[key] or noop end,
    })
    if name then frames[name] = frame end
    if not frames.equipment then frames.equipment = frame end
    return frame
end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:RegisterEvent(name) self.events[name] = true end
function methods:UnregisterAllEvents() self.events = {} end
function methods:CreateFontString() return CreateFrame() end
function methods:CreateTexture() return CreateFrame() end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetShown(shown) self.shown = shown end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:Hide() self.shown = false end
function methods:SetScrollChild(child) self.child = child end
function methods:SetText(text) self.text = text end
function methods:SetFocus() self.focused = true end
function methods:HighlightText() self.highlighted = true end
function methods:Show() self.shown = true end
function methods:IsShown() return self.shown == true end
local function Fire(event, ...)
    local frame = frames.equipment
    if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
end

PlaySound = noop
PlaySoundFile = noop
C_Sound = { PlaySound = noop, PlaySoundFile = noop, PlayItemSound = noop }
C_Item = {
    GetItemID = function(location) return location.id end,
    GetItemInfo = function(id)
        if id == 30293 then return "Heavenly Inspiration" end
        if id == 22954 then return "Kiss of the Spider" end
    end,
    GetItemIconByID = function(id)
        if id == 30293 then return 136047 end
        if id == 22954 then return 134339 end
    end,
}
function hooksecurefunc(target, name, fn)
    local key = type(target) == "table" and ("C_Sound." .. name) or target
    assert(not hooks[key], "hook installed twice")
    hooks[key] = fn or name
end
local unavailable = {}
issecretvalue = function(value) return value == unavailable end
local inventory = { [13] = 30293 }
function GetInventoryItemID(unit, slot)
    assert(unit == "player")
    return inventory[slot]
end

local muted = {}
function MuteSoundFile(id) muted[id] = true end
function UnmuteSoundFile(id) muted[id] = nil end
function SetCVar() error("the profiler must leave game audio settings alone") end

for line in io.lines("LibSoundIndex/LibSoundIndex_TBC.toc") do
    if line:find("%.lua$") then dofile("LibSoundIndex/" .. line:gsub("\\", "/")) end
end
local lsi = LibStub("LibSoundIndex-1.0")
local function Command(text) SlashCmdList.LIBSOUNDINDEX(text) end
local function Contains(text, needle) return text:find(needle, 1, true) ~= nil end

Command("debug start 30")
assert(hooks.PlaySound and hooks["C_Sound.PlayItemSound"], "debug must record with the listener closed")
assert(frames.equipment.events.PLAYER_EQUIPMENT_CHANGED)
hooks.PlaySound(862)
hooks["C_Sound.PlaySoundFile"](510000)
hooks.PlaySoundFile("Interface/AddOns/SomeAddon/SomeSound.ogg")
hooks["C_Sound.PlayItemSound"](0, {id = 30293})
hooks.PlaySoundFile(unavailable)
inventory[13] = unavailable
Fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
inventory[13] = nil
Fire("PLAYER_EQUIPMENT_CHANGED", 13, true) -- Has a new item, but the inventory read has yet to settle.
inventory[13] = 22954
Fire("UNIT_INVENTORY_CHANGED", "party1")
Fire("UNIT_INVENTORY_CHANGED", "player")
Fire("PLAYER_EQUIPMENT_CHANGED", 13, true)

local report = lsi:GetSoundProfileReport()
assert(Contains(report, "TBC 2.5.6 build 70577, interface 20506"))
assert(Contains(report, "ItemRack version Dev"))
assert(Contains(report, "active after"))
assert(Contains(report, "Lua SoundKit 862 [567461]"))
assert(Contains(report, "Lua FileDataID 510000"))
assert(Contains(report, "Lua file path (path omitted)"))
assert(not Contains(report, "SomeAddon"))
assert(Contains(report, "Lua item sound action=0 item=30293"))
assert(Contains(report, "slot=13 30293 -> 22954") and not Contains(report, "30293 -> 0"))
assert(Contains(report, "5 events, 0 older events discarded"), "repeated and restricted reads must not invent observations")
ItemRackSettings.DisableSwapSound = "ON"
report = lsi:GetSoundProfileReport()
assert(Contains(report, "Audio settings at capture start game sound 1, SFX 1, ItemRack swap mute OFF"))
assert(Contains(report, "Audio settings at export game sound 1, SFX 1, ItemRack swap mute ON"))
ItemRackSettings.DisableSwapSound = "OFF"
Command("probe items")
assert(not next(muted), "a group probe must start after the baseline capture")
Command("debug stop")
assert(not next(frames.equipment.events))
hooks.PlaySoundFile(510001)
assert(not Contains(lsi:GetSoundProfileReport(), "510001"))

Command("probe items")
assert(muted[567542] and muted[567551] and muted[567544] and muted[567549])
assert(not muted[567461] and not muted[510000])
Command("result partial")
assert(Contains(lsi:GetSoundProfileReport(), "Probe items, acquired 4/4 for 5s, heard result partial"))
Advance(5)
assert(not next(muted), "probe must release its timed mutes")
Command("probe lua 2")
assert(muted[567461] and muted[510000] and not muted[567542])
Advance(2)
assert(not next(muted))

Command("dump")
local dump = frames.LibSoundIndexProfileDump
assert(dump.shown and dump.edit.focused and dump.edit.highlighted)
assert(dump.edit.text == lsi:GetSoundProfileReport(), "copy window must contain the whole report")

Command("debug start 8")
lsi:MuteItemSwapSounds(30293, 22954)
assert(Contains(lsi:GetSoundProfileReport(), "Item mute request 30293 -> 22954 acquired=4 for 0.35s"))
Advance(1)
Command("debug start 10")
for id = 520001, 520105 do hooks.PlaySoundFile(id) end
report = lsi:GetSoundProfileReport()
assert(Contains(report, "105 events, 5 older events discarded"))
assert(not Contains(report, "Lua FileDataID 520005") and Contains(report, "Lua FileDataID 520006"))
assert(#report < 24000, "bounded export must fit in a single copy box")
Advance(7)
assert(Contains(lsi:GetSoundProfileReport(), "Capture active"), "a stale capture timer must not stop the new one")
Advance(3)
assert(Contains(lsi:GetSoundProfileReport(), "Capture stopped"))
Command("debug clear")
assert(Contains(lsi:GetSoundProfileReport(), "No capture recorded"))
Command("probe 567542 1")
assert(muted[567542])
Advance(1)
assert(not next(muted))
Command("profile")
local visual = frames.LibSoundIndexProfiler
assert(visual.shown and visual.capture.text == "Start Capture" and visual.empty.shown)

visual.capture.scripts.OnClick()
visual.scripts.OnUpdate(visual)
assert(visual.capture.text == "Stop Capture")
inventory[13] = 30293
Fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
hooks.PlaySoundFile(510000)
visual.scripts.OnUpdate(visual)

local removed, equipped = visual.rows[1], visual.rows[2]
assert(removed.item.id == 22954 and equipped.item.id == 30293 and not visual.rows[3].shown)
assert(removed.name.text == "Kiss of the Spider  |  Item 22954" and removed.icon.texture == 134339)
assert(equipped.name.text == "Heavenly Inspiration  |  Item 30293" and equipped.icon.texture == 136047)
assert(removed.roles.text == "Removed" and equipped.roles.text == "Equipped")
assert(removed.files.text == "567544, 567549" and equipped.files.text == "567542, 567551")
assert(not equipped.probe.enabled, "probe buttons must be disabled during capture")

inventory[13] = 22954
Fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
visual.capture.scripts.OnClick()
visual.scripts.OnUpdate(visual)
assert(equipped.roles.text == "Equipped, Removed", "the same item across multiple swaps must share one row")
assert(equipped.probe.enabled and visual.probeAll.enabled and not visual.nextPage.enabled)
equipped.probe.scripts.OnClick()
assert(muted[567542] and muted[567551] and not muted[567544] and not muted[510000])
visual.scripts.OnUpdate(visual)
visual.results[3].scripts.OnClick()
visual.copy.scripts.OnClick()
assert(Contains(dump.edit.text, "Item 30293 (Equipped, Removed) [567542,567551]"))
assert(Contains(dump.edit.text, "Probe item 30293, acquired 2/2 for 5s, heard result quiet"))
Advance(5)
assert(not next(muted))

visual.capture.scripts.OnClick()
for _, id in ipairs({ 25, 35, 17, 18820, 30293, 19019, 999999 }) do
    inventory[13] = id
    Fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
end
visual.capture.scripts.OnClick()
visual.scripts.OnUpdate(visual)
assert(visual.pageLabel.text == "1 / 2" and visual.nextPage.enabled)
visual.nextPage.scripts.OnClick()
assert(visual.pageLabel.text == "2 / 2" and not visual.nextPage.enabled and visual.previous.enabled)
assert(visual.rows[2].item.id == 999999 and visual.rows[2].files.text == "No candidate FileDataIDs")
assert(visual.rows[2].icon.texture == 134400 and not visual.rows[2].probe.enabled)
assert(not visual.rows[3].shown, "paging must hide rows left over from the previous page")
visual.previous.scripts.OnClick()
assert(visual.pageLabel.text == "1 / 2" and visual.rows[1].item.id == 22954)
visual.probeAll.scripts.OnClick()
assert(muted[567542] and muted[567544] and not muted[510000])
Advance(5)
assert(not next(muted))

print("LibSoundIndex capture, visual item grouping, probe, and dump checks passed.")
