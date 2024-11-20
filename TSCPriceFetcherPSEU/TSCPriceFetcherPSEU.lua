-- TSCPriceFetcherPSEU.lua - Consolidated single file
local TSC = {
    name = "TSCPriceFetcherPSEU",
    version = 150
}

-- Local references for performance
local EVENT_MANAGER = EVENT_MANAGER
local zo_callLater = zo_callLater
local ZO_CommaDelimitNumber = ZO_CommaDelimitNumber
local ZO_PostHook = ZO_PostHook
local math_floor = math.floor
local math_ceil = math.ceil
local math_min = math.min
local math_max = math.max
local MAX_PLAYER_CURRENCY = MAX_PLAYER_CURRENCY
local savedVars -- Will be set after initialization

-- Constants
local goldIcon = "|t32:32:EsoUI/Art/currency/currency_gold.dds|t"

-- Server Configuration
-- This addon is configured for Xbox NA server (platform 0)
-- For XBNA: EXPECTED_PLATFORM = 0
-- For XBEU: EXPECTED_PLATFORM = 3
-- For PSNA: EXPECTED_PLATFORM = 1
-- For PSEU: EXPECTED_PLATFORM = 4
local SERVER_PLATFORM_MAPPING = {
    ["XB1live"] = 0,
    ["PS4live"] = 1,
    ["NA Megaserver"] = 2,
    ["XB1live-eu"] = 3,
    ["PS4live-eu"] = 4,
    ["EU Megaserver"] = 5,
    ["PTS"] = 6
}
local EXPECTED_PLATFORM = 4  -- 0 = XBNA, 3 = XBEU, 1 = PSNA, 4 = PSEU

-- QR Code window tracking (like LibQRCode does)
local tscQRWindow = nil
local tscQRContainer = nil

-- List of blocking scenes (expanded for gamepad/console)
local BLOCKING_SCENES = {
    -- Crown Store and related
    ["crownStore"] = true,
    ["crownStoreShowcase"] = true,
    ["crownCrate"] = true,
    ["crownGemStore"] = true,
    ["crownStoreMarket"] = true,
    ["gamepad_crownStore"] = true,
    ["gamepad_crownStoreShowcase"] = true,
    ["gamepad_crownCrate"] = true,
    ["gamepad_crownGemStore"] = true,
    ["gamepad_crownStoreMarket"] = true,

    -- Daily rewards
    ["dailyLoginRewards"] = true,
    ["gamepad_dailyLoginRewards"] = true,

    -- Level up rewards
    ["levelUpRewards"] = true,
    ["gamepad_levelUpRewards"] = true,

    -- Tutorials and intro
    ["tutorial"] = true,
    ["gamepad_tutorial"] = true,

    -- Cinematics
    ["cinematic"] = true,
    ["gamepad_cinematic"] = true,

    -- Character select/creation
    ["characterCreate"] = true,
    ["characterSelect"] = true,
    ["gamepad_characterCreate"] = true,
    ["gamepad_characterSelect"] = true,

    -- Other major overlays
    ["gamepad_options"] = true,
    ["gamepad_login"] = true,
    ["login"] = true,
    ["options"] = true,
}

-- Saved variables version and announcement version
local SAVED_VARS_VERSION = 8
local ANNOUNCEMENT_VERSION = TSC.version

