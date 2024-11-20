d("TSCPriceFetcher.lua loaded")
-- main.lua
local TSCPriceFetcher = {
    name = "TSCPriceFetcher",
    version = "0.0.1",
    modules = {}, -- Container for our modules
    dataSource = "none",
    priceEnabled = false
}

-- Make it globally accessible (needed for ESO addon structure)
_G.TSCPriceFetcher = TSCPriceFetcher

TSCPriceFetcher.modules.debug = TSC_DebugModule
TSCPriceFetcher.modules.tooltips = TSC_TooltipsModule
TSCPriceFetcher.modules.createListingHooks = TSC_CreateListingHooksModule
TSCPriceFetcher.modules.init = TSC_InitModule
TSCPriceFetcher.modules.events = TSC_EventsModule
TSCPriceFetcher.modules.lookup = TSC_LookupModule
TSCPriceFetcher.modules.dataAdapter = TSC_DataAdapterModule

-- Data source detection and initialization
local function detectDataSources()
    local hasFullData = _G.TSCPriceData ~= nil
    local hasAverageData = _G.TSCPriceDataLite ~= nil

    if hasFullData then
        return "full"
    elseif hasAverageData then
        return "lite"
    else
        return "none"
    end
end

local function notifyMissingData()
    d("|cFF6B6B[TSC Price Fetcher]|r No price data addon detected!")
    d("|cFFFFFF - Install either 'TSCPriceDataFull' for complete price data")
    d("|cFFFFFF - Or 'TSCPriceDataLite' for average prices only")
end

function TSCPriceFetcher.initializeDataSource()
    TSCPriceFetcher.dataSource = detectDataSources()
    TSCPriceFetcher.priceEnabled = TSCPriceFetcher.dataSource ~= "none"

    if not TSCPriceFetcher.priceEnabled then
        notifyMissingData()
    else
        TSCPriceFetcher.modules.debug.success("Using " .. TSCPriceFetcher.dataSource .. " data source")
    end
end

TSCPriceFetcher.modules.events.registerAll()

return TSCPriceFetcher
