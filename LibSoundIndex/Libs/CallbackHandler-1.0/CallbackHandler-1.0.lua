--[[ $Id: CallbackHandler-1.0.lua 3 2008-09-26 12:00:00Z nevcairiel $ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
    RegisterName = RegisterName or "RegisterCallback"
    UnregisterName = UnregisterName or "UnregisterCallback"
    if UnregisterAllName == nil then
        UnregisterAllName = "UnregisterAllCallbacks"
    end

    local events = setmetatable({}, meta)
    local registry = { recurse = 0, events = events }

    function registry:Fire(eventname, ...)
        if not rawget(events, eventname) or not next(events[eventname]) then return end
        local oldrecurse = registry.recurse
        registry.recurse = oldrecurse + 1

        Dispatch(events[eventname], eventname, ...)

        registry.recurse = oldrecurse
        if registry.recurse == 0 then
            -- No more recursion, clean up removed entries
        end
    end

    target[RegisterName] = function(self, eventname, method, ... )
        if type(eventname) ~= "string" then
            error("Usage: " .. RegisterName .. "(eventname, method[, arg]): 'eventname' - string expected.", 2)
        end
        method = method or eventname
        local first = not rawget(events, eventname) or not next(events[eventname])

        if type(method) == "string" then
            if type(self) ~= "table" then
                error("Usage: " .. RegisterName .. "(\"eventname\", \"methodname\"): self was not a table", 2)
            elseif self == target then
                error("Usage: " .. RegisterName .. "(\"eventname\", \"methodname\"): do not use Library:" .. RegisterName .. "(), use your own 'self'", 2)
            elseif type(self[method]) ~= "function" then
                error("Usage: " .. RegisterName .. "(\"eventname\", \"methodname\"): 'methodname' - method '" .. tostring(method) .. "' not found on self.", 2)
            end
            events[eventname][self] = { method, select("#", ...) > 0 and {...} or nil }
        elseif type(method) == "function" then
            events[eventname][self] = { method, select("#", ...) > 0 and {...} or nil }
        else
            error("Usage: " .. RegisterName .. "(\"eventname\", \"method\"): 'method' - function or string expected.", 2)
        end

        if first and registry.OnUsed then
            registry.OnUsed(registry, target, eventname)
        end
    end

    target[UnregisterName] = function(self, eventname)
        if not self or self == target then
            error("Usage: " .. UnregisterName .. "(eventname): bad 'self'", 2)
        end
        if type(eventname) ~= "string" then
            error("Usage: " .. UnregisterName .. "(eventname): 'eventname' - string expected.", 2)
        end
        if rawget(events, eventname) and events[eventname][self] then
            events[eventname][self] = nil
            if not next(events[eventname]) and registry.OnUnused then
                registry.OnUnused(registry, target, eventname)
            end
        end
    end

    if UnregisterAllName then
        target[UnregisterAllName] = function(...)
            if select("#", ...) < 1 then
                error("Usage: " .. UnregisterAllName .. "([whatFor]): missing 'self' or \"addonId\" to unregister events for.", 2)
            end
            local first = ...
            if first ~= target then
                for eventname, callbacks in pairs(events) do
                    if callbacks[first] then
                        callbacks[first] = nil
                        if not next(callbacks) and registry.OnUnused then
                            registry.OnUnused(registry, target, eventname)
                        end
                    end
                end
            end
        end
    end

    return registry
end

local function Dispatch(handlers, ...)
    for obj, reg in pairs(handlers) do
        local method, args = reg[1], reg[2]
        if type(method) == "string" then
            if args then
                obj[method](obj, unpack(args), ...)
            else
                obj[method](obj, ...)
            end
        elseif type(method) == "function" then
            if args then
                method(unpack(args), ...)
            else
                method(...)
            end
        end
    end
end
