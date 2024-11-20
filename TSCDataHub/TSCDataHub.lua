local TSCDataHub = {
    name = "TSCDataHub",
    version = "0.0.1",
}

-- Local references for performance
local EVENT_MANAGER = EVENT_MANAGER
local zo_callLater = zo_callLater
local GetItemLinkFunctionalQuality = GetItemLinkFunctionalQuality
local isInitialized = false
local SAVED_VARS_VERSION = 1
local ONE_DAY_SECONDS = 24 * 60 * 60
local GUILD_OBFUSCATION_CONSTANT = 12345 + 67890

local MAX_URL_CHARS_PC = 14900 -- Chrome
-- local MAX_URL_CHARS_PC = 1000 -- Chrome (for testing)
-- local MAX_URL_CHARS_PC = 2000 -- Firefox
-- local MAX_URL_CHARS_PC = 2000 -- Edge
local MAX_URL_CHARS_XBOX = 8000
local MAX_URL_CHARS_PS = 8000

-- QR_BATCH_SIZE removed - now using character-aware batching with URL character limits
local PROD_URL = "https://late-violet-4084.fly.dev/prod/esoapp/up/qr-data"
-- local LOCAL_TESTING_URL = ""
local TRANSACTION_SEPARATOR = ";" -- Between transactions

-- Default values for flags optimization
local DEFAULT_TRAIT = 0
local DEFAULT_QUALITY = 1
local DEFAULT_PERSONAL = 0
local DEFAULT_QUANTITY = 1

local savedVars           -- Will be set after initialization
local SERVER_PLATFORM     -- Will be set at initialization
local PLAYER_ACCOUNT_NAME -- Will be set at initialization
local CURRENT_MAX_CHARS   -- Will be set based on platform and user preference

-- Capture settings
local selectedGuildSlot = 1
local daysToCapture = 1

-- URL submission state
local urlTable = nil
local currentUrlIndex = nil
local totalUrls = nil

local OVERRIDE_AND_USE_CONSOLE_LIMITS = false

-- Default settings structure
TSCDataHub.default = {
    trackPersonalSales = false,
}

-- ============================================================================
-- QR CODE FUNCTIONS
-- ============================================================================