-- Default settings structure
TSC.default = {
    lastSeenAnnouncementVersion = nil,
    autoListAverage = true,
    bumperPriceAdjustment = 5,
    roundingTarget = 100
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function toGold(amount)
    amount = tonumber(amount)
    if not amount then return "0" end
    return ZO_CommaDelimitNumber(amount)
end

-- ============================================================================
-- DATA FUNCTIONS
-- ============================================================================

local function getAvgPrice(itemLink)
    -- Since TSCPriceDataAPIPSEU is a library dependency, it will always be available
    if not TSCPriceDataAPIPSEU then
        return nil
    end
    return TSCPriceDataAPIPSEU:GetPrice(itemLink) -- Returns nil if no data found
end

local function getFormattedAvgPrice(itemLink)
    local result = getAvgPrice(itemLink)

    -- Handle numeric price
    if result then
        return toGold(result) .. " " .. goldIcon
    end

    return nil -- Let tooltip handle "no data" display
end

local function getFormattedPriceRange(itemLink)
    -- Use the new GetItemData function
    local itemData = TSCPriceDataAPIPSEU:GetItemData(itemLink)
    if not itemData or not itemData.commonMin or not itemData.commonMax then
        return nil
    end

    return toGold(itemData.commonMin) .. " - " .. toGold(itemData.commonMax) .. " " .. goldIcon
end

-- ============================================================================
-- TOOLTIP FUNCTIONS
-- ============================================================================

local function tooltipHasPriceInfo(tooltip)
    if not tooltip then return false end

    -- Check scrollTooltip.contents
    if tooltip.scrollTooltip and tooltip.scrollTooltip.contents and tooltip.scrollTooltip.contents.GetNumChildren then
        local content = tooltip.scrollTooltip.contents
        local numChildren = content:GetNumChildren()
        for i = 1, numChildren do
            local child = content:GetChild(i)
            if child and child.GetText then
                local text = child:GetText()
                if text and (text:find("TSC") or text:find("Average Price:") or text:find("No Price Data Available") or text:find("Bound Item")) then
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
                if text and (text:find("TSC") or text:find("Average Price:") or text:find("No Price Data Available") or text:find("Bound Item")) then
                    return true
                end
            end
        end
    end

    return false
end

local function shouldAddPriceToTooltip(tooltipType, tooltipObject, itemLink)
    -- Must have valid tooltip and tooltip type
    if not tooltipType or not tooltipObject then return false end

    -- Must have a valid item link
    if type(itemLink) ~= "string" or not itemLink:find("^|H%d:item:") then return false end

    -- Must have a valid item name
    local itemName = GetItemLinkName(itemLink)
    if not itemName or itemName == "" then return false end

    -- Must have a valid item type
    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_NONE then return false end

    return true
end

local function addPriceToTooltip(tooltip, itemLink)
    local priceSection = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    if not priceSection then
        return false
    end

    -- Check if item is bound
    if IsItemLinkBound(itemLink) then
        priceSection:AddLine("Bound Item", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        return true
    end

    -- Get price data
    local formattedPrice = getFormattedAvgPrice(itemLink)
    local formattedRange = getFormattedPriceRange(itemLink)

    if not formattedPrice then
        priceSection:AddLine("No Price Data", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        return true
    end

    -- Add price data
    priceSection:AddLine("TSC Average: |cDBC14D" .. formattedPrice .. "|r", tooltip:GetStyle("bodyDescription"))

    -- Add range data if available
    if formattedRange then
        priceSection:AddLine("Range: |cDBC14D" .. formattedRange .. "|r", tooltip:GetStyle("bodyDescription"))
    end

    tooltip:AddSection(priceSection)
    return true
end

local function addPriceToGamepadTooltip(tooltipObject, tooltipType, itemLink)
    if not shouldAddPriceToTooltip(tooltipType, tooltipObject, itemLink) then
        return
    end

    local tooltip = tooltipObject:GetTooltip(tooltipType)
    if not tooltip or tooltipHasPriceInfo(tooltip) then
        return
    end

    -- Just try once with error handling
    pcall(addPriceToTooltip, tooltip, itemLink)
end

-- ============================================================================
-- ANNOUNCEMENT FUNCTIONS
-- ============================================================================

local function markAnnouncementSeen()
    savedVars.lastSeenAnnouncementVersion = ANNOUNCEMENT_VERSION
end

local function showAnnouncementPanel()
    local panel = GetControl("TSCAnnouncementPanel")

    panel:SetHidden(false)

    -- Mark the announcement as seen when the panel is shown
    markAnnouncementSeen()

    -- Note: Close button is commented out in XML, panel auto-dismisses after 6 seconds
    zo_callLater(function()
        if not panel:IsHidden() then
            panel:SetHidden(true)
        end
    end, 6000)
end


local function showAnnouncementPanelWhenReady()
    local lastSeen = savedVars.lastSeenAnnouncementVersion
    local currentScene = SCENE_MANAGER:GetCurrentSceneName()
    local shouldShowPanel = lastSeen ~= ANNOUNCEMENT_VERSION and not BLOCKING_SCENES[currentScene]

    if shouldShowPanel then
        showAnnouncementPanel()
    else
        -- Wait and try again when the scene changes
        local function OnSceneChange()
            local newScene = SCENE_MANAGER:GetCurrentSceneName()
            if lastSeen ~= ANNOUNCEMENT_VERSION and not BLOCKING_SCENES[newScene] then
                EVENT_MANAGER:UnregisterForEvent("TSC_AnnounceScene", EVENT_SCENE_MANAGER_SCENE_CHANGED)
                showAnnouncementPanel()
            end
        end
        EVENT_MANAGER:RegisterForEvent("TSC_AnnounceScene", EVENT_SCENE_MANAGER_SCENE_CHANGED, OnSceneChange)
    end
end

-- ============================================================================
-- QR CODE FUNCTIONS
-- ============================================================================

local function showQRCode(url, title)
    if not LibQRCode then
        RequestOpenUnsafeURL(url)
        return
    end

    -- Create our own QR code window (copied from LibQRCode but with custom positioning)
    local defaultTextureSize = 200
    local defaultHeaderHeight = 30
    local defaultXInset = 5
    local defaultYInset = 5

    if tscQRWindow == nil then
        -- Create the main window (only once)
        tscQRWindow = WINDOW_MANAGER:CreateTopLevelWindow("TSCQRWindow")
        local windowWidth = defaultTextureSize + 2 * defaultXInset
        local windowHeight = defaultTextureSize + defaultHeaderHeight + 3 * defaultYInset
        tscQRWindow:SetDimensions(windowWidth, windowHeight)

        -- Position at center + 500px offset
        tscQRWindow:SetAnchor(CENTER, GUI_ROOT, CENTER, 500, 0)
        tscQRWindow:SetMovable(true)
        tscQRWindow:SetMouseEnabled(true)
        tscQRWindow:SetClampedToScreen(true)

        -- Create title header
        local header = WINDOW_MANAGER:CreateControl("TSCQRWindowTitle", tscQRWindow, CT_LABEL)
        header:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        header:SetDimensions(defaultTextureSize, defaultHeaderHeight)
        header:SetColor(0.5, 0.5, 1, 1) -- Blue color like original
        header:SetAnchor(TOP, tscQRWindow, TOP, 0, defaultYInset)
        header:SetFont("ZoFontAnnounceMedium")

        -- Add backdrop
        local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("TSCQRCodeBackdrop", tscQRWindow, "ZO_DefaultBackdrop")
        backdrop:SetAnchorFill()
        backdrop:SetDrawTier(DT_LOW)

        -- Add close button
        local closeButton = WINDOW_MANAGER:CreateControl("TSCQRCodeCloseButton", tscQRWindow, CT_BUTTON)
        closeButton:SetDimensions(defaultHeaderHeight, defaultHeaderHeight)
        closeButton:SetAnchor(TOPRIGHT, tscQRWindow, TOPRIGHT, defaultXInset, defaultYInset)
        closeButton:SetHandler("OnClicked", function()
            SCENE_MANAGER:ToggleTopLevel(tscQRWindow)
            tscQRWindow:SetHidden(true)
        end)
        closeButton:SetEnabled(true)
        closeButton:SetNormalTexture("EsoUI/Art/Buttons/closebutton_up.dds")
        closeButton:SetPressedTexture("EsoUI/Art/Buttons/closebutton_down.dds")
        closeButton:SetMouseOverTexture("EsoUI/Art/Buttons/closebutton_mouseover.dds")
        closeButton:EnableMouseButton(MOUSE_BUTTON_INDEX_LEFT, true)
    else
        -- Window already exists, just show it
        SCENE_MANAGER:ToggleTopLevel(tscQRWindow)
        tscQRWindow:SetHidden(false)
    end

    -- Update the title
    local header = WINDOW_MANAGER:GetControlByName("TSCQRWindowTitle")
    if header then
        header:SetText(title or "QR Code")
    end

    -- Create or update QR code
    if tscQRContainer == nil then
        tscQRContainer = LibQRCode.CreateQRControl(defaultTextureSize, url)
    else
        LibQRCode.DrawQRCode(tscQRContainer, url)
    end

    tscQRContainer:SetParent(tscQRWindow)
    tscQRContainer:SetAnchor(TOPLEFT, tscQRWindow, TOPLEFT, defaultXInset, defaultHeaderHeight + 2 * defaultYInset)
    tscQRContainer:SetAnchor(BOTTOMRIGHT, tscQRWindow, BOTTOMRIGHT, -defaultXInset, -defaultYInset)

    -- Auto-hide after 10 seconds
    zo_callLater(function()
        if not tscQRWindow:IsHidden() then
            tscQRWindow:SetHidden(true)
        end
    end, 10000)
end

-- ============================================================================
-- SETTINGS FUNCTIONS
-- ============================================================================

local function initializeSavedVars()
    -- Initialize account-wide saved variables only
    TSC.savedVars = ZO_SavedVars:NewAccountWide(
        "TSCPriceFetcherDataPSEU", SAVED_VARS_VERSION, nil, TSC.default)

    -- Set local reference for performance
    savedVars = TSC.savedVars

    -- Handle migration by adding any missing default fields
    if TSC.savedVars.version ~= SAVED_VARS_VERSION then
        for key, defaultValue in pairs(TSC.default) do
            if TSC.savedVars[key] == nil then
                TSC.savedVars[key] = defaultValue
            end
        end
        TSC.savedVars.version = SAVED_VARS_VERSION
    end
end

local function setupSettingsMenu()
    local LHAS = LibHarvensAddonSettings
    if not LHAS then
        CHAT_ROUTER:AddSystemMessage("LibHarvensAddonSettings not found - settings menu will not be available")
        return
    end

    local options = {
        allowDefaults = true,         --will allow users to reset the settings to default values
        allowRefresh = true,          --if this is true, when one of settings is changed, all other settings will be checked for state change (disable/enable)
        defaultsFunction = function() --this function is called when allowDefaults is true and user hit the reset button
            d("Reset")
        end,
    }
    --Create settings "container" for your addon
    --First parameter is the name that will be displayed in the options,
    --Second parameter is the options table (it is optional)
    local settings = LHAS:AddAddon("TSC Price Fetcher", options)
    if not settings then
        return
    end

    --[[
        INFORMATION SECTION
    --]]
    local informationSection = {
        type = LHAS.ST_SECTION,
        label = "Information",
    }
    settings:AddSetting(informationSection)

    local whatsNewButton = {
        type = LHAS.ST_BUTTON,
        label = "What's New",
        tooltip = [[v150: Updated with sales data from week starting Jan. 4

Scan the QR code to view full update details]],
        buttonText = "View Update Info",
        clickHandler = function(control, button)
            showQRCode("https://tamrielsavings.com/updates", "What's New")
        end,
    }
    settings:AddSetting(whatsNewButton)

    local bugReportButton = {
        type = LHAS.ST_BUTTON,
        label = "Troubleshoot",
        tooltip = "Generate a QR code that will link to the FAQ + Troubleshooting page on tamrielsavings.com",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            showQRCode("https://tamrielsavings.com/faq", "Troubleshoot")
        end,
    }
    settings:AddSetting(bugReportButton)

    local discordButton = {
        type = LHAS.ST_BUTTON,
        label = "Join TSC on Discord",
        tooltip = "Generate a QR code that will link to the TSC Discord server",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            showQRCode("https://discord.gg/7DzUVCQ", "Join TSC on Discord")
        end,
    }
    settings:AddSetting(discordButton)

    local donateButton = {
        type = LHAS.ST_BUTTON,
        label = "Donate to TSC",
        tooltip = "Generate a QR code that will link to the Donate page on tamrielsavings.com",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            showQRCode("https://tamrielsavings.com/donations", "Donate to TSC")
        end,
    }
    settings:AddSetting(donateButton)

    --[[
        TRADING SETTINGS SECTION
    --]]
    local tradingSettingsSection = {
        type = LHAS.ST_SECTION,
        label = "Item Listing Settings",
    }
    settings:AddSetting(tradingSettingsSection)

    --Define checkbox table
    local autoListAverage = {
        type = LHAS.ST_CHECKBOX,
        label = "Auto List Average",
        tooltip =
        "Setting this ON will cause an item to be listed at the average price of the item.  Setting this OFF will use the game default price",
        default = true,               --default value, only used when options.allowDefaults == true (optional)
        setFunction = function(state) --this function is called when the setting is changed
            savedVars.autoListAverage = state
        end,
        getFunction = function() --this function is called to set initial state of the checkbox
            return savedVars.autoListAverage
        end,
    }
    settings:AddSetting(autoListAverage)

    local bumperPriceAdjustment = {
        type = LHAS.ST_SLIDER,
        label = "Bumper Price Adjustment",
        tooltip = "Use bumpers to adjust the current listing price by the chosen percentage of the TSC average",
        setFunction = function(value)
            savedVars.bumperPriceAdjustment = value
        end,
        getFunction = function()
            return savedVars.bumperPriceAdjustment
        end,
        default = 5,
        min = 1,
        max = 10,
        step = 1,
        unit = "%",
        format = "%d",
        disable = function() return false end,
    }
    settings:AddSetting(bumperPriceAdjustment)

    local roundingTarget = {
        type = LHAS.ST_DROPDOWN,
        label = "Price Rounding Target",
        tooltip =
        "Use triggers to round prices up or down to the nearest chosen value (10, 100, or 1000).",
        setFunction = function(combobox, name, item)
            savedVars.roundingTarget = item.data
        end,
        getFunction = function()
            local target = savedVars.roundingTarget or 100
            if target == 10 then return "10" end
            if target == 100 then return "100" end
            if target == 1000 then return "1000" end
            return "100"
        end,
        default = "100",
        items = {
            {
                name = "10",
                data = 10
            },
            {
                name = "100",
                data = 100
            },
            {
                name = "1000",
                data = 1000
            },
        },
        disable = function() return false end,
    }
    settings:AddSetting(roundingTarget)
end

-- ============================================================================
-- ACTION FUNCTIONS
-- ============================================================================

-- Reusable logic for round and bump actions
local function TSC_PerformRound(up)
    if TRADING_HOUSE_CREATE_LISTING_GAMEPAD then
        local self = TRADING_HOUSE_CREATE_LISTING_GAMEPAD
        local roundingTarget = savedVars.roundingTarget or TSC.default.roundingTarget
        local currentPrice = self.listingPrice
        if currentPrice and currentPrice >= 0 then
            local newPrice
            if currentPrice % roundingTarget == 0 then
                if up then
                    newPrice = math_min(currentPrice + roundingTarget, MAX_PLAYER_CURRENCY)
                else
                    newPrice = math_max(currentPrice - roundingTarget, 0)
                end
            else
                if up then
                    newPrice = math_min(math_ceil(currentPrice / roundingTarget) * roundingTarget, MAX_PLAYER_CURRENCY)
                else
                    newPrice = math_floor(currentPrice / roundingTarget) * roundingTarget
                end
            end
            self:SetListingPrice(newPrice)
        end
    end
end

local function TSC_PerformBump(up)
    if TRADING_HOUSE_CREATE_LISTING_GAMEPAD then
        local self = TRADING_HOUSE_CREATE_LISTING_GAMEPAD
        local currentAdjustment = savedVars.bumperPriceAdjustment or TSC.default.bumperPriceAdjustment
        local currentPrice = self.listingPrice
        if currentPrice and currentPrice >= 0 then
            local itemLink = GetItemLink(self.itemBag, self.itemIndex)
            local avgPricePerUnit = getAvgPrice(itemLink)
            if avgPricePerUnit and type(avgPricePerUnit) == "number" then
                local stackCount = GetSlotStackSize(self.itemBag, self.itemIndex)
                local avgPriceTotal = avgPricePerUnit * stackCount
                local adjustmentAmount = math_floor(avgPriceTotal * currentAdjustment / 100)
                local newPrice
                if up then
                    newPrice = math_min(currentPrice + adjustmentAmount, MAX_PLAYER_CURRENCY)
                else
                    newPrice = math_max(currentPrice - adjustmentAmount, 0)
                end
                self:SetListingPrice(newPrice)
            end
        end
    end
end

-- ============================================================================
-- GLOBAL FUNCTIONS (for keybindings)
-- ============================================================================

function TSCPriceFetcher_RoundUp()
    TSC_PerformRound(true)
end

function TSCPriceFetcher_RoundDown()
    TSC_PerformRound(false)
end

function TSCPriceFetcher_BumpUp()
    TSC_PerformBump(true)
end

function TSCPriceFetcher_BumpDown()
    TSC_PerformBump(false)
end

-- ============================================================================
-- KEYBIND GROUP DEFINITION
-- ============================================================================

local tradingKeybindGroup = {
    {
        name = "Bump Down",
        order = -3000,
        keybind = "UI_SHORTCUT_LEFT_SHOULDER",
        callback = function()
            TSC_PerformBump(false)
        end,
    },
    {
        name = "Bump Up",
        order = -4000,
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        callback = function()
            TSC_PerformBump(true)
        end,
    },
    {
        name = "Round Down",
        order = -1000,
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        callback = function()
            TSC_PerformRound(false)
        end,
    },
    {
        name = "Round Up",
        order = -2000,
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        callback = function()
            TSC_PerformRound(true)
        end,
    }
}

-- ============================================================================
-- HOOK FUNCTIONS
-- ============================================================================

local function hookGamepadTooltips()
    local function OnPlayerActivated()
        EVENT_MANAGER:UnregisterForEvent("TSCUniversalContext", EVENT_PLAYER_ACTIVATED)

        zo_callLater(function()
            if GAMEPAD_TOOLTIPS then
                local leftTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
                local rightTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)

                -- Hook into LEFT tooltip: only the earliest available function
                if leftTooltip then
                    if leftTooltip.AddItemTitle then
                        ZO_PostHook(leftTooltip, "AddItemTitle", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_LEFT_TOOLTIP, itemLink)
                        end)
                    elseif leftTooltip.LayoutGenericItem then
                        ZO_PostHook(leftTooltip, "LayoutGenericItem", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_LEFT_TOOLTIP, itemLink)
                        end)
                    else
                        ZO_PostHook(leftTooltip, "LayoutItem", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_LEFT_TOOLTIP, itemLink)
                        end)
                    end
                end

                -- Hook into RIGHT tooltip: only the earliest available function
                if rightTooltip then
                    if rightTooltip.AddItemTitle then
                        ZO_PostHook(rightTooltip, "AddItemTitle", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_RIGHT_TOOLTIP, itemLink)
                        end)
                    elseif rightTooltip.LayoutGenericItem then
                        ZO_PostHook(rightTooltip, "LayoutGenericItem", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_RIGHT_TOOLTIP, itemLink)
                        end)
                    else
                        ZO_PostHook(rightTooltip, "LayoutItem", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_RIGHT_TOOLTIP, itemLink)
                        end)
                    end
                end
            end
        end, 1000)
    end

    EVENT_MANAGER:RegisterForEvent("TSCUniversalContext", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

local function setupCreateListingHooks()
    if ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing then
        ZO_PostHook("ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing",
            function(selectedData, bag, index, listingPrice)
                -- Only auto-set price if the setting is enabled
                if not savedVars.autoListAverage then
                    return
                end

                local itemLink = GetItemLink(bag, index)

                local avgPricePerUnit = getAvgPrice(itemLink)
                if avgPricePerUnit and type(avgPricePerUnit) == "number" then
                    local stackCount = GetSlotStackSize(bag, index)
                    local ourPrice = avgPricePerUnit * stackCount

                    if ourPrice ~= listingPrice then
                        -- Wait for UI to be fully initialized, then set our price
                        zo_callLater(function()
                            if TRADING_HOUSE_CREATE_LISTING_GAMEPAD and TRADING_HOUSE_CREATE_LISTING_GAMEPAD.SetListingPrice then
                                TRADING_HOUSE_CREATE_LISTING_GAMEPAD:SetListingPrice(ourPrice)
                            end
                        end, 200)
                    end
                end
            end
        )
    end
end



-- ============================================================================
-- KEYBIND MANAGEMENT
-- ============================================================================


local function addTradingKeybinds()
    KEYBIND_STRIP:AddKeybindButtonGroup(tradingKeybindGroup)
end

-- OLD METHOD TO REMOVE KEYBINDS FROM ERIC
-- local function removeTradingKeybinds()
--     KEYBIND_STRIP:RemoveKeybindButtonGroup(tradingKeybindGroup)
-- end

-- NEW METHOD TO REMOVE KEYBINDS FROM MIDNITE
local previousScene = ""
local function removeTradingKeybinds()
    if previousScene == "gamepad_trading_house_create_listing" then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(tradingKeybindGroup)
        -- need to push and pop keybind group to restore system bindings
        KEYBIND_STRIP:PushKeybindGroupState()
        KEYBIND_STRIP:PopKeybindGroupState()
    end
end

-- OLD METHOD TO ADD KEYBINDS FROM ERIC
-- local function setupTradingHouseKeybinds()
--     -- Add keybinds when entering trading house create listing scene
--     SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, newState)
--         local sceneName = scene:GetName()

