--[[
    modules/ui/create_listing_hooks.lua
    Handles adding TSC price info to create listing tooltips
    Exposes: setupCreateListingHooks
]]

local CreateListingHooks = {}

-- Track current item and whether we've added price info
local currentListingItemLink = nil
local hasAddedPriceInfo = false

-- Shared state to prevent duplicate additions across different systems
local processedTooltips = {}

--[[
    Hook function for create listing tooltips
]]
local function OnCreateListingTooltip(tooltipObject, tooltipType, itemLink)
    -- Only process if we're in the create listing scene
    if not TRADING_HOUSE_CREATE_LISTING_GAMEPAD_SCENE or not TRADING_HOUSE_CREATE_LISTING_GAMEPAD_SCENE:IsShowing() then
        return
    end

    -- Only process left tooltip
    if tooltipType ~= GAMEPAD_LEFT_TOOLTIP then
        return
    end

    local tooltip = tooltipObject:GetTooltip(tooltipType)
    if not tooltip then
        return
    end

    -- Generate a unique tooltip identifier
    local tooltipId = tostring(tooltip)
    if processedTooltips[tooltipId] then
        return
    end

    -- Add price info
    local success, result = pcall(function()
        TSC_UtilsModule.AddPriceInfoSection(tooltip, itemLink)
        processedTooltips[tooltipId] = true
        hasAddedPriceInfo = true
        return true
    end)
end

--[[
    Sets up the create listing hooks
]]
function CreateListingHooks.setupCreateListingHooks()
    -- Hook into scene state changes
    if TRADING_HOUSE_CREATE_LISTING_GAMEPAD_SCENE then
        TRADING_HOUSE_CREATE_LISTING_GAMEPAD_SCENE:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWING then
                currentListingItemLink = nil
                hasAddedPriceInfo = false
                processedTooltips = {} -- Clear processed tooltips cache
            elseif newState == SCENE_HIDDEN then
                currentListingItemLink = nil
                hasAddedPriceInfo = false
                processedTooltips = {} -- Clear processed tooltips cache
            end
        end)
    end

    -- Hook into create listing function
    if ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing then
        ZO_PostHook("ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing",
            function(selectedData, bag, index, listingPrice)
                local itemLink = GetItemLink(bag, index)
                currentListingItemLink = itemLink
                hasAddedPriceInfo = false

                -- Try to add price info with retries
                local attempts = 0
                local maxAttempts = 3

                local function tryAddPriceInfo()
                    attempts = attempts + 1

                    if TRADING_HOUSE_CREATE_LISTING_GAMEPAD_SCENE and TRADING_HOUSE_CREATE_LISTING_GAMEPAD_SCENE:IsShowing() then
                        if GAMEPAD_TOOLTIPS and itemLink then
                            OnCreateListingTooltip(GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP, itemLink)
                        end
                    end

                    if not hasAddedPriceInfo and attempts < maxAttempts then
                        zo_callLater(tryAddPriceInfo, 200)
                    end
                end

                zo_callLater(tryAddPriceInfo, 100)
            end
        )
    end
end

TSC_CreateListingHooksModule = CreateListingHooks
return CreateListingHooks