function TSCDataHub.showSettingsQRCode(url, title)
    if not LibQRCode then
        CHAT_ROUTER:AddSystemMessage("LibQRCode not available, opening URL directly")
        RequestOpenUnsafeURL(url)
        return
    end

    -- Create our own QR code window (copied from LibQRCode but with custom positioning)
    local defaultTextureSize = 200
    local defaultHeaderHeight = 30
    local defaultXInset = 5
    local defaultYInset = 5

    -- Get or create the settings window
    local qrWindow = WINDOW_MANAGER:GetControlByName("TSCDataHubSettingsQRWindow")
    if qrWindow == nil then
        -- Create the main window (only once)
        qrWindow = WINDOW_MANAGER:CreateTopLevelWindow("TSCDataHubSettingsQRWindow")
        local windowWidth = defaultTextureSize + 2 * defaultXInset
        local windowHeight = defaultTextureSize + defaultHeaderHeight + 3 * defaultYInset
        qrWindow:SetDimensions(windowWidth, windowHeight)

        -- Position at center + 500px offset
        qrWindow:SetAnchor(CENTER, GUI_ROOT, CENTER, 500, 0)
        qrWindow:SetMovable(true)
        qrWindow:SetMouseEnabled(true)
        qrWindow:SetClampedToScreen(true)

        -- Create title header
        local header = WINDOW_MANAGER:CreateControl("TSCDataHubSettingsQRTitle", qrWindow, CT_LABEL)
        header:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        header:SetDimensions(defaultTextureSize, defaultHeaderHeight)
        header:SetColor(0.5, 0.5, 1, 1) -- Blue color like original
        header:SetAnchor(TOP, qrWindow, TOP, 0, defaultYInset)
        header:SetFont("ZoFontAnnounceMedium")

        -- Add backdrop
        local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("TSCDataHubSettingsQRBackdrop", qrWindow,
            "ZO_DefaultBackdrop")
        backdrop:SetAnchorFill()
        backdrop:SetDrawTier(DT_LOW)

        -- Add close button
        local closeButton = WINDOW_MANAGER:CreateControl("TSCDataHubSettingsQRCloseButton", qrWindow, CT_BUTTON)
        closeButton:SetDimensions(defaultHeaderHeight, defaultHeaderHeight)
        closeButton:SetAnchor(TOPRIGHT, qrWindow, TOPRIGHT, defaultXInset, defaultYInset)
        closeButton:SetHandler("OnClicked", function()
            SCENE_MANAGER:ToggleTopLevel(qrWindow)
            qrWindow:SetHidden(true)
        end)
        closeButton:SetEnabled(true)
        closeButton:SetNormalTexture("EsoUI/Art/Buttons/closebutton_up.dds")
        closeButton:SetPressedTexture("EsoUI/Art/Buttons/closebutton_down.dds")
        closeButton:SetMouseOverTexture("EsoUI/Art/Buttons/closebutton_mouseover.dds")
        closeButton:EnableMouseButton(MOUSE_BUTTON_INDEX_LEFT, true)
    else
        -- Window already exists, just show it
        SCENE_MANAGER:ToggleTopLevel(qrWindow)
        qrWindow:SetHidden(false)
    end

    -- Update the title
    local header = WINDOW_MANAGER:GetControlByName("TSCDataHubSettingsQRTitle")
    if header then
        header:SetText(title or "QR Code")
    end

    -- Create or update QR code
    local qrContainer = WINDOW_MANAGER:GetControlByName("TSCDataHubSettingsQRContainer")
    if qrContainer == nil then
        qrContainer = LibQRCode.CreateQRControl(defaultTextureSize, url)
    else
        LibQRCode.DrawQRCode(qrContainer, url)
    end

    qrContainer:SetParent(qrWindow)
    qrContainer:SetAnchor(TOPLEFT, qrWindow, TOPLEFT, defaultXInset, defaultHeaderHeight + 2 * defaultYInset)
    qrContainer:SetAnchor(BOTTOMRIGHT, qrWindow, BOTTOMRIGHT, -defaultXInset, -defaultYInset)

    -- Auto-hide after 10 seconds
    zo_callLater(function()
        if not qrWindow:IsHidden() then
            qrWindow:SetHidden(true)
        end
    end, 10000)
end

function TSCDataHub.showGuildDataURL(url, title)
    RequestOpenUnsafeURL(url)
end

-- ============================================================================
-- URL SUBMISSION FUNCTIONS
-- ============================================================================

function TSCDataHub.updateSubmitButton()
    -- Force LHAS to refresh the controls like Dolgubons does
    if TSCDataHub.settings and TSCDataHub.settings.UpdateControls then
        TSCDataHub.settings:UpdateControls()
    end
end

function TSCDataHub.submitNextURL()
    if not urlTable or not currentUrlIndex or currentUrlIndex > totalUrls then
        return
    end

    local url = urlTable[currentUrlIndex]
    if url then
        RequestOpenUnsafeURL(url)
        currentUrlIndex = currentUrlIndex + 1
        TSCDataHub.updateSubmitButton()
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function setMaxCharactersForCurrentSetup()
    if OVERRIDE_AND_USE_CONSOLE_LIMITS then
        -- Override for testing using console limits while on PC
        CURRENT_MAX_CHARS = MAX_URL_CHARS_XBOX
    elseif SERVER_PLATFORM == 2 or SERVER_PLATFORM == 5 or SERVER_PLATFORM == 6 then
        -- PC platforms (NA PC, EU PC, PTS PC)
        CURRENT_MAX_CHARS = MAX_URL_CHARS_PC
    elseif SERVER_PLATFORM == 0 or SERVER_PLATFORM == 3 then
        -- Xbox platforms (NA Xbox, EU Xbox)
        CURRENT_MAX_CHARS = MAX_URL_CHARS_XBOX
    elseif SERVER_PLATFORM == 1 or SERVER_PLATFORM == 4 then
        -- PlayStation platforms (NA PS, EU PS)
        CURRENT_MAX_CHARS = MAX_URL_CHARS_PS
    else
        -- Unknown platform, use Xbox limit, as console limits are more restrictive
        CURRENT_MAX_CHARS = MAX_URL_CHARS_XBOX
    end
end

