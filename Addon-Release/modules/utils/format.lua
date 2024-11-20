local Formatter = {}

--[[
    Formats a number with commas for thousands.
    Example: 1234567 -> "1,234,567"
]]
function Formatter.toGold(amount)
    amount = tonumber(amount)
    if not amount then return "0" end
    return ZO_CommaDelimitNumber(amount)
end

--[[
    Strips ESO localization suffixes (e.g., ^M, ^F) from item names.
    Uses zo_strformat for robust, game-consistent handling.
    Example: "Iron Sword^m" -> "Iron Sword"
]]
function Formatter.StripEsoSuffix(itemName)
    if type(itemName) ~= "string" then return "" end
    return zo_strformat("<<1>>", itemName)
end

TSC_FormatterModule = Formatter
return Formatter
