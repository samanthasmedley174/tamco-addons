--[[
    modules/utils/data_adapter.lua
    Provides unified interface to different price data sources
    Exposes: getAvgPrice, getMinPrice, getMaxPrice, getFullData, hasFeature
]]

local goldIcon = "|t32:32:EsoUI/Art/currency/currency_gold.dds|t"

local DataAdapter = {}

-- Check what features are available based on current data source
function DataAdapter.hasFeature(feature)
    if TSCPriceFetcher.dataSource == "full" then
        return true                  -- Full data has all features
    elseif TSCPriceFetcher.dataSource == "lite" then
        return feature == "avgPrice" -- Lite only has average price
    end
    return false
end

-- Get average price (works with both data sources)
function DataAdapter.getAvgPrice(itemLink)
    if not TSCPriceFetcher.priceEnabled then
        return nil
    end

    -- Get item ID from link
    local itemId = GetItemLinkItemId(itemLink)
    if not itemId then
        return nil
    end

    local price = nil
    if TSCPriceFetcher.dataSource == "full" then
        price = TSCPriceData:GetAvgPrice(itemId)
    elseif TSCPriceFetcher.dataSource == "lite" then
        price = TSCPriceDataLite:GetPrice(itemId)
    end

    return price -- Returns nil if no data found
end

-- Get min price (only available with full data)
function DataAdapter.getCommonMinPrice(itemLink)
    if not DataAdapter.hasFeature("commonMin") then
        return nil
    end

    local itemId = GetItemLinkItemId(itemLink)
    return TSCPriceData:GetCommonMin(itemId)
end

-- Get max price (only available with full data)
function DataAdapter.getCommonMaxPrice(itemLink)
    if not DataAdapter.hasFeature("commonMax") then
        return nil
    end

    local itemId = GetItemLinkItemId(itemLink)
    return TSCPriceData:GetCommonMax(itemId)
end

-- Get min price (only available with full data)
function DataAdapter.getMinPrice(itemLink)
    if not DataAdapter.hasFeature("minPrice") then
        return nil
    end

    local itemId = GetItemLinkItemId(itemLink)
    return TSCPriceData:GetMinPrice(itemId)
end

-- Get max price (only available with full data)
function DataAdapter.getMaxPrice(itemLink)
    if not DataAdapter.hasFeature("maxPrice") then
        return nil
    end

    local itemId = GetItemLinkItemId(itemLink)
    return TSCPriceData:GetMaxPrice(itemId)
end

-- Get sales count (only available with full data)
function DataAdapter.getSalesCount(itemLink)
    if not DataAdapter.hasFeature("salesCount") then
        return nil
    end

    local itemId = GetItemLinkItemId(itemLink)
    return TSCPriceData:GetSalesCount(itemId)
end

-- Get full data (only available with full data)
function DataAdapter.getFullData(itemLink)
    if not DataAdapter.hasFeature("fullData") then
        return nil
    end

    local itemId = GetItemLinkItemId(itemLink)
    return TSCPriceData:GetPrice(itemId)
end

-- Get formatted average price with fallback
function DataAdapter.getFormattedAvgPrice(itemLink)
    local result = DataAdapter.getAvgPrice(itemLink)

    -- Handle numeric price
    if result then
        return TSC_FormatterModule.toGold(result) .. " " .. goldIcon
    end

    return nil -- Let tooltip handle "no data" display
end

-- Get formatted price range (only for full data)
function DataAdapter.getFormattedPriceRange(itemLink)
    if not DataAdapter.hasFeature("minPrice") then
        return nil
    end

    local minPrice = DataAdapter.getCommonMinPrice(itemLink)
    local maxPrice = DataAdapter.getCommonMaxPrice(itemLink)

    if minPrice and maxPrice then
        return TSC_FormatterModule.toGold(minPrice) .. " - " .. TSC_FormatterModule.toGold(maxPrice) .. " " .. goldIcon
    end

    return nil
end

TSC_DataAdapterModule = DataAdapter
return DataAdapter