local function obfuscateGuildId(guildId)
    -- Mathematical transformation to create 6-digit obfuscated ID
    return (guildId * GUILD_OBFUSCATION_CONSTANT) % 1000000
end

local function isGuildHistoryReady(guildId, category)
    local numEvents = GetNumGuildHistoryEvents(guildId, category)
    return numEvents > 0
end

local function isSalesEvent(eventData)
    -- Check if event is a sales event
    -- For now, accept type 0 since that's what we're getting from the API
    return eventData and
        (eventData.eventType == 0 or eventData.eventType == GUILD_EVENT_ITEM_SOLD or eventData.eventType == GUILD_EVENT_ITEM_LISTED)
end

local function extractSalesDetails(eventData)
    -- CHAT_ROUTER:AddSystemMessage("extractSalesDetails: " .. eventData.itemLink)
    -- Use ESO's built-in functions to extract item information
    local itemId = GetItemLinkItemId(eventData.itemLink)
    -- CHAT_ROUTER:AddSystemMessage("extractSalesDetails: " .. itemId)
    local trait = GetItemLinkTraitInfo(eventData.itemLink)
    -- CHAT_ROUTER:AddSystemMessage("extractSalesDetails: " .. trait)
    local quality = GetItemLinkFunctionalQuality(eventData.itemLink)
    -- CHAT_ROUTER:AddSystemMessage("extractSalesDetails: " .. quality)

    -- Convert to standardized transaction format
    return {
        itemId = itemId,
        trait = trait,
        quality = quality,
        price = eventData.price or 0,
        timestamp = eventData.timestamp,
        seller = eventData.seller or "",
        quantity = eventData.quantity or 1
    }
end


-- ============================================================================
-- DATA FETCHING FUNCTIONS (Phase 1)
-- ============================================================================


local function waitForGuildHistory(guildId, category, callback, maxRetries)
    maxRetries = maxRetries or 10 -- Default to 10 retries (5 seconds)

    if isGuildHistoryReady(guildId, category) then
        callback()
    elseif maxRetries > 0 then
        zo_callLater(function()
            waitForGuildHistory(guildId, category, callback, maxRetries - 1)
        end, 500) -- Wait 500ms before retry
    else
        CHAT_ROUTER:AddSystemMessage("Guild history failed to load")
        callback() -- Proceed anyway, let the individual fetches handle failures
    end
end

local function fetchEventData(guildId, category, index)
    -- For trader events, use the specific trader API
    if category == GUILD_HISTORY_EVENT_CATEGORY_TRADER then
        local eventId, timestampS, _, eventType, sellerDisplayName, _, itemLink, quantity, price, _ =
            GetGuildHistoryTraderEventInfo(guildId, index)

        -- Check if we got valid data
        if not eventId or eventId == 0 or not timestampS or timestampS == 0 then
            return nil
        end

        return {
            eventId = eventId,
            timestamp = timestampS,
            eventType = eventType,
            index = index,
            seller = sellerDisplayName,
            itemLink = itemLink,
            quantity = quantity,
            price = price,
        }
    else
        -- For other categories, use basic info
        local eventId, eventTimestamp = GetGuildHistoryEventBasicInfo(guildId, category, index)

        if not eventId or eventId == 0 or not eventTimestamp or eventTimestamp == 0 then
            return nil
        end

        return {
            eventId = eventId,
            timestamp = eventTimestamp,
            index = index
        }
    end
end

