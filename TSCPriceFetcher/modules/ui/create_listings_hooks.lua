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

local function colorize(msg, color)
    return string.format("|c%s%s|r", color, tostring(msg))
end

--[[
    Checks if the tooltip already contains TSC price info
    Enhanced version that checks for any TSC content
    @param tooltip (table): The tooltip object to check
    @return (boolean): true if price info is present
]]
local function TooltipHasPriceInfo(tooltip)
    if not tooltip then return false end

    -- Generate a unique tooltip identifier
    local tooltipId = tostring(tooltip)
    if processedTooltips[tooltipId] then
        -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Tooltip already processed (cached)")
        return true
    end

    -- Check scrollTooltip.contents
    if tooltip.scrollTooltip and tooltip.scrollTooltip.contents and tooltip.scrollTooltip.contents.GetNumChildren then
        local content = tooltip.scrollTooltip.contents
        local numChildren = content:GetNumChildren()
        for i = 1, numChildren do
            local child = content:GetChild(i)
            if child and child.GetText then
                local text = child:GetText()
                if text and (text:find("Tamriel Savings Co") or text:find("Average Price:") or text:find("No Price Data Available") or text:find("Bound Item")) then
                    -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Found existing TSC content in scrollTooltip")
                    processedTooltips[tooltipId] = true
                    return true
                end
            end
        end
    end

    -- Check direct children
    if tooltip.GetNumChildren then
        local numChildren = tooltip:GetNumChildren()
        for i = 1, numChildren do
            local child = tooltip:GetChild(i)
            if child and child.GetText then
                local text = child:GetText()
                if text and (text:find("Tamriel Savings Co") or text:find("Average Price:") or text:find("No Price Data Available") or text:find("Bound Item")) then
                    -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Found existing TSC content in direct children")
                    processedTooltips[tooltipId] = true
                    return true
                end
            end
        end
    end

    return false
end

--[[
    Adds TSC price info section to the create listing tooltip
    @param tooltip (table): The tooltip object to modify
    @param itemLink (string): The item link being listed
]]
local function AddPriceInfoSection(tooltip, itemLink)
    -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Checking if should add price info for: " .. tostring(itemLink))

    -- Check if we already have price info in this tooltip
    if TooltipHasPriceInfo(tooltip) then
        -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Price info already present, skipping")
        return
    end

    -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Adding price info section")

    -- Mark this tooltip as processed
    local tooltipId = tostring(tooltip)
    processedTooltips[tooltipId] = true

    -- Use the same price info logic as regular tooltips
    local priceSection = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    priceSection:AddLine(colorize("Tamriel Savings Co", "009449"), tooltip:GetStyle("bodyDescription"))

    -- Check if item is bound
    if IsItemLinkBound(itemLink) then
        priceSection:AddLine("Bound Item", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        hasAddedPriceInfo = true
        -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Added bound item message")
        return
    end

    -- Get price data
    local formattedPrice = TSC_DataAdapterModule.getFormattedAvgPrice(itemLink)
    local priceRange = TSC_DataAdapterModule.getFormattedPriceRange(itemLink)
    local salesCount = TSC_DataAdapterModule.getSalesCount(itemLink)

    -- Check if we have any data
    local hasData = formattedPrice or priceRange or salesCount

    if not hasData then
        priceSection:AddLine("No Price Data Available", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        hasAddedPriceInfo = true
        -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Added no data message")
        return
    end

    -- Add price data
    if formattedPrice then
        priceSection:AddLine("Average Price: " .. formattedPrice, tooltip:GetStyle("bodyDescription"))
    end

    if priceRange then
        priceSection:AddLine("Range: " .. priceRange, tooltip:GetStyle("bodyDescription"))
    end

    if salesCount then
        priceSection:AddLine("Sales: " .. tostring(salesCount), tooltip:GetStyle("bodyDescription"))
    end

    tooltip:AddSection(priceSection)
    hasAddedPriceInfo = true
    -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Added complete price info section")
end

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

    -- Add price info
    local success, result = pcall(function()
        AddPriceInfoSection(tooltip, itemLink)
        return true
    end)

    if not success then
        -- TSCPriceFetcher.modules.debug.error("CreateListingHooks: Failed to add price info: " .. tostring(result))
    end
end

--[[
    Sets up the create listing hooks
]]
function CreateListingHooks.setupCreateListingHooks()
    -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Setting up create listing hooks")

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

    -- Also hook into the general tooltip system as backup, but with additional checks
    local originalAddPriceToGamepadTooltip = TSCPriceFetcher.modules.tooltips.AddPriceToGamepadTooltip
    TSCPriceFetcher.modules.tooltips.AddPriceToGamepadTooltip = function(tooltipObject, tooltipType, itemLink)
        -- Call original function first
        originalAddPriceToGamepadTooltip(tooltipObject, tooltipType, itemLink)

        -- Only add create listing price info if we're in create listing scene AND haven't already added it
        if TRADING_HOUSE_CREATE_LISTING_GAMEPAD_SCENE and TRADING_HOUSE_CREATE_LISTING_GAMEPAD_SCENE:IsShowing() then
            -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Backup hook triggered in create listing scene")
            OnCreateListingTooltip(tooltipObject, tooltipType, itemLink)
        end
    end

    -- TSCPriceFetcher.modules.debug.log("CreateListingHooks: Setup complete")
end

TSC_CreateListingHooksModule = CreateListingHooks
return CreateListingHooks
