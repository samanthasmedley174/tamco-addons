-- Ensure the data object exists (create if data file didn't load)
if not _G.TSCPriceDataPSNA then
    _G.TSCPriceDataPSNA = {}
end

local TSCPriceDataAPIPSNA = _G.TSCPriceDataPSNA

-- Expose as global with PSNA suffix
_G.TSCPriceDataAPIPSNA = TSCPriceDataAPIPSNA


function TSCPriceDataAPIPSNA:FormatItemName(itemLink)
    local itemName = GetItemLinkName(itemLink)

    -- Strip ZOS formatting suffixes in one pass
    itemName = string.gsub(itemName, "|H[^|]*|h", "")

    -- Remove anything after the ^ symbol
    itemName = string.gsub(itemName, "%^.*$", "")

    -- Trim any trailing whitespace
    itemName = string.gsub(itemName, "%s+$", "")

    return itemName
end

function TSCPriceDataAPIPSNA:GetPrice(itemLink)
    if itemLink == nil then 
        return nil 
    end
    if type(itemLink) ~= "string" then 
        return nil 
    end

    if not self or not self.priceData then
        return nil
    end
    
    local itemId = GetItemLinkItemId(itemLink)
    local data = nil

    if itemId then
        data = self.priceData and self.priceData[itemId]
    end

    if data == nil then
        local formattedName = self:FormatItemName(itemLink)
        data = self.priceData and self.priceData[formattedName]
    end

    if data == nil then return nil end
    -- Parse string format: "avgPrice,commonMin,commonMax"
    if type(data) == "string" then
        return tonumber(string.match(data, "^([^,]+)"))
    end

    return nil
end

function TSCPriceDataAPIPSNA:GetItemData(itemLink)
    if itemLink == nil then return nil end
    if type(itemLink) ~= "string" then return nil end

    local itemId = GetItemLinkItemId(itemLink)
    local data = nil

    if itemId then
        data = self.priceData and self.priceData[itemId]
    end

    if data == nil then
        local itemName = self:FormatItemName(itemLink)
        data = self.priceData and self.priceData[itemName]
    end

    if data == nil then return nil end
    -- Parse string format: "avgPrice,commonMin,commonMax"
    if type(data) == "string" then
        local avgPrice, commonMin, commonMax = string.match(data, "([^,]+),([^,]+),([^,]+)")
        return {
            avgPrice = tonumber(avgPrice),
            commonMin = tonumber(commonMin),
            commonMax = tonumber(commonMax)
        }
    end

    return nil
end
