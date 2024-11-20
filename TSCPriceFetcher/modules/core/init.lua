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

-- Helper: Extract itemLink from selectedData
local function ExtractItemLink(selectedData)
    if not selectedData then return nil end
    if selectedData.bagId and selectedData.slotIndex then
        return GetItemLink(selectedData.bagId, selectedData.slotIndex)
    elseif selectedData.itemLink then
        return selectedData.itemLink
    end
    return nil
end

-- Helper: Validate selectedData for price display
local function IsValidItem(selectedData, itemLink)
    if not selectedData then return false end
    if selectedData.isCurrencyEntry or selectedData.isMundusEntry then return false end
    if not itemLink then return false end
    local itemName = GetItemLinkName(itemLink)
    if not itemName or itemName == "" then return false end
    return true
end

-- Handler for inventory tooltip
local function OnGamepadInventoryTooltip(self, selectedData)
    local itemLink = ExtractItemLink(selectedData)
    if not IsValidItem(selectedData, itemLink) then return end

    local tooltipObject = GAMEPAD_TOOLTIPS
    local tooltipType = GAMEPAD_LEFT_TOOLTIP

    TSCPriceFetcher.modules.tooltips.AddPriceToGamepadTooltip(tooltipObject, tooltipType, itemLink)
end

local function HookGamepadTooltips()
    SecurePostHook(ZO_GamepadInventory, "UpdateItemLeftTooltip", OnGamepadInventoryTooltip)
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
