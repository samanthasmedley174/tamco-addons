--[[
       modules/utils/lookup.lua
       Provides price lookup for items.
       Exposes: getFormattedPrice, getPrice
]]

local goldIcon = "|t32:32:EsoUI/Art/currency/currency_gold.dds|t"

local Lookup = {}

local function IsValidItemLink(itemLink)
    return type(itemLink) == "string" and itemLink:match("^|H%d:item:")
end

function Lookup.getFormattedPrice(itemLink)
    if not IsValidItemLink(itemLink) then
        -- TSCPriceFetcher.modules.debug.warn("Lookup: invalid itemLink")
        return "no price data"
    end

    -- TSCPriceFetcher.modules.debug.log("Lookup: Looking up price for itemLink='" .. tostring(itemLink) .. "'")
    return TSCPriceFetcher.modules.dataAdapter.getFormattedAvgPrice(itemLink)
end

function Lookup.getPrice(itemLink)
    if not IsValidItemLink(itemLink) then
        return nil
    end
    return TSCPriceFetcher.modules.dataAdapter.getAvgPrice(itemLink)
end

TSC_LookupModule = Lookup
return Lookup
