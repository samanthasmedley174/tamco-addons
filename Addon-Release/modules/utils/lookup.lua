--[[
       modules/utils/lookup.lua
       Provides price lookup for item names.
       Exposes: getFormattedPrice, getPrice
]]

local priceData = TSCPriceNameData
local goldIcon = "|t32:32:EsoUI/Art/currency/currency_gold.dds|t"

local Lookup = {}



local function IsValidItemName(itemName)
    return type(itemName) == "string" and itemName ~= ""
end

--[[
    Gets the price for a given item name, formatted with commas for thousands.
    If the item is not found, returns a default string ("No price data").
    @param itemName (string) - The name of the item to look up.
    @return (string) - The formatted price as a string (e.g., "1,234"), or the default string if not found.

    Usage:
        local formatted = Lookup.getFormattedPrice("Acai Berry")
        -- formatted will be "1,234" or "no price data"
]]
function Lookup.getFormattedPrice(itemName)
    if type(itemName) ~= "string" then
        TSCPriceFetcher.modules.debug.warn("Lookup: itemName is not a string")
        return "no price data"
    end
    TSCPriceFetcher.modules.debug.log("Lookup: Looking up price for itemName='" .. tostring(itemName) .. "'")
    local cleanName = TSC_FormatterModule.StripEsoSuffix(itemName)
    local price = Lookup.getPrice(cleanName)
    if price then
        TSCPriceFetcher.modules.debug.log("Lookup: Found price='" .. tostring(price) .. "'")
        if TSC_FormatterModule then
            return TSC_FormatterModule.toGold(price) .. " " .. goldIcon
        else
            return tostring(price) .. " gold"
        end
    end

    TSCPriceFetcher.modules.debug.warn("Lookup: No price data for itemName='" .. tostring(itemName) .. "'")
    return "no price data"
end

function Lookup.getPrice(itemName)
    if not IsValidItemName(itemName) then
        return nil
    end
    local cleanName = TSC_FormatterModule.StripEsoSuffix(itemName)
    return priceData[string.lower(cleanName)]
end

TSC_LookupModule = Lookup
return Lookup