local function processEventBatch(guildId, category, startIndex, endIndex)
    local totalEvents = 0
    local salesEvents = {}
    local salesCount = 0
    local eventTypeCounts = {}

    -- Process each index in the range
    for index = startIndex, endIndex do
        totalEvents = totalEvents + 1

        -- Fetch basic event data
        local eventData = fetchEventData(guildId, category, index)
        if eventData then
            -- Track event types for debugging
            local eventType = eventData.eventType or "unknown"
            eventTypeCounts[eventType] = (eventTypeCounts[eventType] or 0) + 1

            -- Log first few events to see what we're getting
            -- if totalEvents <= 5 then
            --     CHAT_ROUTER:AddSystemMessage("Event " ..
            --         tostring(index) ..
            --         " - Type: " .. tostring(eventType) .. ", Price: " .. tostring(eventData.price or "nil"))
            --     CHAT_ROUTER:AddSystemMessage("  Full data: " ..
            --         tostring(eventData.eventId) ..
            --         ", " ..
            --         tostring(eventData.timestamp) ..
            --         ", " ..
            --         tostring(eventData.seller or "nil") ..
            --         ", " ..
            --         tostring(eventData.buyer or "nil") ..
            --         ", " .. tostring(eventData.quantity or "nil") .. ", " .. tostring(eventData.tax or "nil"))
            --     CHAT_ROUTER:AddSystemMessage("  Raw itemLink: " .. tostring(eventData.itemLink or "nil"))
            -- end

            -- Check if it's a sales event
            if isSalesEvent(eventData) then
                salesCount = salesCount + 1

                -- Get detailed sales data
                local salesData = extractSalesDetails(eventData)
                if salesData then
                    table.insert(salesEvents, salesData)
                end
            end
        end
    end

    -- Log event type breakdown
    -- CHAT_ROUTER:AddSystemMessage("Event types found:")
    for eventType, count in pairs(eventTypeCounts) do
        -- CHAT_ROUTER:AddSystemMessage("  Type " .. tostring(eventType) .. ": " .. tostring(count) .. " events")
    end

    -- CHAT_ROUTER:AddSystemMessage("Found " .. tostring(salesCount) .. " sales events")

    return salesEvents
end

local function fetchGuildSalesBatch(guildId, startTime, callback)
    local currentTime = GetTimeStamp()

    -- Use TRADER category for sales data
    local newestIndex, oldestIndex = GetGuildHistoryEventIndicesForTimeRange(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER,
        currentTime, startTime)

    if not newestIndex or not oldestIndex then
        CHAT_ROUTER:AddSystemMessage("No guild history events found in time range")
        callback(nil, {}, true)
        return
    end

    -- Determine the correct order (oldest to newest)
    local startIndex, endIndex
    if oldestIndex <= newestIndex then
        startIndex, endIndex = oldestIndex, newestIndex
    else
        startIndex, endIndex = newestIndex, oldestIndex
    end

    -- Wait for guild history to be ready before processing
    waitForGuildHistory(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, function()
        -- Process the event batch using our new modular functions
        local salesEvents = processEventBatch(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, startIndex, endIndex)

        -- Return the sales events to the callback
        callback(salesEvents, true)
    end)
end

-- ============================================================================
-- DATA ENCODING FUNCTIONS
-- ============================================================================

local function encodeFlags(trait, quality, isPersonalSale, quantity)
    -- Check if any values are non-default
    if trait == DEFAULT_TRAIT and quality == DEFAULT_QUALITY and (isPersonalSale and 1 or 0) == DEFAULT_PERSONAL and quantity == DEFAULT_QUANTITY then
        return nil -- No flags needed
    end

    -- Build base flags: quality + personal + trait (padded to 2 digits)
    local personal = isPersonalSale and 1 or 0
    local flags = string.format("%d%d%02d", quality, personal, trait)

    -- Add quantity if it's not the default
    if quantity ~= DEFAULT_QUANTITY then
        flags = flags .. string.format("%03d", quantity)
    end

    return flags
end

local function encodeTransaction(transaction, minTimestamp)
    local deltaTime = transaction.timestamp - minTimestamp

    -- Check if this is a personal sale (if tracking is enabled)
    local isPersonalSale = savedVars.trackPersonalSales and transaction.seller == PLAYER_ACCOUNT_NAME

    -- Encode flags if any are non-default
    local flags = encodeFlags(transaction.trait, transaction.quality, isPersonalSale, transaction.quantity or 1)

    local encodedTransaction
    if flags then
        -- Include flags field: itemId,price,deltaTime,flags
        encodedTransaction = string.format("%d,%d,%d,%s",
            transaction.itemId,
            transaction.price,
            deltaTime,
            flags
        )
    else
        -- No flags field: itemId,price,deltaTime
        encodedTransaction = string.format("%d,%d,%d",
            transaction.itemId,
            transaction.price,
            deltaTime
        )
    end

    return encodedTransaction
end

