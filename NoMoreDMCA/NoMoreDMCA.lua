local AddonName = "NoMoreDMCA"
local QRCodeMade = false
local QRHidden = true
local timerStart = 59
local timer = timerStart
local updateCycle = 0.2
local xLast, yLast

-- 1 = Black Square,0 = White/Empty
--https://www.dcode.fr/binary-image
--[[
local qrCode = {
    {1,1,1,1,1,1,1,0,0,0,0,0,1,0,1,1,1,0,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,1,0,1,0,1,0,1,1,1,0,0,0,1,0,0,0,0,0,1},
    {1,0,1,1,1,0,1,0,0,0,0,0,1,0,0,0,1,0,1,0,1,1,1,0,1},
    {1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,1,0,0,1,0,1,1,1,0,1},
    {1,0,1,1,1,0,1,0,0,1,0,1,0,0,1,0,1,0,1,0,1,1,1,0,1},
    {1,0,0,0,0,0,1,0,1,1,0,0,0,1,0,0,0,0,1,0,0,0,0,0,1},
    {1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1},
    {0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0},
    {1,1,1,1,1,0,1,1,1,1,0,0,0,1,1,1,0,1,0,1,0,1,0,1,0},
    {0,1,1,0,0,0,0,0,1,0,1,0,1,0,1,1,1,1,0,1,1,0,0,0,1},
    {0,0,1,0,0,1,1,0,1,0,1,1,0,1,0,1,0,1,1,0,1,0,1,0,0},
    {1,1,0,0,0,0,0,1,1,0,0,1,1,0,1,0,1,0,0,0,0,0,0,0,0},
    {0,0,1,1,1,0,1,0,0,1,1,0,1,0,1,1,0,1,1,1,1,1,0,1,1},
    {1,1,1,0,1,1,0,0,0,1,0,1,1,0,1,0,1,1,0,1,1,0,0,1,0},
    {1,0,0,0,1,0,1,1,0,1,1,0,0,1,0,0,0,1,1,0,1,0,1,0,0},
    {1,0,0,0,1,0,0,1,0,0,1,1,1,1,1,0,1,0,0,0,0,0,0,1,1},
    {1,0,1,1,0,0,1,1,0,1,0,0,0,0,0,1,1,1,1,1,1,1,0,0,1},
    {0,0,0,0,0,0,0,0,1,0,0,0,1,0,1,0,1,0,0,0,1,0,0,0,1},
    {1,1,1,1,1,1,1,0,1,1,0,1,0,1,0,1,1,0,1,0,1,0,1,1,1},
    {1,0,0,0,0,0,1,0,0,0,0,1,1,0,1,0,1,0,0,0,1,1,0,0,0},
    {1,0,1,1,1,0,1,0,1,1,0,0,0,1,1,1,1,1,1,1,1,1,0,0,0},
    {1,0,1,1,1,0,1,0,1,0,0,1,1,0,1,0,1,1,0,0,1,0,0,1,1},
    {1,0,1,1,1,0,1,0,1,0,0,0,1,1,0,0,0,1,0,0,1,0,1,0,1},
    {1,0,0,0,0,0,1,0,1,0,0,1,0,1,1,1,1,1,1,1,1,1,0,1,0},
    {1,1,1,1,1,1,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1}
}--]]
local qrCode = {
	{1,1,1,1,1,1,1,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,1,1,1,1,1,1,1},
	{1,0,0,0,0,0,1,0,1,0,0,1,1,0,0,1,0,1,0,0,1,0,1,0,0,0,0,0,1},
	{1,0,1,1,1,0,1,0,1,1,0,0,1,0,1,0,0,1,0,1,0,0,1,0,1,1,1,0,1},
	{1,0,1,1,1,0,1,0,1,1,1,0,0,0,1,1,0,0,0,0,1,0,1,0,1,1,1,0,1},
	{1,0,1,1,1,0,1,0,0,1,1,0,1,1,1,1,1,0,0,1,0,0,1,0,1,1,1,0,1},
	{1,0,0,0,0,0,1,0,1,1,1,0,1,0,0,0,1,1,0,1,1,0,1,0,0,0,0,0,1},
	{1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1},
	{0,0,0,0,0,0,0,0,0,0,1,1,0,1,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0},
	{1,1,0,0,1,1,1,0,0,0,1,0,0,1,1,0,1,1,0,1,0,0,0,1,0,1,1,1,1},
	{0,0,1,0,1,1,0,1,1,0,0,1,1,1,1,0,1,0,0,1,0,1,1,1,1,0,1,0,0},
	{0,0,1,1,0,0,1,1,1,1,1,1,0,1,0,0,1,0,1,1,0,1,1,0,1,1,1,0,1},
	{0,1,1,1,1,0,0,1,0,1,0,0,1,1,0,0,1,0,0,1,1,1,0,0,0,1,0,0,0},
	{0,0,1,1,0,0,1,0,1,0,0,0,0,1,0,0,0,0,0,1,1,1,1,1,0,1,1,1,0},
	{1,1,1,0,1,0,0,0,1,1,1,1,1,1,0,0,1,0,0,1,0,0,1,1,1,0,1,0,0},
	{0,0,0,1,0,0,1,1,1,0,0,1,1,1,1,1,1,0,0,0,0,0,1,0,1,1,1,1,0},
	{1,0,0,1,0,0,0,1,1,0,1,0,1,0,1,0,0,0,0,1,1,1,0,0,0,0,0,1,0},
	{1,0,0,0,1,0,1,0,0,0,1,0,1,0,1,0,0,1,0,1,1,1,0,1,0,1,1,1,0},
	{1,0,1,0,0,1,0,0,1,0,1,0,0,1,0,1,1,0,0,0,0,1,1,1,1,0,1,1,1},
	{0,0,0,1,1,0,1,0,0,1,0,1,1,1,1,0,1,0,1,1,0,0,1,0,1,1,1,0,0},
	{0,0,1,0,0,0,0,1,1,1,1,0,1,0,0,0,0,1,0,1,1,1,0,0,0,0,0,1,0},
	{1,1,1,0,0,1,1,0,1,1,0,0,0,1,1,0,1,1,0,1,1,1,1,1,1,0,0,0,0},
	{0,0,0,0,0,0,0,0,1,1,0,0,0,1,0,0,0,0,1,0,1,0,0,0,1,1,1,0,0},
	{1,1,1,1,1,1,1,0,0,1,1,1,0,1,1,1,1,0,0,0,1,0,1,0,1,1,1,0,1},
	{1,0,0,0,0,0,1,0,1,0,1,0,1,0,1,0,0,0,0,1,1,0,0,0,1,0,1,1,0},
	{1,0,1,1,1,0,1,0,1,1,1,0,0,0,0,0,0,1,0,1,1,1,1,1,1,1,0,0,1},
	{1,0,1,1,1,0,1,0,0,0,0,1,0,1,1,0,1,0,0,0,0,1,1,1,0,1,1,1,0},
	{1,0,1,1,1,0,1,0,0,1,0,1,0,1,1,1,0,0,1,1,0,0,0,0,1,0,1,1,1},
	{1,0,0,0,0,0,1,0,1,0,1,0,1,0,0,0,0,1,1,0,1,0,1,1,1,1,1,0,0},
	{1,1,1,1,1,1,1,0,1,1,0,0,0,1,1,0,1,1,1,0,1,0,1,0,1,0,0,1,0}
}






