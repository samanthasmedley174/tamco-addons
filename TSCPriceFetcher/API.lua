local TSCPriceDataAPI = _G.TSCPriceDataAPI


function TSCPriceDataAPI:FormatItemName(itemLink)
    local itemName = GetItemLinkName(itemLink)

    -- Strip ZOS formatting suffixes in one pass
    itemName = string.gsub(itemName, "|H[^|]*|h", "")

    -- Remove anything after the ^ symbol
    itemName = string.gsub(itemName, "%^.*$", "")

    -- Trim any trailing whitespace
    itemName = string.gsub(itemName, "%s+$", "")

    return itemName
end

function TSCPriceDataAPI:GetPrice(itemLink)
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
        return tonumber(string.match(data, "^([^,]+)"))
    end

    return nil
end

function TSCPriceDataAPI:GetItemData(itemLink)
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
