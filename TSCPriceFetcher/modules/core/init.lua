--[[
    modules/core/init.lua
    Handles addon initialization and hooks for gamepad tooltips.
    Exposes: initialize, isReady
]]

local Init = {}

-- Flag to track if the addon is initialized
Init.isInitialized = false

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

    TSCPriceFetcher.modules.debug.log("selectedData: " ..
        zo_strjoin(", ", tostring(selectedData.bagId), tostring(selectedData.slotIndex),
            tostring(selectedData.itemLink)))
end

local function HookGamepadTooltips()
    SecurePostHook(ZO_GamepadInventory, "UpdateItemLeftTooltip", OnGamepadInventoryTooltip)
end

--- Initializes the addon (called on EVENT_ADD_ON_LOADED)
function Init.initialize()
    if Init.isInitialized then
        TSCPriceFetcher.modules.debug.log("Init: Already initialized")
        return
    end

    -- Initialize data source detection
    TSCPriceFetcher.initializeDataSource()

    Init.isInitialized = true
    TSCPriceFetcher.modules.debug.success("Init: Addon initialized")
    HookGamepadTooltips()
end

--- Returns true if the addon is initialized
function Init.isReady()
    return Init.isInitialized
end

TSC_InitModule = Init
return Init
