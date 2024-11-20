d("TSCPriceFetcher.lua loaded")
-- main.lua
local TSCPriceFetcher = {
    name = "TSCPriceFetcher",
    version = "0.0.1",
    modules = {} -- Container for our modules
}

-- Make it globally accessible (needed for ESO addon structure)
_G.TSCPriceFetcher = TSCPriceFetcher

TSCPriceFetcher.modules.debug = TSC_DebugModule
TSCPriceFetcher.modules.tooltips = TSC_TooltipsModule
TSCPriceFetcher.modules.init = TSC_InitModule
TSCPriceFetcher.modules.events = TSC_EventsModule
TSCPriceFetcher.modules.lookup = TSC_LookupModule

TSCPriceFetcher.modules.events.registerAll()

return TSCPriceFetcher