--         -- Check for the correct trading house create listing scene
--         if newState == SCENE_SHOWING and sceneName == "gamepad_trading_house_create_listing" then
--             addTradingKeybinds()
--         elseif newState == SCENE_HIDING and sceneName == "gamepad_trading_house_create_listing" then
--             removeTradingKeybinds()
--         end
--     end)
-- end

-- NEW METHOD TO ADD KEYBINDS FROM MIDNITE
local function setupTradingHouseKeybinds()

    -- Add keybinds when entering trading house create listing scene
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, newState)
        local sceneName = scene:GetName()
        -- Remove keybinds when leaving trading house
        EVENT_MANAGER:RegisterForEvent("OnGuildStoreClosed", EVENT_CLOSE_TRADING_HOUSE, function()
            removeTradingKeybinds()
            EVENT_MANAGER:UnregisterForEvent("OnGuildStoreClosed", EVENT_CLOSE_TRADING_HOUSE)
        end)

        -- Check for the correct trading house create listing scene
        if newState == SCENE_SHOWING and sceneName == "gamepad_trading_house_create_listing" then
            addTradingKeybinds()
        elseif  newState == SCENE_SHOWING and sceneName == "gamepad_trading_house" then
            removeTradingKeybinds()
            EVENT_MANAGER:UnregisterForEvent("OnGuildStoreClosed", EVENT_CLOSE_TRADING_HOUSE)
        end
        previousScene = sceneName
    end)
