---@diagnostic disable: undefined-global

--[[
    modules/core/events.lua
    Handles event registration and unregistration for the addon.
    Exposes: register, unregister, registerAll
]]

local Events = {}

-- Table to keep track of registered events and their handlers
Events.registered = {}

-- Register an event with a handler
function Events.register(event, callback)
    EVENT_MANAGER:RegisterForEvent(TSCPriceFetcher.name, event, callback)
    Events.registered[event] = callback
end

-- Unregister an event
function Events.unregister(event)
    EVENT_MANAGER:UnregisterForEvent(TSCPriceFetcher.name, event)
    Events.registered[event] = nil
end

-- Register all events needed for the addon
function Events.registerAll()
    Events.register(EVENT_ADD_ON_LOADED, function(event, addonName)
        if addonName == TSCPriceFetcher.name then
            TSCPriceFetcher.modules.init.initialize()
            Events.unregister(EVENT_ADD_ON_LOADED)
        end
    end)

    Events.register(EVENT_PLAYER_ACTIVATED, function()
        TSCPriceFetcher.initializeDataSource()
        Events.unregister(EVENT_PLAYER_ACTIVATED)
    end)
end

TSC_EventsModule = Events
return Events
