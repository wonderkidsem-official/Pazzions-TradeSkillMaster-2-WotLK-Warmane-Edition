-- ------------------------------------------------------------------------------ --
--                           TradeSkillMaster_AuctionDB                           --
--           http://www.curse.com/addons/wow/tradeskillmaster_auctiondb           --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

-- load the parent file (TSM) into a local variable and register this file as a module
local TSM = select(2, ...)
local GUI = TSM:NewModule("GUI")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_AuctionDB") -- loads the localization table
	
local private = {}

function GUI:Show(frame)
	private.statusBar = private.statusBar or private:CreateStatusBar(frame.content)
	private.statusBar:Show()
	GUI:UpdateStatus("", 0, 0)
	
	private.startScanContent = private.startScanContent or private:CreateStartScanContent(frame)
	private.startScanContent:Show()
end

function GUI:Hide()
	private.statusBar:Hide()
	private.startScanContent:Hide()
	
	TSM.Scan:DoneScanning()
	TSMAPI.AuctionScan:StopScan()
end

function GUI:UpdateStatus(text, major, minor)
	if text then
		private.statusBar:SetStatusText(text)
	end
	if major or minor then
		private.statusBar:UpdateStatus(major, minor)
	end
end

function private:CreateStatusBar(parent)
	local frame = TSMAPI.GUI:CreateStatusBar(parent, "TSMAuctionDBStatusBar")
	TSMAPI.GUI:CreateHorizontalLine(frame, -30, parent)
	
	return frame
end

