-- Opt-in Lua sound and equipment diagnostics.
local lib, minor = LibStub:GetLibrary("LibSoundIndex-1.0", true)
if not lib or minor < 3 or lib.GetSoundProfileReport then return end

local MAX_EVENTS, MAX_PROBES, MAX_FILES = 100, 6, 128
local profile, equipmentFrame, listenerFrame, dumpFrame, profilerFrame
local probes, hooks = {}, {}

local function IsPublic(value)
    return not issecretvalue or not issecretvalue(value)
end

local function IsID(value)
    return IsPublic(value) and type(value) == "number" and value > 0
        and value <= 4294967295 and value % 1 == 0
end

local function Notify(message)
    print("|cff00ff00LibSoundIndex|r " .. message)
end

local function UniqueFiles(first, second)
    local files, seen = {}, {}
    local function Add(ids)
        for _, id in ipairs(ids) do
            if not seen[id] then
                files[#files + 1] = id
                seen[id] = true
            end
        end
    end
    Add(first)
    if second then Add(second) end
    table.sort(files)
    return files
end

local function FormatFiles(files, limit)
    if #files == 0 then return "-" end
    local output = table.concat(files, ",", 1, math.min(limit, #files))
    if #files > limit then
        output = output .. (" (+%d more)"):format(#files - limit)
    end
    return output
end

local function RefreshProfilerLater()
    if profilerFrame then profilerFrame.dirty = true end
end

local function Record(kind, detail, files, group, items)
    if profile and profile.active then
        profile.total = profile.total + 1
        profile.events[(profile.total - 1) % MAX_EVENTS + 1] = {
            at = GetTime() - profile.startedAt,
            detail = kind .. " " .. detail,
            files = files,
            group = group,
            items = items,
        }
        RefreshProfilerLater()
    end
    if listenerFrame and listenerFrame:IsShown() then
        listenerFrame.msgFrame:AddMessage(kind .. " " .. detail)
    end
end

local function IsObserving()
    return (profile and profile.active) or (listenerFrame and listenerFrame:IsShown())
end

local function ObserveKit(id)
    if not IsObserving() or not IsID(id) then return end
    Record("Lua SoundKit", tostring(id), lib:GetFileDataIDs(id), "lua")
end

local function ObserveFile(id)
    if not IsObserving() or not IsPublic(id) then return end
    if IsID(id) then
        Record("Lua FileDataID", tostring(id), {id}, "lua")
    elseif type(id) == "string" then
        Record("Lua file path", "(path omitted)", {}, "lua")
    end
end

local function ObserveItemSound(action, location)
    if not IsObserving() then return end
    if not IsPublic(location) or not C_Item or type(C_Item.GetItemID) ~= "function" then return end
    local ok, id = pcall(C_Item.GetItemID, location)
    local label = IsPublic(action) and type(action) == "number" and tostring(action) or "?"
    if not ok or not IsID(id) then
        Record("Lua item sound", "action=" .. label .. " item=unavailable", {}, "items")
        return
    end
    Record("Lua item sound", "action=" .. label .. " item=" .. id, lib:GetItemSoundFileDataIDs(id), "items",
        {{id = id, role = "Lua call"}})
end

local function InstallHooks()
    if type(hooksecurefunc) ~= "function" then return end
    local callbacks = { PlaySound = ObserveKit, PlaySoundFile = ObserveFile }
    for name, callback in pairs(callbacks) do
        if type(_G[name]) == "function" and not hooks[name] then
            hooks[name] = pcall(hooksecurefunc, name, callback) or nil
        end
    end
    callbacks.PlayItemSound = ObserveItemSound
    for name, callback in pairs(callbacks) do
        local key = "C_Sound." .. name
        if C_Sound and type(C_Sound[name]) == "function" and not hooks[key] then
            hooks[key] = pcall(hooksecurefunc, C_Sound, name, callback) or nil
        end
    end
end

local function ReadEquippedItem(slot)
    if type(GetInventoryItemID) ~= "function" then return end
    local ok, id = pcall(GetInventoryItemID, "player", slot)
    if not ok or not IsPublic(id) then return end
    if id == nil or id == 0 then return 0 end
    if IsID(id) then return id end
end

local function SampleSlot(slot, hasCurrent)
    local current = ReadEquippedItem(slot)
    if current == nil or (current == 0 and hasCurrent == true) then return end
    local previous = profile.equipment[slot]
    profile.equipment[slot] = current
    if previous ~= nil and previous ~= current then
        local oldFiles = lib:GetItemSoundFileDataIDs(previous)
        local newFiles = lib:GetItemSoundFileDataIDs(current)
        Record("Equipment change", ("slot=%d %d -> %d (old=%d new=%d files)"):format(
            slot, previous, current, #oldFiles, #newFiles), UniqueFiles(oldFiles, newFiles), "items",
            {{id = previous, role = "Removed"}, {id = current, role = "Equipped"}})
    end
end

local function SampleEquipment()
    for slot = 0, 19 do SampleSlot(slot) end
end

local function CreateEquipmentObserver()
    if equipmentFrame then return end
    equipmentFrame = CreateFrame("Frame")
    equipmentFrame:SetScript("OnEvent", function(_, event, value, hasCurrent)
        if not profile or not profile.active or not IsPublic(value) then return end
        if event == "PLAYER_EQUIPMENT_CHANGED" and type(value) == "number"
            and value >= 0 and value <= 19 and value % 1 == 0 then
            SampleSlot(value, IsPublic(hasCurrent) and hasCurrent)
        elseif event == "UNIT_INVENTORY_CHANGED" and value == "player" then
            SampleEquipment()
        end
    end)
end

local function StopCapture()
    if not profile or not profile.active then return end
    SampleEquipment()
    profile.active = false
    profile.stoppedAt = GetTime()
    equipmentFrame:UnregisterAllEvents()
    lib.RecordProfileSwapMute = nil
    RefreshProfilerLater()
    Notify(("Capture stopped with %d events. Use /lsi probe items or /lsi dump."):format(profile.total))
end

local function ReadCVar(name)
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if type(getter) == "function" then
        local ok, value = pcall(getter, name)
        if ok and IsPublic(value) and (value == "0" or value == "1") then return value end
    end
    return "unknown"
end

local function AudioSettings()
    local swapSetting = ItemRackSettings and ItemRackSettings.DisableSwapSound
    if not IsPublic(swapSetting) then swapSetting = nil end
    return ("game sound %s, SFX %s, ItemRack swap mute %s"):format(
        ReadCVar("Sound_EnableAllSound"), ReadCVar("Sound_EnableSFX"),
        (swapSetting == "ON" or swapSetting == "OFF") and swapSetting or "unknown")
end

local function StartCapture(seconds)
    if not C_Timer or type(C_Timer.After) ~= "function" then
        Notify("Capture timer unavailable.")
        return
    end
    InstallHooks()
    CreateEquipmentObserver()
    local nextProfile = {
        active = true,
        startedAt = GetTime(),
        events = {},
        total = 0,
        equipment = {},
        audioSettings = AudioSettings(),
    }
    local scheduled = pcall(C_Timer.After, seconds, function()
        if profile == nextProfile then StopCapture() end
    end)
    if not scheduled then
        Notify("Could not start the capture timer.")
        return
    end
    profile, probes = nextProfile, {}
    if profilerFrame then profilerFrame.page = 1 end
    RefreshProfilerLater()
    profile.equipmentEvents = pcall(equipmentFrame.RegisterEvent, equipmentFrame, "PLAYER_EQUIPMENT_CHANGED")
    profile.inventoryEvents = pcall(equipmentFrame.RegisterEvent, equipmentFrame, "UNIT_INVENTORY_CHANGED")
    SampleEquipment()
    lib.RecordProfileSwapMute = function(_, source, destination, files, acquired, duration)
        if IsPublic(duration) and type(duration) == "number" then
            Record("Item mute request", ("%d -> %d acquired=%d for %.2fs"):format(
                source or 0, destination or 0, acquired, duration), UniqueFiles(files), "items",
                {{id = source, role = "Mute request"}, {id = destination, role = "Mute request"}})
        end
    end
    Notify(("Capturing for %ds. Swap your gear, then use /lsi debug stop."):format(seconds))
end

local function VisitEvents(visitor)
    if not profile then return end
    for i = math.max(1, profile.total - MAX_EVENTS + 1), profile.total do
        visitor(profile.events[(i - 1) % MAX_EVENTS + 1])
    end
end

local function ProfileFiles(scope)
    local found, files = {}, {}
    VisitEvents(function(event)
        if scope == "all" or scope == event.group then
            for _, id in ipairs(event.files) do
                if not found[id] then
                    found[id] = true
                    files[#files + 1] = id
                end
            end
        end
    end)
    table.sort(files)
    return files
end

local ITEM_ROLES = {"Equipped", "Removed", "Lua call", "Mute request"}

local function ProfileItems()
    local items, byID = {}, {}
    VisitEvents(function(event)
        for _, entry in ipairs(event.items or {}) do
            local id = entry.id
            if IsID(id) then
                local item = byID[id]
                if not item then
                    item = {id = id, files = lib:GetItemSoundFileDataIDs(id), roles = {}}
                    items[#items + 1] = item
                    byID[id] = item
                end
                item.roles[entry.role] = true
            end
        end
    end)
    return items
end

local function FormatRoles(item)
    local roles = {}
    for _, role in ipairs(ITEM_ROLES) do
        if item.roles[role] then roles[#roles + 1] = role end
    end
    return table.concat(roles, ", ")
end

local function ParseSeconds(text, default, maximum)
    if text == "" then return default end
    local value = tonumber(text)
    if value and value >= 1 and value <= maximum and value % 1 == 0 then return value end
end

local function ApplyProbe(scope, files, duration)
    if #files == 0 then
        Notify("This profile has no matching file IDs. Capture a gear swap or supply a FileDataID.")
        return
    end
    if #files > MAX_FILES then
        Notify(("Profile contains %d files. Use a narrower capture or probe a single FileDataID."):format(#files))
        return
    end
    local acquired = lib:MuteFileDataIDsForDuration(files, duration)
    if #probes == MAX_PROBES then table.remove(probes, 1) end
    probes[#probes + 1] = {scope = scope, files = files, acquired = acquired, duration = duration}
    RefreshProfilerLater()
    if acquired > 0 then
        Notify(("%d of %d files muted for %ds. Repeat the swap now."):format(acquired, #files, duration))
    else
        Notify("No files were muted. Use /lsi info to check mute API availability.")
    end
end

local function Probe(scope, duration)
    local id = tonumber(scope)
    local files
    if IsID(id) and scope:match("^%d+$") then
        files = {id}
    elseif scope == "items" or scope == "lua" or scope == "all" then
        if profile and profile.active then
            Notify("Stop capturing before muting a profile.")
            return
        end
        files = ProfileFiles(scope)
    else
        Notify("Usage: /lsi probe [items|lua|all|FileDataID] [seconds]")
        return
    end
    ApplyProbe(scope, files, duration)
end

local function ItemRackVersion()
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if type(getter) == "function" then
        local ok, version = pcall(getter, "ItemRack", "Version")
        if ok and IsPublic(version) and type(version) == "string" then return version end
    end
    return "unavailable"
end

function lib:GetSoundProfileReport()
    local game, build, _, interface = GetBuildInfo()
    local hookNames = {}
    for name in pairs(hooks) do hookNames[#hookNames + 1] = name end
    table.sort(hookNames)
    local lines = {
        ("LibSoundIndex sound profile (library revision %d)"):format(minor),
        ("Client %s %s build %s, interface %s"):format(self:GetClientKey(), game, build, tostring(interface)),
        "Item data build " .. (self.ItemSoundData and self.ItemSoundData.build or "unavailable"),
        "ItemRack version " .. ItemRackVersion(),
        "File mute API " .. (
            type(MuteSoundFile) == "function" and type(UnmuteSoundFile) == "function" and "available" or "unavailable"),
        "Audio settings at export " .. AudioSettings(),
        "Lua hooks " .. (#hookNames > 0 and table.concat(hookNames, ", ") or "none installed"),
        "Lua hooks record calls. Equipment changes and item sound calls provide candidate files.",
    }
    if profile then
        lines[#lines + 1] = ("Capture %s after %.2fs, %d events, %d older events discarded"):format(
            profile.active and "active" or "stopped", (profile.stoppedAt or GetTime()) - profile.startedAt,
            profile.total, math.max(0, profile.total - MAX_EVENTS))
        lines[#lines + 1] = "Audio settings at capture start " .. profile.audioSettings
        lines[#lines + 1] = ("Equipment event %s, inventory event %s"):format(
            profile.equipmentEvents and "registered" or "unavailable",
            profile.inventoryEvents and "registered" or "unavailable")
        lines[#lines + 1] = "Item candidate files " .. FormatFiles(ProfileFiles("items"), MAX_FILES)
        lines[#lines + 1] = "Lua request files " .. FormatFiles(ProfileFiles("lua"), MAX_FILES)
        for _, item in ipairs(ProfileItems()) do
            lines[#lines + 1] = ("Item %d (%s) [%s]"):format(item.id, FormatRoles(item), FormatFiles(item.files, MAX_FILES))
        end
        VisitEvents(function(event)
            lines[#lines + 1] = ("+%.2fs %s [%s]"):format(event.at, event.detail, FormatFiles(event.files, 8))
        end)
    else
        lines[#lines + 1] = "No capture recorded. Use /lsi debug start."
    end
    for _, probe in ipairs(probes) do
        lines[#lines + 1] = ("Probe %s, acquired %d/%d for %ds, heard result %s [%s]"):format(
            probe.scope, probe.acquired, #probe.files, probe.duration, probe.result or "unreported", FormatFiles(probe.files, 20))
    end
    return table.concat(lines, "\n")
end

local function ShowDump()
    if not dumpFrame then
        local frame = CreateFrame("Frame", "LibSoundIndexProfileDump", UIParent, "BackdropTemplate")
        frame:SetSize(680, 420)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
        frame:SetBackdropColor(0.08, 0.08, 0.08, 0.98)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Sound Profile  |  Ctrl+C to copy")

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -34)
        scroll:SetPoint("BOTTOMRIGHT", -34, 14)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetMaxLetters(0)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(620)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)
        frame.scroll, frame.edit = scroll, edit
        dumpFrame = frame
    end
    local report = lib:GetSoundProfileReport()
    local _, newlines = report:gsub("\n", "")
    dumpFrame.edit:SetHeight(math.max(370, (newlines * 2 + 10) * 16))
    dumpFrame.edit:SetText(report)
    dumpFrame.scroll:UpdateScrollChildRect()
    dumpFrame:Show()
    dumpFrame:Raise()
    dumpFrame.edit:SetFocus()
    dumpFrame.edit:HighlightText()
    dumpFrame.scroll:SetVerticalScroll(0)
end

local function ShowListener()
    if listenerFrame then
        listenerFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "LibSoundIndexListener", UIParent, "BackdropTemplate")
    frame:SetSize(420, 300)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
    frame:SetBackdropColor(0, 0, 0, 0.85)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -9)
    title:SetText("LibSoundIndex Sound Listener")

    local messages = CreateFrame("ScrollingMessageFrame", nil, frame)
    messages:SetPoint("TOPLEFT", 12, -32)
    messages:SetPoint("BOTTOMRIGHT", -12, 34)
    messages:SetFontObject(ChatFontNormal)
    messages:SetJustifyH("LEFT")
    messages:SetFading(false)
    messages:SetMaxLines(MAX_EVENTS)
    messages:AddMessage("Drop an item here to inspect its sound files.")
    messages:AddMessage("Use /lsi debug start to capture a gear swap.")
    frame.msgFrame = messages

    local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetSize(60, 22)
    clear:SetPoint("BOTTOM", 0, 6)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function() messages:Clear() end)

    frame:SetScript("OnReceiveDrag", function()
        local kind, itemID, itemLink = GetCursorInfo()
        if not IsPublic(kind) or kind ~= "item" then return end
        ClearCursor()
        lib:DebugAnalyzeItem(IsPublic(itemLink) and itemLink or itemID)
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and CursorHasItem() then
            self:GetScript("OnReceiveDrag")()
        end
    end)
    listenerFrame = frame
    InstallHooks()
end

local function SaveProbeResult(result)
    local latest = probes[#probes]
    if latest and (result == "quiet" or result == "partial" or result == "audible") then
        latest.result = result
        RefreshProfilerLater()
        Notify("Saved listening result in the sound dump.")
    else
        Notify("Run a probe, then choose a quiet, partial, or audible result.")
    end
end

local function ItemAppearance(id)
    local name, icon
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getInfo) == "function" then
        local ok, value, _, _, _, _, _, _, _, _, texture = pcall(getInfo, id)
        if ok and IsPublic(value) and type(value) == "string" then name = value end
        if ok and IsPublic(texture) then icon = texture end
    end
    local getIcon = C_Item and C_Item.GetItemIconByID or GetItemIcon
    if not icon and type(getIcon) == "function" then
        local ok, texture = pcall(getIcon, id)
        if ok and IsPublic(texture) then icon = texture end
    end
    return name, icon or 134400
end

local function RefreshProfiler(frame)
    local items = ProfileItems()
    local active = profile and profile.active or false
    local pages = math.max(1, math.ceil(#items / #frame.rows))
    frame.page = math.max(1, math.min(frame.page, pages))
    frame.dirty = false

    frame.capture:SetText(active and "Stop Capture" or "Start Capture")
    frame.probeAll:SetEnabled(not active and #ProfileFiles("items") > 0)
    frame.previous:SetEnabled(frame.page > 1)
    frame.nextPage:SetEnabled(frame.page < pages)
    frame.pageLabel:SetText(("%d / %d"):format(frame.page, pages))
    frame.status:SetText(active and ("%d items  |  Recording"):format(#items) or ("%d items"):format(#items))
    frame.empty:SetShown(#items == 0)
    frame.empty:SetText(active and "Waiting for an equipment change."
        or "Start a capture, then swap gear. Turn off ItemRack swap muting for the baseline.")

    for index, row in ipairs(frame.rows) do
        local item = items[(frame.page - 1) * #frame.rows + index]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            local name, icon = ItemAppearance(item.id)
            row.icon:SetTexture(icon)
            local itemLabel = ("Item %d"):format(item.id)
            row.name:SetText(name and (name .. "  |  " .. itemLabel) or itemLabel)
            row.roles:SetText(FormatRoles(item))
            row.files:SetText(#item.files > 0 and table.concat(item.files, ", ") or "No candidate FileDataIDs")
            row.probe:SetEnabled(not active and #item.files > 0)
        end
    end

    local latest = probes[#probes]
    frame.outcome:SetText(latest and ("Last probe  %d/%d files  |  %ss  |  %s"):format(
        latest.acquired, #latest.files, latest.duration, latest.result or "Record what you heard")
        or "Probes apply for five seconds.")
    for _, button in ipairs(frame.results) do
        button:SetEnabled(latest ~= nil and latest.acquired > 0)
    end
end

local function ProfileButton(parent, text, width, click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", click)
    return button
end

local function CreateProfileRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 16, -91 - (index - 1) * 61)
    row:SetSize(666, 58)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.10, 0.12, 0.15, 0.9)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 9, 0)
    row.icon:SetSize(38, 38)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 58, -7)
    row.name:SetWidth(282)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.roles = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.roles:SetPoint("TOPRIGHT", -91, -9)

    row.files = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.files:SetPoint("TOPLEFT", 58, -24)
    row.files:SetWidth(510)
    row.files:SetJustifyH("LEFT")

    row.probe = ProfileButton(row, "Probe", 68, function()
        if row.item and not (profile and profile.active) then
            ApplyProbe("item " .. row.item.id, row.item.files, 5)
        end
    end)
    row.probe:SetPoint("RIGHT", -8, 0)
    return row
end

local function ShowProfiler()
    if not profilerFrame then
        local frame = CreateFrame("Frame", "LibSoundIndexProfiler", UIParent, "BackdropTemplate")
        frame:Hide()
        frame:SetSize(698, 535)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
        frame:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
        frame.rows, frame.results, frame.page = {}, {}, 1
        frame:SetScript("OnUpdate", function(self)
            if self.dirty then RefreshProfiler(self) end
        end)
        frame:SetScript("OnShow", function(self)
            pcall(self.RegisterEvent, self, "GET_ITEM_INFO_RECEIVED")
        end)
        frame:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
        frame:SetScript("OnEvent", RefreshProfilerLater)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText("Gear Swap Sound Profiler")
        frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.status:SetPoint("TOPRIGHT", -34, -17)

        frame.capture = ProfileButton(frame, "Start Capture", 114, function()
            if profile and profile.active then StopCapture() else StartCapture(30) end
        end)
        frame.capture:SetPoint("TOPLEFT", 16, -42)
        frame.probeAll = ProfileButton(frame, "Probe All Items", 110, function() Probe("items", 5) end)
        frame.probeAll:SetPoint("LEFT", frame.capture, "RIGHT", 8, 0)
        frame.luaCalls = ProfileButton(frame, "Lua Listener", 98, ShowListener)
        frame.luaCalls:SetPoint("LEFT", frame.probeAll, "RIGHT", 8, 0)
        frame.copy = ProfileButton(frame, "Copy Report", 103, ShowDump)
        frame.copy:SetPoint("TOPRIGHT", -16, -42)

        local column = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        column:SetPoint("TOPLEFT", 16, -74)
        column:SetText("ITEMS AND CANDIDATE FILEDATAIDS")
        frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.empty:SetPoint("TOPLEFT", 16, -110)
        for index = 1, 6 do
            frame.rows[index] = CreateProfileRow(frame, index)
        end

        frame.previous = ProfileButton(frame, "Previous", 72, function()
            frame.page = frame.page - 1
            RefreshProfiler(frame)
        end)
        frame.previous:SetPoint("BOTTOMLEFT", 16, 44)
        frame.nextPage = ProfileButton(frame, "Next", 64, function()
            frame.page = frame.page + 1
            RefreshProfiler(frame)
        end)
        frame.nextPage:SetPoint("LEFT", frame.previous, "RIGHT", 7, 0)
        frame.pageLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.pageLabel:SetPoint("LEFT", frame.nextPage, "RIGHT", 10, 0)
        frame.outcome = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.outcome:SetPoint("BOTTOMLEFT", 16, 17)
        for index, result in ipairs({"audible", "partial", "quiet"}) do
            local button = ProfileButton(frame, result:gsub("^%l", string.upper), 72, function() SaveProbeResult(result) end)
            button:SetPoint("BOTTOMRIGHT", -16 - (index - 1) * 79, 10)
            frame.results[index] = button
        end
        profilerFrame = frame
    end

    profilerFrame:Show()
    profilerFrame:Raise()
    RefreshProfiler(profilerFrame)
end

local function HandleDebug(arg)
    local action, seconds = arg:match("^(%S+)%s*(.*)$")
    if action == "stop" or (not action and profile and profile.active) then
        if profile and profile.active then StopCapture() else Notify("No active capture.") end
    elseif action == "clear" then
        StopCapture()
        profile, probes = nil, {}
        RefreshProfilerLater()
        Notify("Sound profile cleared.")
    elseif action == "start" or not action then
        local duration = ParseSeconds(seconds or "", 30, 120)
        if duration then
            StartCapture(duration)
        else
            Notify("Capture length must be between 1 and 120 seconds.")
        end
    else
        Notify("Usage: /lsi debug start [seconds], stop, or clear")
    end
end

SLASH_LIBSOUNDINDEX1 = "/lsi"
SlashCmdList["LIBSOUNDINDEX"] = function(msg)
    msg = strtrim(msg or "")
    local command, arg = msg:match("^(%S+)%s*(.*)$")
    if not command or command == "info" then
        lib:PrintInfo()
    elseif command == "muteall" then
        lib:MuteAll()
        Notify("Curated sound groups muted.")
    elseif command == "unmuteall" then
        lib:UnmuteAll()
        Notify("Released library sound mutes.")
    elseif command == "profile" then
        ShowProfiler()
    elseif command == "listen" then
        ShowListener()
    elseif command == "item" then
        lib:DebugAnalyzeItem(arg)
    elseif command == "testitem" then
        local count = lib:MuteItemSwapSounds(arg, nil, 2)
        Notify(("Muted %d item candidate files for two seconds."):format(count))
    elseif command == "debug" then
        HandleDebug(arg)
    elseif command == "dump" then
        ShowDump()
    elseif command == "probe" then
        local scope, seconds = arg:match("^(%S+)%s*(.*)$")
        local duration = ParseSeconds(seconds or "", 5, 30)
        if duration then Probe(scope or "items", duration) else Notify("Probe length must be between 1 and 30 seconds.") end
    elseif command == "result" then
        SaveProbeResult(arg)
    else
        Notify("/lsi profile opens the gear swap sound profiler. /lsi debug start [seconds], stop, or clear")
        print("/lsi probe [items|lua|all|FileDataID] [seconds], /lsi result [quiet|partial|audible], /lsi dump")
        print("/lsi info, /lsi listen, /lsi item <item>, /lsi testitem <item>, /lsi muteall, /lsi unmuteall")
    end
end
