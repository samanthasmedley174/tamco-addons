--[[
    modules/core/init.lua
    Handles addon initialization and hooks for gamepad tooltips.
    Exposes: initialize, isReady
]]

local Init = {}

-- Flag to track if the addon is initialized
Init.isInitialized = false

-- Flag to prevent infinite recursion in trading house price override
local inPriceOverride = false

local function HookGamepadTooltips()
    local function OnPlayerActivated()
        EVENT_MANAGER:UnregisterForEvent("TSCUniversalContext", EVENT_PLAYER_ACTIVATED)

        zo_callLater(function()
            if GAMEPAD_TOOLTIPS then
                local leftTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
                local rightTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)

                -- Hook into LEFT tooltip
                if leftTooltip then
                    ZO_PostHook(leftTooltip, "LayoutItem", function(self, itemLink)
                        TSCPriceFetcher.modules.tooltips.AddPriceToGamepadTooltip(GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP,
                            itemLink)
                    end)
                end

                -- Hook into RIGHT tooltip
                if rightTooltip then
                    ZO_PostHook(rightTooltip, "LayoutItem", function(self, itemLink)
                        TSCPriceFetcher.modules.tooltips.AddPriceToGamepadTooltip(GAMEPAD_TOOLTIPS, GAMEPAD_RIGHT_TOOLTIP,
                        itemLink)
                    end)
                end
            end
        end, 1000)
    end

    EVENT_MANAGER:RegisterForEvent("TSCUniversalContext", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

-- Set up guild store price auto-population using SetListingPrice
local function SetupTradingHouseHooks()
    if not ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing then
        return
    end

    -- Use ZO_PostHook to update the price after the listing is created
    ZO_PostHook("ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing",
        function(selectedItem, bagId, slotIndex, initialPostPrice)
            -- Get item information
            local itemLink = GetItemLink(bagId, slotIndex)
            if not itemLink or itemLink == "" then
                return
            end

            -- Look up our price data
            local avgPricePerUnit = TSC_DataAdapterModule.getAvgPrice(itemLink)
            if not avgPricePerUnit or type(avgPricePerUnit) ~= "number" then
                return
            end

            -- Calculate total price for the stack
            local stackCount = GetSlotStackSize(bagId, slotIndex)
            local ourPrice = avgPricePerUnit * stackCount

            -- Only update if our price differs from the game's suggestion
            if ourPrice ~= initialPostPrice then
                -- Add safety checks and slight delay to ensure listing object is fully initialized
                zo_callLater(function()
                    if TRADING_HOUSE_CREATE_LISTING_GAMEPAD and TRADING_HOUSE_CREATE_LISTING_GAMEPAD.SetListingPrice then
                        -- Safely call SetListingPrice with error handling
                        local success, errorMsg = pcall(function()
                            TRADING_HOUSE_CREATE_LISTING_GAMEPAD:SetListingPrice(ourPrice)
                        end)

                        if not success then
                            -- If SetListingPrice fails, fall back to the double call method
                            if not inPriceOverride then
                                inPriceOverride = true
                                ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing(selectedItem, bagId, slotIndex,
                                    ourPrice)
                                inPriceOverride = false
                            end
                        end
                    end
                end, 50) -- Small delay to ensure UI is fully initialized
            end
        end)
end

--- Initializes the addon (called on EVENT_ADD_ON_LOADED)
function Init.initialize()
    if Init.isInitialized then
        return
    end

    -- Initialize data source detection
    TSCPriceFetcher.initializeDataSource()

    Init.isInitialized = true

    -- Set up existing hooks
    HookGamepadTooltips()
    SetupTradingHouseHooks()
    TSCPriceFetcher.modules.createListingHooks.setupCreateListingHooks()
end

--- Returns true if the addon is initialized
function Init.isReady()
    return Init.isInitialized
end

TSC_InitModule = Init
return Init
