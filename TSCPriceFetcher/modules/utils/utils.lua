local Utils = {}

local COLORS = {
    TSC_GREEN = "009449"
}

function Utils.colorize(msg, color)
    return string.format("|c%s%s|r", color, tostring(msg))
end

--[[
    Checks if the tooltip already contains TSC price info
    @param tooltip (table): The tooltip object to check
    @return (boolean): true if price info is present
]]
function Utils.TooltipHasPriceInfo(tooltip)
    if not tooltip then return false end

    -- Check scrollTooltip.contents
    if tooltip.scrollTooltip and tooltip.scrollTooltip.contents and tooltip.scrollTooltip.contents.GetNumChildren then
        local content = tooltip.scrollTooltip.contents
        local numChildren = content:GetNumChildren()
        for i = 1, numChildren do
            local child = content:GetChild(i)
            if child and child.GetText then
                local text = child:GetText()
                if text and (text:find("Tamriel Savings Co") or text:find("Average Price:") or text:find("No Price Data Available") or text:find("Bound Item")) then
                    return true
                end
            end
        end
    end

    -- Check direct children
    if tooltip.GetNumChildren then
        local numChildren = tooltip:GetNumChildren()
        for i = 1, numChildren do
            local child = tooltip:GetChild(i)
            if child and child.GetText then
                local text = child:GetText()
                if text and (text:find("Tamriel Savings Co") or text:find("Average Price:") or text:find("No Price Data Available") or text:find("Bound Item")) then
                    return true
                end
            end
        end
    end

    return false
end

--[[
    Adds TSC price info section to a tooltip
    @param tooltip (table): The tooltip object to modify
    @param itemLink (string): The item link being listed
]]
function Utils.AddPriceInfoSection(tooltip, itemLink)
    local priceSection = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    priceSection:AddLine(Utils.colorize("Tamriel Savings Co", COLORS.TSC_GREEN), tooltip:GetStyle("bodyDescription"))

    -- Check if item is bound
    if IsItemLinkBound(itemLink) then
        priceSection:AddLine("Bound Item", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        return
    end

    -- Get price data
    local formattedPrice = TSC_DataAdapterModule.getFormattedAvgPrice(itemLink)
    local priceRange = TSC_DataAdapterModule.getFormattedPriceRange(itemLink)
    local salesCount = TSC_DataAdapterModule.getSalesCount(itemLink)

    -- Check if we have any data
    local hasData = formattedPrice or priceRange or salesCount

    if not hasData then
        priceSection:AddLine("No Price Data Available", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        return
    end

    -- Add price data
    if formattedPrice then
        priceSection:AddLine("Average Price: " .. formattedPrice, tooltip:GetStyle("bodyDescription"))
    end

    if priceRange then
        priceSection:AddLine("Range: " .. priceRange, tooltip:GetStyle("bodyDescription"))
    end

    if salesCount then
        priceSection:AddLine("Sales: " .. tostring(salesCount), tooltip:GetStyle("bodyDescription"))
    end

    tooltip:AddSection(priceSection)
end

TSC_UtilsModule = Utils
return Utils