end

-- ============================================================================
-- SERVER VALIDATION
-- ============================================================================

local function checkServerCompatibility()
    local worldName = GetWorldName()
    if not worldName then return end
    
    local currentPlatform = SERVER_PLATFORM_MAPPING[worldName]
    
    if currentPlatform == nil then
        -- Unknown world name - show warning
        zo_callLater(function()
            local message = string.format(
                "|cFF0000TSC Price Fetcher Warning:|r Unknown server name: |cFFFF00%s|r. " ..
                "Please ensure you have the correct addon version installed.",
                worldName
            )
            CHAT_ROUTER:AddSystemMessage(message)
        end, 2000)
        return
    end
    
    if currentPlatform ~= EXPECTED_PLATFORM then
        -- Wrong server/platform - show warning
        zo_callLater(function()
            local platformNames = {
                [0] = "Xbox NA",
                [1] = "PlayStation NA",
                [2] = "PC NA",
                [3] = "Xbox EU",
                [4] = "PlayStation EU",
                [5] = "PC EU",
                [6] = "PTS"
            }
            local expectedName = platformNames[EXPECTED_PLATFORM] or "Unknown"
            local currentName = platformNames[currentPlatform] or "Unknown"
            local message = string.format(
                "|cFF0000TSC Price Fetcher Warning:|r This addon is configured for |cFFFF00%s|r, but you are on |cFFFF00%s|r (|cFFFF00%s|r). " ..
                "Please install the correct version for your server.",
                expectedName,
                currentName,
                worldName
            )
            CHAT_ROUTER:AddSystemMessage(message)
        end, 2000)
    end