local function RenderQR()
    local container = NoMoreDMCAContainer
    local pixelSize = 14 -- Matches the XML Dimensions
    local spacing = 0   -- Space between blocks
    
    for rowIndex,row in ipairs(qrCode) do
        for colIndex,value in ipairs(row) do
            if value == 1 then
                -- Generate a unique name for each pixel
                local name = "NoMoreDMCA_QR_Pixel_" .. rowIndex .. "_" .. colIndex
                local pixel = CreateControlFromVirtual(name,container,"NoMoreDMCA_QR_Pixel_Template")
                
                -- Position the pixel based on its grid coordinates
                local offsetX = (colIndex - 1) * (pixelSize + spacing)
                local offsetY = (rowIndex - 1) * (pixelSize + spacing)
                
                pixel:SetAnchor(TOPLEFT,container,TOPLEFT,offsetX+25,offsetY+25)
            end
        end
    end
	QRCodeMade=true
end

local function hideQR()
	QRHidden = true
	NoMoreDMCAContainer:SetHidden(QRHidden)
	EVENT_MANAGER:UnregisterForUpdate(AddonName.."UpdateUI")	
end

local function UpdateUI()
	-- Check if Player has moved
	local x, y = GetMapPlayerPosition("player")
	if x ~= xLast or y ~= yLast then 
		hideQR() 
		return
	end	
	-- Update Countdown
	timer = timer - updateCycle	
	if timer <= 0 then
		 hideQR()
		 d('you can use "/dmcaqr" to see QRcode again.')
	else
		NoMoreDMCAContainerCountdownBGLabel:SetText("Moving will close QR Code\nThis will auto close in "..math.ceil(timer).." seconds")
	end	
end

local function showQR()
	-- Check if we have made the QR code yet
	if not QRCodeMade then RenderQR() end 
	NoMoreDMCAContainerDiscriptionBGLabel:SetText("Were you affected by the recent addon debacle?\nHelp us take down the bad actor filing fraudulent DMCA requests against addon developers")
	-- Show QR on Screen
	QRHidden = false
	NoMoreDMCAContainer:SetHidden(QRHidden)	
	-- Prep for UpdateUI
	xLast, yLast = GetMapPlayerPosition("player")
	timer = timerStart
	EVENT_MANAGER:RegisterForUpdate(AddonName.."UpdateUI", updateCycle*1000, UpdateUI)
	-- auto close after 59 seconds
	zo_callLater(function() hideQR() end,timer*1000)
end

local function OnAddonLoaded(event, name)
	if name ~= AddonName then return end
	EVENT_MANAGER:UnregisterForEvent(AddonName, EVENT_ADD_ON_LOADED)
	zo_callLater(function() showQR() end,1000)
	SLASH_COMMANDS["/dmcaqr"] = function()
		if QRHidden then
			showQR()
		else
			hideQR()
		end
	end
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_ADD_ON_LOADED, OnAddonLoaded)
