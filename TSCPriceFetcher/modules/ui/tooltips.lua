--[[
    modules/ui/tooltips.lua
    Handles adding price information to gamepad tooltips in ESO.
    All helper functions are local; only AddPriceToGamepadTooltip is exposed.
]]
local Tooltips = {}

--[[
    Determines if the tooltip context and item link are valid for price display.
    @param tooltipType (number): The tooltip type (e.g., GAMEPAD_LEFT_TOOLTIP).
    @param tooltipObject (table): The tooltip object.
    @param itemLink (string): The item link string.
    @return (boolean): true if valid, false otherwise.
]]
local function ShouldAddPriceToTooltip(tooltipType, tooltipObject, itemLink)
    -- Must have valid tooltip and tooltip type
    if not tooltipType or not tooltipObject then return false end

    -- Must be a valid item link
    if type(itemLink) ~= "string" or not itemLink:find("^|H%d:item:") then return false end

    -- Must have a valid item name
    local itemName = GetItemLinkName(itemLink)
    if not itemName or itemName == "" then return false end

    -- Must have a valid item type
    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_NONE then return false end

    return true
end

--[[
    Adds price info to a gamepad tooltip if the item is valid and price not already present.
    @param tooltipObject (table): The GAMEPAD_TOOLTIPS object.
    @param tooltipType (number): The tooltip type (e.g., GAMEPAD_LEFT_TOOLTIP).
    @param itemLink (string): The item link string.
]]
function Tooltips.AddPriceToGamepadTooltip(tooltipObject, tooltipType, itemLink)
    if not ShouldAddPriceToTooltip(tooltipType, tooltipObject, itemLink) then return end

    local tooltip = tooltipObject:GetTooltip(tooltipType)
    if not tooltip then return end

    if TSC_UtilsModule.TooltipHasPriceInfo(tooltip) then return end

    local success, result = pcall(function()
        TSC_UtilsModule.AddPriceInfoSection(tooltip, itemLink)
        return true
    end)
end

TSC_TooltipsModule = Tooltips
return Tooltips