local function createURLFromEncodedBatch(encodedBatch, guildId, referenceTimestamp)
    local dataString = table.concat(encodedBatch.encodedTransactions, TRANSACTION_SEPARATOR)

    -- PROD_URL
    local url = string.format("%s?sp=%d&g=%d&t=%d&d=%s", PROD_URL, SERVER_PLATFORM, guildId, referenceTimestamp,
        dataString)

    -- LOCAL_TESTING_URL
    --  local url = string.format("%s?sp=%d&g=%d&t=%d&d=%s", LOCAL_TESTING_URL, SERVER_PLATFORM, guildId, referenceTimestamp,
    -- dataString)
    return url
end

local function createEncodedBatches(encodedTransactions, maxTransactionChars)
    -- Split encoded transactions into batches based on character count
    local batches = {}
    local currentBatch = {
        encodedTransactions = {}
    }
    local currentBatchLength = 0

    for _, encodedTxn in ipairs(encodedTransactions) do
        local transactionLength = string.len(encodedTxn.encoded) + 1 -- +1 for separator

        -- Check if adding this transaction would exceed the limit
        if (currentBatchLength + transactionLength) > maxTransactionChars and #currentBatch.encodedTransactions > 0 then
            -- Current batch is full, save it and start fresh
            table.insert(batches, currentBatch)
            currentBatch = {
                encodedTransactions = { encodedTxn.encoded }
            }
            currentBatchLength = transactionLength
        else
            -- Add to current batch
            table.insert(currentBatch.encodedTransactions, encodedTxn.encoded)
            currentBatchLength = currentBatchLength + transactionLength
        end
    end

    -- Add remaining transactions
    if #currentBatch.encodedTransactions > 0 then
        table.insert(batches, currentBatch)
    end
    return batches
end

-- ============================================================================
-- SERVICE FUNCTIONS
-- ============================================================================

local function validateGuildSlot(guildSlot)
    local numGuilds = GetNumGuilds()

    if guildSlot > numGuilds then
        local ordinal = ""
        if guildSlot == 1 then
            ordinal = "1st"
        elseif guildSlot == 2 then
            ordinal = "2nd"
        elseif guildSlot == 3 then
            ordinal = "3rd"
        else
            ordinal = guildSlot .. "th"
        end

        return nil, "You don't have a " .. ordinal .. " guild!"
    end

    return true
end

local function getGuildData(guildSlot, daysToCapture)
    local guildId = GetGuildId(guildSlot)
    local obfuscatedId = obfuscateGuildId(guildId)

    -- Calculate start time based on user-selected days
    local currentTime = GetTimeStamp()
    local startTime = currentTime - (daysToCapture * 86400) -- 86400 = seconds per day

    CHAT_ROUTER:AddSystemMessage("Capturing data from " .. daysToCapture .. " days ago (timestamp: " .. startTime .. ")")

    return {
        guildId = guildId,
        obfuscatedId = obfuscatedId,
        startTime = startTime,
        currentTime = currentTime
    }
end

-- ============================================================================
-- CONTROLLER FUNCTIONS
-- ============================================================================

local function CheckGuildAndCollect(guildSlot, daysToCapture)
    -- Step 1: Validate guild slot
    local isValid, errorMsg = validateGuildSlot(guildSlot)
    if not isValid then
        CHAT_ROUTER:AddSystemMessage(errorMsg)
        return
    end

    -- Step 2: Get guild data
    local guildData = getGuildData(guildSlot, daysToCapture)

    -- CHAT_ROUTER:AddSystemMessage("Starting data collection for guild " .. guildData.obfuscatedId)

    -- Step 3: Start batch data collection
    local batchNumber = 1

    urlTable = {} -- Store all URLs for data export

    local function processBatch(salesEvents, isLastBatch)
        if salesEvents and #salesEvents > 0 then
            -- Use collection start time as universal reference for delta compression
            local referenceTimestamp = guildData.startTime

            -- Step 1: Encode all transactions with reference-based deltas
            local encodedTransactions = {}
            for _, transaction in ipairs(salesEvents) do
                local encoded = encodeTransaction(transaction, referenceTimestamp)
                table.insert(encodedTransactions, {
                    encoded = encoded,
                    timestamp = transaction.timestamp
                })
            end

            -- Step 2: Create character-aware batches using platform and method specific limits
            -- CHAT_ROUTER:AddSystemMessage("Using " .. CURRENT_MAX_CHARS .. " character limit for direct URLs")
            local batches = createEncodedBatches(encodedTransactions, CURRENT_MAX_CHARS)

            -- Step 3: Create URLs from encoded batches with reference timestamp
            for i, batch in ipairs(batches) do
                local url = createURLFromEncodedBatch(batch, guildData.obfuscatedId, referenceTimestamp)
                table.insert(urlTable, url)
            end

            batchNumber = batchNumber + #batches

            if not isLastBatch then
                -- Continue to next batch
                fetchGuildSalesBatch(guildData.guildId, guildData.startTime, processBatch)
            else
                if #urlTable > 0 then
                    -- Store URLs for manual submission
                    urlTable = urlTable
                    currentUrlIndex = 1
                    totalUrls = #urlTable
                    -- Update the submit button to be enabled
                    TSCDataHub.updateSubmitButton()
                end
            end
        end
    end

    -- Wait a bit for guild history to be ready (like LibHistoire does)
    zo_callLater(function()
        fetchGuildSalesBatch(guildData.guildId, guildData.startTime, processBatch)
    end, 1000) -- Wait 1 second before starting