end

-- ============================================================================
-- INITIALIZATION FUNCTIONS
-- ============================================================================

-- Flag to track if the addon is initialized
local isInitialized = false

local function initialize()
    if isInitialized then
        return
    end

    -- Set up existing hooks
    hookGamepadTooltips()
    setupCreateListingHooks()
    setupTradingHouseKeybinds()

    showAnnouncementPanelWhenReady()
    setupSettingsMenu()
    isInitialized = true
end


-- ============================================================================
-- STRING IDS (for keybindings)
-- ============================================================================

ZO_CreateStringId("SI_BINDING_NAME_TSC_ROUND_UP", "Round Up")
ZO_CreateStringId("SI_BINDING_NAME_TSC_ROUND_DOWN", "Round Down")
ZO_CreateStringId("SI_BINDING_NAME_TSC_BUMP_UP", "Bump Up")
ZO_CreateStringId("SI_BINDING_NAME_TSC_BUMP_DOWN", "Bump Down")

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

-- No slash commands needed for release

-- ============================================================================
-- ADDON SETUP
-- ============================================================================

-- Make it globally accessible (needed for ESO addon structure)
_G.TSCPriceFetcher = TSC

-- Register events directly
EVENT_MANAGER:RegisterForEvent(TSC.name, EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == TSC.name then
        -- Check server compatibility first
        checkServerCompatibility()

        -- Initialize saved variables first
        initializeSavedVars()

        -- Initialize the addon
        initialize()

        EVENT_MANAGER:UnregisterForEvent(TSC.name, EVENT_ADD_ON_LOADED)
    end
end)

EVENT_MANAGER:RegisterForEvent(TSC.name, EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(TSC.name, EVENT_PLAYER_ACTIVATED)
end)
