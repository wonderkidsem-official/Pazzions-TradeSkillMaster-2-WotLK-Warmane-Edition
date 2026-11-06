local TSM = select(2, ...)
local Sidebar = TSM:NewModule("Sidebar", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Shopping") -- loads the localization table

local private = {pages={}, order={}, createFunctions={}, updateFunctions={}, currentPage=nil}


function Sidebar:Show(parent)
	private.frame = private.frame or private:CreateSidebar(parent)
	private.frame:Show()
end

function Sidebar:Hide()
	if not private.frame then return end
	private.frame:Hide()
end

local function GetOrCreatePage(label)
	if not private.frame or not private.frame.content then return end
	if not private.frame.content[label] and private.createFunctions[label] then
		private.frame.content[label] = private.createFunctions[label](private.frame.content)
		private.frame.content[label]:Hide()
	end
	return private.frame.content[label]
end

function private:CreateSidebar(parent)
	TSM.Util:ShowSearchFrame(nil, L["% Market Value"])
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
	frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)
	frame:SetWidth(300)
	TSMAPI.Design:SetFrameBackdropColor(frame)
	
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 5, -5)
	content:SetPoint("BOTTOMRIGHT", -5, 5)
	frame.content = content
	
	private.frame = frame
	private.currentPage = private.currentPage or private.order[1]
	local activePage = GetOrCreatePage(private.currentPage)
	if activePage then
		activePage:Show()
	end
	
	return frame
end

function Sidebar:AddSidebarFeature(label, createFunc, updateFunc)
	private.pages[label] = label
	private.createFunctions[label] = createFunc
	private.updateFunctions[label] = updateFunc
	tinsert(private.order, label)
end

function Sidebar:UpdateCurrentFrame()
	if private.currentPage and private.updateFunctions[private.currentPage] then
		private.updateFunctions[private.currentPage]()
	end
end

function Sidebar:GetPages()
	return private.order
end

function Sidebar:ButtonClick(key)
	for i in pairs(private.pages) do
		if private.frame.content[i] then
			private.frame.content[i]:Hide()
		end
	end
	local page = GetOrCreatePage(key)
	if page then
		page:Show()
	end
	private.currentPage = key
end

function Sidebar:GetCurrentPage()
	if not private.frame or not private.frame:IsVisible() then return end
	
	if private.currentPage == L["Saved Searches"] then	
		return "saved"
	elseif private.currentPage == L["TSM Groups"] then	
		return "groups"
	elseif private.currentPage == L["Log"] then	
		return "log"
	elseif private.currentPage == L["Quick Posting"] then	
		return "quick"
	elseif private.currentPage == L["Custom Filter"] then	
		return "custom"
	elseif private.currentPage == OTHER then	
		return "other"
	end
end