end

-- ============================================================================
-- SETTINGS FUNCTIONS
-- ============================================================================

local function setupSettingsMenu()
    local LHAS = LibHarvensAddonSettings
    if not LHAS then
        d("LibHarvensAddonSettings not found - settings menu will not be available")
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
    local settings = LHAS:AddAddon("TSC Data Hub", options)
    if not settings then
        return
    end

    -- Store reference to settings for refreshing
    TSCDataHub.settings = settings

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
        tooltip = [[v100: Initial release

Scan the QR code to view full update details]],
        buttonText = "View Update Info",
        clickHandler = function(control, button)
            TSCDataHub.showSettingsQRCode("https://tamrielsavings.com/updates", "What's New")
        end,
    }
    settings:AddSetting(whatsNewButton)

    local bugReportButton = {
        type = LHAS.ST_BUTTON,
        label = "Troubleshoot",
        tooltip = "Generate a QR code that will link to the FAQ + Troubleshooting page on tamrielsavings.com",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            TSCDataHub.showSettingsQRCode("https://tamrielsavings.com/faq", "Troubleshoot")
        end,
    }
    settings:AddSetting(bugReportButton)

    local discordButton = {
        type = LHAS.ST_BUTTON,
        label = "Join TSC on Discord",
        tooltip = "Generate a QR code that will link to the TSC Discord server",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            TSCDataHub.showSettingsQRCode("https://discord.gg/7DzUVCQ", "Join TSC on Discord")
        end,
    }
    settings:AddSetting(discordButton)

    local donateButton = {
        type = LHAS.ST_BUTTON,
        label = "Donate to TSC",
        tooltip = "Generate a QR code that will link to the Donate page on tamrielsavings.com",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            TSCDataHub.showSettingsQRCode("https://tamrielsavings.com/donations", "Donate to TSC")
        end,
    }
    settings:AddSetting(donateButton)

    --[[
        TRADING SETTINGS SECTION
    --]]
    local tradingSettingsSection = {
        type = LHAS.ST_SECTION,
        label = "Sales Tracking Settings",
    }
    settings:AddSetting(tradingSettingsSection)

    local trackPersonalSales = {
        type = LHAS.ST_CHECKBOX,
        label = "Track Personal Sales",
        tooltip =
        "Setting this ON will track allow you to track your personal sales on the website.  Setting this OFF will not track your personal sales.",
        default = false,
        setFunction = function(state)
            savedVars.trackPersonalSales = state
        end,
        getFunction = function()
            return savedVars.trackPersonalSales
        end,
    }
    settings:AddSetting(trackPersonalSales)

    --[[
        TRADING SETTINGS SECTION
    --]]
    local tradingSettingsSection = {
        type = LHAS.ST_SECTION,
        label = "Sales Tracking",
    }
    settings:AddSetting(tradingSettingsSection)

    local guildSelectorControl = {
        type = LibHarvensAddonSettings.ST_DROPDOWN,
        label = "Guild",
        tooltip = "Choose the guild you want to track",
        items = function()
            local guilds = {}
            local numGuilds = GetNumGuilds()
            for i = 1, numGuilds do
                local guildId = GetGuildId(i)
                local guildName = GetGuildName(guildId)
                if guildName and guildName ~= "" then
                    table.insert(guilds, {
                        name = guildName,
                        data = i
                    })
                end
            end
            return guilds
        end,
        getFunction = function()
            -- Return the guild name for display, not the slot number
            if selectedGuildSlot then
                local guildId = GetGuildId(selectedGuildSlot)
                local guildName = GetGuildName(guildId)
                return guildName or "No Guild Selected"
            end
            return "No Guild Selected"
        end,
        setFunction = function(combobox, value, item)
            selectedGuildSlot = item.data -- This will be the guild slot number
        end,
        default = 1
    }
    settings:AddSetting(guildSelectorControl)

    local daysToCaptureSlider = {
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Days to Capture",
        tooltip = "Number of days to go back when capturing guild data (1 = today only, 7 = full week)",
        min = 1,
        max = 7,
        step = 1,
        format = "%d",
        unit = " days",
        getFunction = function()
            return daysToCapture
        end,
        setFunction = function(value)
            daysToCapture = value
        end,
        default = 1
    }
    settings:AddSetting(daysToCaptureSlider)

    local captureButton = {
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Capture Guild Data",
        tooltip = "Start capturing guild data for the selected guild and number of days",
        buttonText = "Capture",
        clickHandler = function()
            if selectedGuildSlot then
                -- CHAT_ROUTER:AddSystemMessage("Starting capture for guild slot " ..
                --     selectedGuildSlot .. " with " .. daysToCapture .. " days")
                return CheckGuildAndCollect(selectedGuildSlot, daysToCapture)
            else
                -- CHAT_ROUTER:AddSystemMessage("Please select a guild first")
            end
        end
    }
    settings:AddSetting(captureButton)

    --[[
        URL SUBMISSION SECTION
    --]]
    local urlSubmissionSection = {
        type = LHAS.ST_SECTION,
        label = "URL Submission",
    }
    settings:AddSetting(urlSubmissionSection)

    local submitButton = {
        type = LHAS.ST_BUTTON,
        label = function()
            if not urlTable or not currentUrlIndex or not totalUrls then
                return "No URLs available"
            end
            if currentUrlIndex > totalUrls then
                return "All URLs submitted"
            end
            return string.format("Submit URL %d of %d", currentUrlIndex, totalUrls)
        end,
        tooltip = "Submit the next URL in the queue",
        buttonText = "Submit",
        disable = function()
            if not urlTable or not currentUrlIndex or not totalUrls then
                return true
            end
            if currentUrlIndex > totalUrls then
                return true
            end
            return false
        end,
        clickHandler = function()
            TSCDataHub.submitNextURL()
        end,
    }
    settings:AddSetting(submitButton)

    -- Store references for updates (store the actual control objects)
    TSCDataHub.submitButton = submitButton