function private:CreateStartScanContent(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame:Hide()

	local function UpdateGetAllButton()
		if TSM.Scan.isScanning then
			frame:Disable()
		elseif not select(2, CanSendAuctionQuery()) then
			local previous = TSM.db.profile.lastGetAll or time()
			if previous > (time() - 15*60) then
				local diff = previous + 15*60 - time()
				local diffMin = math.floor(diff/60)
				local diffSec = diff - diffMin*60
				frame.getAllStatusText:SetText("|cff990000"..format(L["Ready in %s min and %s sec"], diffMin, diffSec))
			else
				frame.getAllStatusText:SetText("|cff990000"..L["Not Ready"])
			end
			frame:Enable()
			frame.startGetAllButton:Disable()
		else
			frame:Enable()
			frame.getAllStatusText:SetText("|cff009900"..L["Ready"])
			frame.startGetAllButton:Enable()
		end
	end
	
	frame:SetScript("OnShow", function(self)
			TSMAPI:CreateTimeDelay("auctionDBGetAllStatus", 0, UpdateGetAllButton, 0.2)
		end)
	
	frame:SetScript("OnHide", function(self)
			TSMAPI:CancelFrame("auctionDBGetAllStatus")
		end)
		
	frame.Enable = function(self)
		if self.startMarketScanButton then self.startMarketScanButton:Enable() end
		self.startGetAllButton:Enable()
		self.startFullScanButton:Enable()
		self.startGroupScanButton:Enable()
	end

	frame.Disable = function(self)
		if self.startMarketScanButton then self.startMarketScanButton:Disable() end
		self.startGetAllButton:Disable()
		self.startFullScanButton:Disable()
		self.startGroupScanButton:Disable()
	end
	
	-- top row (auto updater)
	local text = TSMAPI.GUI:CreateLabel(frame)
	text:SetFont(TSMAPI.Design:GetContentFont(), 24)
	text:SetPoint("TOP", 0, -24)
	text:SetHeight(24)
	text:SetJustifyH("CENTER")
	text:SetJustifyV("CENTER")
	text:SetText(TSMAPI.Design:GetInlineColor("link").."TSM_AuctionDB")
	local ag = text:CreateAnimationGroup()
	local a1 = ag:CreateAnimation("Alpha")
	a1:SetChange(-.5)
	a1:SetDuration(.5)
	ag:SetLooping("BOUNCE")
	ag:Play()
	
	local content = CreateFrame("Frame", nil, frame)
	content:SetAllPoints(parent.content)
	TSMAPI.Design:SetFrameBackdropColor(content)
	
	-- group tree
	local container = CreateFrame("Frame", nil, content)
	container:SetPoint("TOPLEFT", 5, -35)
	container:SetPoint("BOTTOMRIGHT", -205, 5)
	TSMAPI.Design:SetFrameColor(container)
	frame.groupTree = TSMAPI:CreateGroupTree(container, nil, "AuctionDB")
	
	local bar = TSMAPI.GUI:CreateVerticalLine(content, 0)
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", -200, -30)
	bar:SetPoint("BOTTOMRIGHT", -200, 0)
	
	local buttonFrame = CreateFrame("Frame", nil, content)
	buttonFrame:SetPoint("TOPLEFT", content, "TOPRIGHT", -200, 0)
	buttonFrame:SetPoint("BOTTOMRIGHT")
	
	-- row 1 (fast market scan - warmane optimized)
	local btn = TSMAPI.GUI:CreateButton(buttonFrame, 15)
	btn:SetPoint("TOPLEFT", 6, -38)
	btn:SetPoint("TOPRIGHT", -6, -38)
	btn:SetHeight(26)
	btn:SetScript("OnClick", TSM.Scan.StartMarketScan)
	btn:SetText("|cff00ff00" .. L["Fast Market Scan"] .. "|r")
	btn.tooltip = "Warmane-Optimized: Scans all Trade Goods, Consumables, Gems, and Glyphs safely page-by-page. Takes ~60-90 seconds, 0% disconnect risk!"
	frame.startMarketScanButton = btn
	
	local text = TSMAPI.GUI:CreateLabel(buttonFrame)
	text:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
	text:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -2)
	text:SetHeight(14)
	text:SetJustifyH("CENTER")
	text:SetJustifyV("CENTER")
	text:SetText("|cff88ff88All Mats & Crafts (~1m)|r")
	
	TSMAPI.GUI:CreateHorizontalLine(buttonFrame, -84)
	
	-- row 2 (getall scan)
	local btn = TSMAPI.GUI:CreateButton(buttonFrame, 15)
	btn:SetPoint("TOPLEFT", 6, -96)
	btn:SetPoint("TOPRIGHT", -6, -96)
	btn:SetHeight(24)
	btn:SetScript("OnClick", TSM.Scan.StartGetAllScan)
	btn:SetText(L["Run GetAll Scan"])
	btn.tooltip = L["A GetAll scan is the fastest in-game method for scanning every item on the auction house. However, there are many possible bugs on Blizzard's end with it including the chance for it to disconnect you from the game. Also, it has a 15 minute cooldown."]
	frame.startGetAllButton = btn
	
	local text = TSMAPI.GUI:CreateLabel(buttonFrame)
	text:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
	text:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -2)
	text:SetHeight(14)
	text:SetJustifyH("CENTER")
	text:SetJustifyV("CENTER")
	frame.getAllStatusText = text
	
	TSMAPI.GUI:CreateHorizontalLine(buttonFrame, -145)
	
	-- row 3 (full scan)
	local btn = TSMAPI.GUI:CreateButton(buttonFrame, 15)
	btn:SetPoint("TOPLEFT", 6, -158)
	btn:SetPoint("TOPRIGHT", -6, -158)
	btn:SetHeight(24)
	btn:SetScript("OnClick", TSM.Scan.StartFullScan)
	btn:SetText(L["Run Full Scan"])
	btn.tooltip = L["A full auction house scan will scan every item on the auction house but is far slower than a GetAll scan. Expect this scan to take several minutes or longer."]
	frame.startFullScanButton = btn
	
	TSMAPI.GUI:CreateHorizontalLine(buttonFrame, -200)
	
	-- row 4 (group scan)
	local btn = TSMAPI.GUI:CreateButton(buttonFrame, 15)
	btn:SetPoint("TOPLEFT", 6, -215)
	btn:SetPoint("TOPRIGHT", -6, -215)
	btn:SetHeight(24)
	btn:SetScript("OnClick", GUI.StartGroupScan)
	btn:SetText("|cff00ff00" .. L["Scan Selected Groups"] .. "|r")
	btn.tooltip = "Warmane-Optimized Smart Group Scan: Automatically detects categories for selected items and scans them in ~1-2 minutes with 0% disconnect risk!"
	frame.startGroupScanButton = btn
	
	return frame
end

function GUI:StartGroupScan()
	local items = {}
	for groupName, data in pairs(private.startScanContent.groupTree:GetSelectedGroupInfo()) do
		groupName = TSMAPI:FormatGroupPath(groupName, true)
		for itemString in pairs(data.items) do
			tinsert(items, itemString)
		end
	end
	if #items == 0 then
		TSM:Print(L["No groups selected for scanning."])
		return
	end
	TSM.Scan:StartGroupScan(items)
end