end

-- ============================================================================
-- INITIALIZATION FUNCTIONS
-- ============================================================================

local function initializeSavedVars()
    -- Initialize account-wide saved variables
    TSCDataHub.savedVars = ZO_SavedVars:NewAccountWide(
        "TSCDataHubData", SAVED_VARS_VERSION, nil, TSCDataHub.default)

    -- Set local reference for performance
    savedVars = TSCDataHub.savedVars

    -- Handle migration by adding any missing default fields
    if TSCDataHub.savedVars.version ~= SAVED_VARS_VERSION then
        for key, defaultValue in pairs(TSCDataHub.default) do
            if TSCDataHub.savedVars[key] == nil then
                TSCDataHub.savedVars[key] = defaultValue
            end
        end
        TSCDataHub.savedVars.version = SAVED_VARS_VERSION
    end
end

local function setServerPlatform()
    local worldName = GetWorldName()
    local platform = GetUIPlatform()

    if string.find(worldName, "NA") then
        if platform == UI_PLATFORM_XBOX then
            SERVER_PLATFORM = 0 -- NA Xbox
        elseif platform == UI_PLATFORM_PS4 or platform == UI_PLATFORM_PS5 then
            SERVER_PLATFORM = 1 -- NA PlayStation
        else
            SERVER_PLATFORM = 2 -- NA PC
        end
    elseif string.find(worldName, "EU") then
        if platform == UI_PLATFORM_XBOX then
            SERVER_PLATFORM = 3 -- EU Xbox
        elseif platform == UI_PLATFORM_PS5 then
            SERVER_PLATFORM = 4 -- EU PlayStation
        else
            SERVER_PLATFORM = 5 -- EU PC
        end
    elseif string.find(worldName, "PTS") then
        SERVER_PLATFORM = 6 -- PTS PC (only platform that has PTS)
    else
        SERVER_PLATFORM = 9 -- Unknown
    end
end

local function getServerPlatform()
    local platformNames = {
        [0] = "Xbox NA",
        [1] = "PlayStation NA", 
        [2] = "PC NA",
        [3] = "Xbox EU",
        [4] = "PlayStation EU",
        [5] = "PC EU",
        [6] = "PTS PC",
        [9] = "Unknown"
    }
    
    -- local platformName = platformNames[SERVER_PLATFORM] or "Unknown"
    -- CHAT_ROUTER:AddSystemMessage("You are playing on: " .. platformName)
    -- return platformName
    local worldName = GetWorldName()
    local platform = GetUIPlatform()
    CHAT_ROUTER:AddSystemMessage("GetWorldName: " .. worldName )
    CHAT_ROUTER:AddSystemMessage("GetUIPlatform: " .. platform)
    CHAT_ROUTER:AddSystemMessage("GetUIPlatform: " .. platformNames[platform])


end

local function initialize()
    if isInitialized then
        return
    end

    -- Initialize server platform once
    setServerPlatform()
    -- Set initial character limits based on platform and user preference
    setMaxCharactersForCurrentSetup()
    setupSettingsMenu()
    PLAYER_ACCOUNT_NAME = string.gsub(GetDisplayName(), "^@", " ")

    SLASH_COMMANDS["/tscdhg1"] = function()
        CheckGuildAndCollect(1, 2)
    end

    SLASH_COMMANDS["/tscdhg2"] = function()
        CheckGuildAndCollect(2, 2)
    end

    SLASH_COMMANDS["/tscdhg3"] = function()
        CheckGuildAndCollect(3, 2)
    end

    SLASH_COMMANDS["/tscdhg4"] = function()
        CheckGuildAndCollect(4, 2)
    end

    SLASH_COMMANDS["/tscdhg5"] = function()
        CheckGuildAndCollect(5, 2)
    end

    SLASH_COMMANDS["/tester"] = function()
        CHAT_ROUTER:AddSystemMessage("UI_PLATFORM_PC: " .. UI_PLATFORM_PC)
        CHAT_ROUTER:AddSystemMessage("UI_PLATFORM_PS4: " .. UI_PLATFORM_PS4)
        CHAT_ROUTER:AddSystemMessage("UI_PLATFORM_PS5: " .. UI_PLATFORM_PS5)
        CHAT_ROUTER:AddSystemMessage("UI_PLATFORM_REUSE_ME: " .. UI_PLATFORM_REUSE_ME)
        CHAT_ROUTER:AddSystemMessage("UI_PLATFORM_XBOX: " .. UI_PLATFORM_XBOX)
    end

    isInitialized = true


    zo_callLater(function()
        CHAT_ROUTER:AddSystemMessage("Hello" .. tostring(PLAYER_ACCOUNT_NAME) .. "!")
        CHAT_ROUTER:AddSystemMessage("Thanks for helping out with testing!")
        getServerPlatform()
        CHAT_ROUTER:AddSystemMessage("Please let us know if the server and platform message above is accurate!")
    end, 5000)
end

-- ============================================================================
-- ADDON SETUP
-- ============================================================================

_G.TSCDataHub = TSCDataHub

-- Register events directly
EVENT_MANAGER:RegisterForEvent(TSCDataHub.name, EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == TSCDataHub.name then
        -- Initialize saved variables first
        initializeSavedVars()

        -- Initialize the addon
        initialize()

        EVENT_MANAGER:UnregisterForEvent(TSCDataHub.name, EVENT_ADD_ON_LOADED)
    end
end)

EVENT_MANAGER:RegisterForEvent(TSCDataHub.name, EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(TSCDataHub.name, EVENT_PLAYER_ACTIVATED)
end)
