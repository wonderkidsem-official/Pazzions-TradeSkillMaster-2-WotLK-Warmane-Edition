-- ------------------------------------------------------------------------------ --
--                           TradeSkillMaster_AuctionDB                           --
--           http://www.curse.com/addons/wow/tradeskillmaster_auctiondb           --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

-- load the parent file (TSM) into a local variable and register this file as a module
local TSM = select(2, ...)
local Scan = TSM:NewModule("Scan", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_AuctionDB") -- loads the localization table

Scan.groupScanData = {}
Scan.filterList = {}
Scan.numFilters = 0

local function NewRecordTable()
	return {prices={}, total=0, weighted=true}
end

local function AddWeightedRecord(records, itemBuyout, count)
	if not itemBuyout or itemBuyout <= 0 or not count or count <= 0 then return end
	if not records[itemBuyout] then
		tinsert(records.prices, itemBuyout)
		records[itemBuyout] = count
	else
		records[itemBuyout] = records[itemBuyout] + count
	end
	records.total = records.total + count
end

local ITEM_CLASS_LOOKUP = nil
local function GetItemClassLookup()
	if ITEM_CLASS_LOOKUP then return ITEM_CLASS_LOOKUP end
	local classes = { GetAuctionItemClasses() }
	if #classes == 0 then return {} end
	ITEM_CLASS_LOOKUP = {}
	for i, className in ipairs(classes) do
		ITEM_CLASS_LOOKUP[className] = { index = i, name = className, subClasses = {} }
		for j, subClassName in ipairs({ GetAuctionItemSubClasses(i) }) do
			ITEM_CLASS_LOOKUP[className].subClasses[subClassName] = { index = j, name = subClassName }
		end
	end
	return ITEM_CLASS_LOOKUP
end

local function GetCraftingSupplementalItems(scanTime)
	if not TSMAPI.GetModuleItems then return end
	local moduleItems = TSMAPI:GetModuleItems("Crafting")
	if type(moduleItems) ~= "table" then return end

	local items, seen = {}, {}
	for itemString in pairs(moduleItems) do
		local baseItemString = TSMAPI:GetBaseItemString(itemString) or itemString
		local itemID = TSMAPI:GetItemID(baseItemString)
		if itemID and not seen[baseItemString] then
			local itemData = TSM.data[itemID]
			if itemData then
				TSM:DecodeItemData(itemID)
			end
			if not itemData or itemData.lastScan ~= scanTime then
				tinsert(items, baseItemString)
				seen[baseItemString] = true
			end
		end
	end

	return items
end

function Scan:StartCraftingSupplementalScan()
	local items = Scan.craftingSupplementalItems
	Scan.craftingSupplementalItems = nil
	if not items or #items == 0 then return end

	if Scan.isScanning then
		Scan.craftingSupplementalItems = items
		return TSMAPI:CreateTimeDelay("auctionDBCraftingSupplementalScan", 1, function() Scan:StartCraftingSupplementalScan() end)
	end
	if not AuctionFrame or not AuctionFrame:IsVisible() then
		TSM:Print(format("Skipped supplemental Crafting scan for %d items because the Auction House was closed.", #items))
		return
	end

	TSM:Print(format("GetAll missed %d Crafting items. Running exact supplemental scans.", #items))
	Scan:StartSupplementalExactScan(items)
end

local function GetSupplementalQuery(itemString)
	local name = TSMAPI:GetSafeItemInfo(itemString)
	if name then
		return {name=name}
	end
	return TSMAPI:GetAuctionQueryInfo(itemString)
end

local function SupplementalScanCallback(event, ...)
	if event == "SCAN_PAGE_UPDATE" then
		local page, total = ...
		local queue = Scan.supplementalQueue or {}
		TSM.GUI:UpdateStatus(format("Supplemental Crafting scan %d / %d (Page %d / %d)", Scan.supplementalIndex or 0, #queue, page, total))
	elseif event == "SCAN_COMPLETE" then
		local data = ...
		local itemString = Scan.supplementalCurrentItem
		local itemID = itemString and TSMAPI:GetItemID(itemString)
		local obj = type(data) == "table" and itemString and data[itemString]
		if not obj and itemID and type(data) == "table" then
			for dataItemString, dataObj in pairs(data) do
				if TSMAPI:GetItemID(dataItemString) == itemID and TSMAPI:GetBaseItemString(dataItemString) == dataItemString then
					obj = dataObj
					break
				end
			end
		end
		if obj and itemString then
			Scan.supplementalData[itemString] = obj
		end
		Scan:ScanNextSupplementalItem()
	elseif event == "SCAN_TIMEOUT" then
		Scan:ScanNextSupplementalItem()
	elseif event == "INTERRUPTED" or event == "SCAN_INTERRUPTED" then
		Scan:DoneScanning()
	end
end

function Scan:StartSupplementalExactScan(items)
	Scan.isScanning = "Group"
	Scan.isBuggedGetAll = nil
	Scan.groupItems = {}
	Scan.supplementalQueue = {}
	Scan.supplementalData = {}
	Scan.supplementalIndex = 0

	for _, itemString in ipairs(items) do
		local baseItemString = TSMAPI:GetBaseItemString(itemString) or itemString
		if TSMAPI:GetItemID(baseItemString) and not Scan.groupItems[baseItemString] then
			Scan.groupItems[baseItemString] = true
			tinsert(Scan.supplementalQueue, baseItemString)
		end
	end

	if #Scan.supplementalQueue == 0 then
		Scan:DoneScanning()
		return
	end

	TSMAPI.AuctionScan:StopScan()
	Scan:ScanNextSupplementalItem()
end

function Scan:ScanNextSupplementalItem()
	local queue = Scan.supplementalQueue
	if not queue then return end

	Scan.supplementalIndex = (Scan.supplementalIndex or 0) + 1
	local itemString = queue[Scan.supplementalIndex]
	if not itemString then
		local data = Scan.supplementalData or {}
		local totalItems = #queue
		local updatedItems = 0
		for _ in pairs(data) do
			updatedItems = updatedItems + 1
		end
		Scan.supplementalQueue = nil
		Scan.supplementalData = nil
		Scan.supplementalCurrentItem = nil
		Scan.supplementalIndex = nil
		TSM:Print(format("Supplemental Crafting scan found auction data for %d / %d missed items. Processing data...", updatedItems, totalItems))
		Scan:ProcessScanData(data)
		TSM.GUI:UpdateStatus(L["Processing data..."])
		TSMAPI:CreateTimeDelay("auctionDBSupplementalProcessDelay", 0.2, function()
			if TSM.processingData then return end
			TSMAPI:CancelFrame("auctionDBSupplementalProcessDelay")
			Scan:DoneScanning()
		end, 0.2)
		return
	end

	Scan.supplementalCurrentItem = itemString
	local query = GetSupplementalQuery(itemString)
	if not query then
		Scan:ScanNextSupplementalItem()
		return
	end

	TSM.GUI:UpdateStatus(format("Supplemental Crafting scan %d / %d", Scan.supplementalIndex, #queue))
	local result = TSMAPI.AuctionScan:RunQuery(query, SupplementalScanCallback)
	if result and result < 0 then
		Scan:ScanNextSupplementalItem()
	end
end


-- ============================================================================
-- Fast Market Scan (Warmane-Optimized Category-Based Scan)
-- Scans Trade Goods (6), Consumables (4), Gems (10), Glyphs (5) safely page-by-page.
-- Takes ~60-90 seconds total, 0% disconnect risk on high-pop realms.
-- ============================================================================

local MARKET_CATEGORIES = {
	{ class = 6, name = "Trade Goods" },
	{ class = 4, name = "Consumables" },
	{ class = 10, name = "Gems" },
	{ class = 5, name = "Glyphs" },
}

function Scan:StartMarketScan()
	if not AuctionFrame or not AuctionFrame:IsVisible() then
		TSM:Print(L["Auction House must be open to scan."])
		return
	end

	Scan.isScanning = "Market"
	Scan.isBuggedGetAll = nil
	Scan.groupItems = nil
	TSMAPI.AuctionScan:StopScan()

	Scan.marketScan = {
		catIndex = 1,
		page = 0,
		totalPages = nil,
		data = {},
		itemCount = 0,
		retries = 0,
	}

	TSM.GUI:UpdateStatus("Preparing Fast Market Scan...", 0)
	Scan:SendMarketPageQuery()
end

function Scan:SendMarketPageQuery()
	if Scan.isScanning ~= "Market" or not Scan.marketScan then return end

	if not AuctionFrame or not AuctionFrame:IsVisible() then
		TSM:Print(L["Market scan cancelled: Auction House was closed."])
		Scan:DoneScanning()
		return
	end

	if not CanSendAuctionQuery() then
		TSMAPI:CreateTimeDelay("marketScanQueryDelay", 0.08, function()
			Scan:SendMarketPageQuery()
		end)
		return
	end

	TSMAPI:CancelFrame("marketScanQueryDelay")
	TSMAPI:CancelFrame("marketScanRetry")

	-- 6 second watchdog timeout
	TSMAPI:CreateTimeDelay("marketScanWatchdog", 6.0, function()
		Scan:OnMarketScanTimeout()
	end)

	local cat = MARKET_CATEGORIES[Scan.marketScan.catIndex]
	Scan:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", "OnMarketScanPageLoaded")
	QueryAuctionItems("", nil, nil, nil, cat.class, nil, Scan.marketScan.page, nil, nil)
end

function Scan:OnMarketScanPageLoaded()
	Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
	TSMAPI:CancelFrame("marketScanWatchdog")

	if Scan.isScanning ~= "Market" or not Scan.marketScan then return end

	local numBatch, totalAuctions = GetNumAuctionItems("list")
	local cat = MARKET_CATEGORIES[Scan.marketScan.catIndex]

	if not totalAuctions or totalAuctions == 0 or not numBatch or numBatch == 0 then
		if Scan.marketScan.retries < 2 then
			Scan.marketScan.retries = Scan.marketScan.retries + 1
			TSMAPI:CreateTimeDelay("marketScanRetry", 0.4, function()
				Scan:SendMarketPageQuery()
			end)
			return
		else
			-- Category is empty or done, advance to next category
			Scan.marketScan.retries = 0
			Scan.marketScan.catIndex = Scan.marketScan.catIndex + 1
			if Scan.marketScan.catIndex > #MARKET_CATEGORIES then
				Scan:FinishMarketScan()
				return
			else
				Scan.marketScan.page = 0
				Scan.marketScan.totalPages = nil
				TSMAPI:CreateTimeDelay("marketScanNext", 0.1, function()
					Scan:SendMarketPageQuery()
				end)
				return
			end
		end
	end

	Scan.marketScan.retries = 0
	local itemsPerPage = NUM_AUCTION_ITEMS_PER_PAGE or 50
	local totalPages = ceil(totalAuctions / itemsPerPage)
	Scan.marketScan.totalPages = totalPages

	local pageData = Scan.marketScan.data
	for i = 1, numBatch do
		local link = GetAuctionItemLink("list", i)
		local itemID = link and TSMAPI:GetItemID(link)
		local _, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
		if itemID and count and count > 0 and buyout and buyout > 0 then
			local itemData = pageData[itemID]
			if not itemData then
				itemData = {records = NewRecordTable(), minBuyout = math.huge, quantity = 0}
				pageData[itemID] = itemData
			end
			local itemBuyout = floor(buyout / count)
			itemData.minBuyout = min(itemData.minBuyout, itemBuyout)
			itemData.quantity = itemData.quantity + count
			AddWeightedRecord(itemData.records, itemBuyout, count)
			Scan.marketScan.itemCount = Scan.marketScan.itemCount + count
		end
	end

	local curPage = Scan.marketScan.page + 1
	local catNum = Scan.marketScan.catIndex
	local catTotal = #MARKET_CATEGORIES
	local pct = min(floor(((catNum - 1) * 100 + (curPage * 100 / totalPages)) / catTotal), 100)
	TSM.GUI:UpdateStatus(format("Market [%s]: %d/%d (%d%%) - %d items", cat.name, curPage, totalPages, pct, Scan.marketScan.itemCount), pct)

	if curPage % 20 == 0 then
		collectgarbage("step", 20)
	end

	if curPage >= totalPages then
		-- This category is finished! Move to next category
		Scan.marketScan.catIndex = Scan.marketScan.catIndex + 1
		if Scan.marketScan.catIndex > #MARKET_CATEGORIES then
			Scan:FinishMarketScan()
			return
		else
			Scan.marketScan.page = 0
			Scan.marketScan.totalPages = nil
			Scan.marketScan.retries = 0
			TSMAPI:CreateTimeDelay("marketScanNext", 0.1, function()
				Scan:SendMarketPageQuery()
			end)
			return
		end
	end

	Scan.marketScan.page = curPage
	TSMAPI:CreateTimeDelay("marketScanNext", 0.05, function()
		Scan:SendMarketPageQuery()
	end)
end

function Scan:OnMarketScanTimeout()
	Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
	if Scan.isScanning ~= "Market" or not Scan.marketScan then return end

	Scan.marketScan.retries = (Scan.marketScan.retries or 0) + 1
	if Scan.marketScan.retries <= 2 then
		local cat = MARKET_CATEGORIES[Scan.marketScan.catIndex]
		TSM:Print(format("Page %d of %s timed out, retrying (%d/2)...", Scan.marketScan.page + 1, cat and cat.name or "", Scan.marketScan.retries))
		TSMAPI:CreateTimeDelay("marketScanRetry", 0.5, function()
			Scan:SendMarketPageQuery()
		end)
	else
		-- Skip page or advance
		Scan.marketScan.retries = 0
		Scan.marketScan.page = Scan.marketScan.page + 1
		if Scan.marketScan.totalPages and Scan.marketScan.page >= Scan.marketScan.totalPages then
			Scan.marketScan.catIndex = Scan.marketScan.catIndex + 1
			if Scan.marketScan.catIndex > #MARKET_CATEGORIES then
				Scan:FinishMarketScan()
				return
			else
				Scan.marketScan.page = 0
				Scan.marketScan.totalPages = nil
			end
		end
		TSMAPI:CreateTimeDelay("marketScanNext", 0.05, function()
			Scan:SendMarketPageQuery()
		end)
	end
end

function Scan:FinishMarketScan()
	local totalItems = Scan.marketScan and Scan.marketScan.itemCount or 0
	TSM:Print(format("Fast Market Scan complete! %d items scanned across all profession categories.", totalItems))
	TSM.db.factionrealm.lastCompleteScan = time()
	local finalData = Scan.marketScan and Scan.marketScan.data or {}
	Scan.marketScan = nil
	Scan:DoneScanning()
	TSM.Data:ProcessData(finalData)
end


function Scan:StartFullScan()
	if not AuctionFrame or not AuctionFrame:IsVisible() then
		TSM:Print(L["Auction House must be open to scan."])
		return
	end

	Scan.isScanning = "Full"
	Scan.isBuggedGetAll = nil
	Scan.groupItems = nil
	TSMAPI.AuctionScan:StopScan()

	Scan.safeScan = {
		page = 0,
		totalPages = nil,
		data = {},
		itemCount = 0,
		retries = 0,
	}

	TSM.GUI:UpdateStatus("Preparing Full Scan...", 0)
	Scan:SendSafePageQuery()
end

function Scan:SendSafePageQuery()
	if Scan.isScanning ~= "Full" or not Scan.safeScan then return end

	if not AuctionFrame or not AuctionFrame:IsVisible() then
		TSM:Print(L["Full scan cancelled: Auction House was closed."])
		Scan:DoneScanning()
		return
	end

	if not CanSendAuctionQuery() then
		TSMAPI:CreateTimeDelay("safeFullScanQueryDelay", 0.08, function()
			Scan:SendSafePageQuery()
		end)
		return
	end

	TSMAPI:CancelFrame("safeFullScanQueryDelay")
	TSMAPI:CancelFrame("safeFullScanRetry")

	-- 6 second watchdog timeout
	TSMAPI:CreateTimeDelay("safeFullScanWatchdog", 6.0, function()
		Scan:OnSafeScanTimeout()
	end)

	Scan:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", "OnSafeScanPageLoaded")
	QueryAuctionItems("", nil, nil, nil, nil, nil, Scan.safeScan.page, nil, nil)
end

function Scan:OnSafeScanPageLoaded()
	Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
	TSMAPI:CancelFrame("safeFullScanWatchdog")

	if Scan.isScanning ~= "Full" or not Scan.safeScan then return end

	local numBatch, totalAuctions = GetNumAuctionItems("list")
	if not totalAuctions or totalAuctions == 0 or not numBatch or numBatch == 0 then
		if Scan.safeScan.retries < 3 then
			Scan.safeScan.retries = Scan.safeScan.retries + 1
			TSMAPI:CreateTimeDelay("safeFullScanRetry", 0.5, function()
				Scan:SendSafePageQuery()
			end)
			return
		else
			TSM:Print(L["Full scan completed: No auction items found."])
			Scan:DoneScanning()
			return
		end
	end

	Scan.safeScan.retries = 0
	local itemsPerPage = NUM_AUCTION_ITEMS_PER_PAGE or 50
	local totalPages = ceil(totalAuctions / itemsPerPage)
	Scan.safeScan.totalPages = totalPages

	local pageData = Scan.safeScan.data
	for i = 1, numBatch do
		local link = GetAuctionItemLink("list", i)
		local itemID = link and TSMAPI:GetItemID(link)
		local _, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
		if itemID and count and count > 0 and buyout and buyout > 0 then
			local itemData = pageData[itemID]
			if not itemData then
				itemData = {records = NewRecordTable(), minBuyout = math.huge, quantity = 0}
				pageData[itemID] = itemData
			end
			local itemBuyout = floor(buyout / count)
			itemData.minBuyout = min(itemData.minBuyout, itemBuyout)
			itemData.quantity = itemData.quantity + count
			AddWeightedRecord(itemData.records, itemBuyout, count)
			Scan.safeScan.itemCount = Scan.safeScan.itemCount + count
		end
	end

	local curPage = Scan.safeScan.page + 1
	local pct = min(floor(curPage * 100 / totalPages), 100)
	TSM.GUI:UpdateStatus(format("Full Scan: Page %d / %d (%d%%) - %d items", curPage, totalPages, pct, Scan.safeScan.itemCount), pct)

	if curPage % 25 == 0 then
		collectgarbage("step", 20)
	end

	if curPage >= totalPages then
		TSM:Print(format(L["Full Scan complete! %d items scanned across %d pages."], Scan.safeScan.itemCount, totalPages))
		TSM.db.factionrealm.lastCompleteScan = time()
		local finalData = Scan.safeScan.data
		Scan.safeScan = nil
		Scan:DoneScanning()
		TSM.Data:ProcessData(finalData)
		return
	end

	Scan.safeScan.page = curPage
	TSMAPI:CreateTimeDelay("safeFullScanNext", 0.05, function()
		Scan:SendSafePageQuery()
	end)
end

function Scan:OnSafeScanTimeout()
	Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
	if Scan.isScanning ~= "Full" or not Scan.safeScan then return end

	Scan.safeScan.retries = (Scan.safeScan.retries or 0) + 1
	if Scan.safeScan.retries <= 3 then
		TSM:Print(format("Page %d timed out, retrying (%d/3)...", Scan.safeScan.page + 1, Scan.safeScan.retries))
		TSMAPI:CreateTimeDelay("safeFullScanRetry", 0.5, function()
			Scan:SendSafePageQuery()
		end)
	else
		TSM:Print(format("Skipping page %d...", Scan.safeScan.page + 1))
		Scan.safeScan.retries = 0
		Scan.safeScan.page = Scan.safeScan.page + 1
		if Scan.safeScan.totalPages and Scan.safeScan.page >= Scan.safeScan.totalPages then
			TSM:Print(format(L["Full Scan complete! %d items scanned."], Scan.safeScan.itemCount))
			TSM.db.factionrealm.lastCompleteScan = time()
			local finalData = Scan.safeScan.data
			Scan.safeScan = nil
			Scan:DoneScanning()
			TSM.Data:ProcessData(finalData)
		else
			Scan:SendSafePageQuery()
		end
	end
end

function Scan.ProcessGetAllScan(self)
	-- Wait for all chunks to finish downloading from the server
	while true do
		self:Sleep(0.2)
		if not Scan.isScanning or Scan.isScanning ~= "GetAll" then return end
		if Scan.getAllLoaded then
			break
		end
	end

	local data = {}
	local linkCache = {}
	collectgarbage("collect")
	local totalLoaded = Scan.getAllLoaded
	local numAuctions = GetNumAuctionItems("list") or totalLoaded
	local maxItems = min(totalLoaded, numAuctions)
	local statusFormat = "GetAll: %d / %d (%d%%)"

	for i = 1, maxItems do
		if i % 1000 == 0 or i == maxItems then
			local pct = floor(i * 100 / maxItems)
			TSM.GUI:UpdateStatus(format(statusFormat, i, maxItems, pct), pct)
			if i % 5000 == 0 then
				collectgarbage("step", 20)
			end
			self:Yield(true)
		end

		local link = GetAuctionItemLink("list", i)
		if link then
			local itemID = linkCache[link]
			if not itemID then
				local idStr = strmatch(link, "item:(%d+)")
				itemID = idStr and tonumber(idStr)
				linkCache[link] = itemID or false
			end

			if itemID then
				local _, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
				if count and count > 0 and buyout and buyout > 0 then
					local itemData = data[itemID]
					if not itemData then
						itemData = {records = NewRecordTable(), minBuyout = math.huge, quantity = 0}
						data[itemID] = itemData
					end
					local itemBuyout = floor(buyout / count)
					if itemBuyout < itemData.minBuyout then
						itemData.minBuyout = itemBuyout
					end
					itemData.quantity = itemData.quantity + count
					AddWeightedRecord(itemData.records, itemBuyout, count)
				end
			end
		end
	end

	wipe(linkCache)
	linkCache = nil

	TSM.db.factionrealm.lastCompleteScan = time()
	TSM.Data:ProcessData(data)

	TSM.GUI:UpdateStatus(L["Processing data..."])
	while TSM.processingData do
		self:Sleep(0.2)
	end
	data = nil
	collectgarbage("collect")

	TSM:Print(L["It is strongly recommended that you reload your ui (type '/reload') after running a GetAll scan. Otherwise, any other scans (Post/Cancel/Search/etc) will be much slower than normal."])
end

local lastDownloadUIUpdate = 0
local lastChunkTime = 0

function Scan:AUCTION_ITEM_LIST_UPDATE()
	if Scan.isScanning ~= "GetAll" then return end

	local num, total = GetNumAuctionItems("list")
	if not num or num == 0 then return end

	lastChunkTime = GetTime()

	-- Throttled UI update (at most once every 0.3s) to prevent main thread freezing and TCP socket buffer choking
	local now = GetTime()
	if (now - lastDownloadUIUpdate > 0.3) or (total and total > 0 and num >= total) then
		lastDownloadUIUpdate = now
		if total and total > 0 then
			local pct = min(floor(num * 100 / total), 100)
			TSM.GUI:UpdateStatus(format("Downloading: %d / %d (%d%%)", num, total, pct), pct)
		else
			TSM.GUI:UpdateStatus(format("Downloading: %d items...", num))
		end
	end

	-- Full download complete (all chunks received)
	if total and total > 0 and num >= total then
		TSMAPI:CancelFrame("getAllStallWatcher")
		TSMAPI:CancelFrame("getAllTimeout")
		Scan.stallWatcherRunning = nil
		Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
		TSM.GUI:UpdateStatus(format("Downloaded: %d items. Processing...", num), 100)
		Scan.getAllLoaded = num
		return
	end

	-- Start repeating watchdog once to check for completion if total count was unknown or chunk streaming stopped
	if not Scan.stallWatcherRunning then
		Scan.stallWatcherRunning = true
		TSMAPI:CreateTimeDelay("getAllStallWatcher", 1.0, function()
			if Scan.isScanning ~= "GetAll" then
				Scan.stallWatcherRunning = nil
				TSMAPI:CancelFrame("getAllStallWatcher")
				return
			end
			-- If no new chunks arrived in the last 8 seconds and we have auction data, finish downloading
			if (GetTime() - lastChunkTime) > 8.0 then
				local finalNum = GetNumAuctionItems("list")
				if finalNum and finalNum > 0 then
					Scan.stallWatcherRunning = nil
					TSMAPI:CancelFrame("getAllStallWatcher")
					TSMAPI:CancelFrame("getAllTimeout")
					Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
					TSM.GUI:UpdateStatus(format("Downloaded: %d items. Processing...", finalNum), 100)
					Scan.getAllLoaded = finalNum
				end
			end
		end, 1.0)
	end
end

function Scan:GetAllScanQuery()
	local canScan, canGetAll = CanSendAuctionQuery()
	if not canGetAll then return TSM:Print(L["Can't run a GetAll scan right now."]) end
	if not canScan then return TSMAPI:CreateTimeDelay(0.5, Scan.GetAllScanQuery) end

	TSM.GUI:UpdateStatus(L["Running query..."], 0)
	lastChunkTime = GetTime()
	lastDownloadUIUpdate = 0
	Scan.stallWatcherRunning = nil

	-- Temporarily unregister Auctionator's core handler to avoid freezing client thread during massive stream
	if Atr_core and Atr_core.UnregisterEvent then
		Atr_core:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
		Scan.unregisteredAtrCore = true
	end

	QueryAuctionItems("", nil, nil, 0, 0, 0, 0, false, -1, true)
	Scan:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

	-- 120 second overall timeout (fallback)
	TSMAPI:CreateTimeDelay("getAllTimeout", 120.0, function()
		if Scan.isScanning == "GetAll" and not Scan.getAllLoaded then
			Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
			TSMAPI:CancelFrame("getAllStallWatcher")
			Scan.stallWatcherRunning = nil
			TSM:Print("GetAll scan did not run successfully.")
			Scan:DoneScanning()
		end
	end)

	TSMAPI.Threading:Start(Scan.ProcessGetAllScan, 1, function() Scan:DoneScanning() end)
end

local function GroupScanCallback(event, ...)
	if event == "QUERY_COMPLETE" then
		local filterList = ...
		local numItems = 0
		for _, v in ipairs(filterList) do
			numItems = numItems + #v.items
		end
		Scan.filterList = filterList
		Scan.numFilters = #filterList
		Scan:ScanNextGroupFilter()
	elseif event == "QUERY_UPDATE" then
		local current, total = ...
		TSM.GUI:UpdateStatus(format(L["Preparing Filter %d / %d"], current, total))
	elseif event == "SCAN_INTERRUPTED" then
		Scan:DoneScanning()
	elseif event == "SCAN_TIMEOUT" then
		tremove(Scan.filterList, 1)
		Scan:ScanNextGroupFilter()
	elseif event == "SCAN_PAGE_UPDATE" then
		local page, total = ...
		TSM.GUI:UpdateStatus(format(L["Scanning %d / %d (Page %d / %d)"], Scan.numFilters-#Scan.filterList, Scan.numFilters, page+1, total), nil, page*100/total)
	elseif event == "SCAN_COMPLETE" then
		local data = ...
		for _, itemString in ipairs(Scan.filterList[1].items) do
			if not Scan.groupScanData[itemString] then
				Scan.groupScanData[itemString] = data[itemString]
			end
		end
		tremove(Scan.filterList, 1)
		Scan:ScanNextGroupFilter()
	end
end

function Scan:ScanNextGroupFilter(data)
	if #Scan.filterList == 0 then
		Scan:ProcessScanData(Scan.groupScanData)
		Scan:DoneScanning()
		return
	end
	TSM.GUI:UpdateStatus(format(L["Scanning %d / %d (Page %d / %d)"], Scan.numFilters-#Scan.filterList, Scan.numFilters, 1, 1), (Scan.numFilters-#Scan.filterList)*100/Scan.numFilters)
	TSMAPI.AuctionScan:RunQuery(Scan.filterList[1], GroupScanCallback)
end

-- ============================================================================
-- Exact Item Group Scan (Warmane-Optimized Fast Targeted Search)
-- Queries each item in the selected groups by its EXACT NAME.
-- Only pulls the pages for the items you actually have in your groups!
-- Takes ~2-4 minutes for 150 items, or ~30s for small groups. 0% disconnect!
-- ============================================================================

function Scan:StartGroupScan(items)
	if not AuctionFrame or not AuctionFrame:IsVisible() then
		TSM:Print(L["Auction House must be open to scan."])
		return
	end

	if not items or #items == 0 then
		TSM:Print(L["No items found in selected groups."])
		return
	end

	-- Check if items are in local cache; if not, wait 0.4s for cache fill
	local coldCount = 0
	for _, itemString in ipairs(items) do
		if not TSMAPI:GetSafeItemInfo(itemString) then
			coldCount = coldCount + 1
		end
	end
	if coldCount > 0 and not Scan._groupColdRetried then
		Scan._groupColdRetried = true
		TSM.GUI:UpdateStatus(format("Caching item data (%d pending)...", coldCount), 0)
		TSMAPI:CreateTimeDelay("groupScanColdDelay", 0.4, function()
			Scan:StartGroupScan(items)
		end)
		return
	end
	Scan._groupColdRetried = nil

	Scan.isScanning = "Group"
	Scan.isBuggedGetAll = nil
	Scan.groupItems = {}

	local targets = {}
	local seenNames = {}

	for _, itemString in ipairs(items) do
		Scan.groupItems[itemString] = true
		local itemID = TSMAPI:GetItemID(itemString)
		if itemID then
			Scan.groupItems[itemID] = true
		end
		local name = TSMAPI:GetSafeItemInfo(itemString)
		if name and name ~= "" and not seenNames[name] then
			seenNames[name] = true
			tinsert(targets, {
				name = name,
				itemID = itemID,
				itemString = itemString,
			})
		end
	end

	if #targets == 0 then
		TSM:Print(L["No scannable targets found in selected groups."])
		Scan:DoneScanning()
		return
	end

	TSMAPI.AuctionScan:StopScan()

	Scan.smartGroupScan = {
		targets = targets,
		targetIndex = 1,
		totalTargets = #targets,
		page = 0,
		totalPages = nil,
		data = {},
		itemCount = 0,
		retries = 0,
		startTime = time(),
	}

	TSM.GUI:UpdateStatus(format("Starting exact scan for %d items...", #targets), 0)
	Scan:SendGroupPageQuery()
end

function Scan:SendGroupPageQuery()
	if Scan.isScanning ~= "Group" or not Scan.smartGroupScan then return end

	if not AuctionFrame or not AuctionFrame:IsVisible() then
		TSM:Print(L["Group scan cancelled: Auction House was closed."])
		Scan:DoneScanning()
		return
	end

	if not CanSendAuctionQuery() then
		TSMAPI:CreateTimeDelay("groupScanQueryDelay", 0.08, function()
			Scan:SendGroupPageQuery()
		end)
		return
	end

	TSMAPI:CancelFrame("groupScanQueryDelay")
	TSMAPI:CancelFrame("groupScanRetry")

	-- 5 second watchdog timeout
	TSMAPI:CreateTimeDelay("groupScanWatchdog", 5.0, function()
		Scan:OnGroupScanTimeout()
	end)

	local sgs = Scan.smartGroupScan
	local target = sgs.targets[sgs.targetIndex]
	if not target then
		Scan:FinishSmartGroupScan()
		return
	end

	Scan:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", "OnGroupScanPageLoaded")
	QueryAuctionItems(target.name, nil, nil, nil, nil, nil, sgs.page, nil, nil)
end

function Scan:OnGroupScanPageLoaded()
	Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
	TSMAPI:CancelFrame("groupScanWatchdog")

	if Scan.isScanning ~= "Group" or not Scan.smartGroupScan then return end
	local sgs = Scan.smartGroupScan
	local target = sgs.targets[sgs.targetIndex]
	if not target then
		Scan:FinishSmartGroupScan()
		return
	end

	local numBatch, totalAuctions = GetNumAuctionItems("list")

	-- If this item has 0 auctions on AH, advance immediately to next target
	if not totalAuctions or totalAuctions == 0 or not numBatch or numBatch == 0 then
		sgs.retries = 0
		Scan:AdvanceGroupTarget()
		return
	end

	sgs.retries = 0
	local itemsPerPage = NUM_AUCTION_ITEMS_PER_PAGE or 50
	local totalPages = ceil(totalAuctions / itemsPerPage)
	sgs.totalPages = totalPages

	local pageData = sgs.data
	for i = 1, numBatch do
		local link = GetAuctionItemLink("list", i)
		local itemID = link and TSMAPI:GetItemID(link)
		local itemString = link and TSMAPI:GetBaseItemString(link)
		local _, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
		if itemID and count and count > 0 and buyout and buyout > 0 then
			if Scan.groupItems[itemID] or (itemString and Scan.groupItems[itemString]) or (target.itemID and itemID == target.itemID) then
				local itemData = pageData[itemID]
				if not itemData then
					itemData = {records = NewRecordTable(), minBuyout = math.huge, quantity = 0}
					pageData[itemID] = itemData
				end
				local itemBuyout = floor(buyout / count)
				itemData.minBuyout = min(itemData.minBuyout, itemBuyout)
				itemData.quantity = itemData.quantity + count
				AddWeightedRecord(itemData.records, itemBuyout, count)
				sgs.itemCount = sgs.itemCount + count
			end
		end
	end

	local curPage = sgs.page + 1
	local curTarget = sgs.targetIndex
	local totalTargets = sgs.totalTargets
	local pct = min(floor(((curTarget - 1) * 100 + (curPage * 100 / max(totalPages, 1))) / max(totalTargets, 1)), 100)

	if totalPages > 1 then
		TSM.GUI:UpdateStatus(format("[%d/%d] %s (Page %d/%d) - %d%%", curTarget, totalTargets, target.name, curPage, totalPages, pct), pct)
	else
		TSM.GUI:UpdateStatus(format("[%d/%d] %s - %d%%", curTarget, totalTargets, target.name, pct), pct)
	end

	if curTarget % 15 == 0 then
		collectgarbage("step", 20)
	end

	if curPage >= totalPages then
		Scan:AdvanceGroupTarget()
		return
	end

	sgs.page = curPage
	TSMAPI:CreateTimeDelay("groupScanNext", 0.05, function()
		Scan:SendGroupPageQuery()
	end)
end

function Scan:AdvanceGroupTarget()
	if Scan.isScanning ~= "Group" or not Scan.smartGroupScan then return end
	local sgs = Scan.smartGroupScan

	sgs.retries = 0
	sgs.page = 0
	sgs.totalPages = nil
	sgs.targetIndex = sgs.targetIndex + 1

	if sgs.targetIndex > sgs.totalTargets then
		Scan:FinishSmartGroupScan()
	else
		local curTarget = sgs.targetIndex
		local totalTargets = sgs.totalTargets
		local target = sgs.targets[curTarget]
		local pct = min(floor((curTarget - 1) * 100 / max(totalTargets, 1)), 100)
		TSM.GUI:UpdateStatus(format("[%d/%d] %s - %d%%", curTarget, totalTargets, target and target.name or "...", pct), pct)

		TSMAPI:CreateTimeDelay("groupScanNext", 0.05, function()
			Scan:SendGroupPageQuery()
		end)
	end
end

function Scan:OnGroupScanTimeout()
	Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
	if Scan.isScanning ~= "Group" or not Scan.smartGroupScan then return end
	local sgs = Scan.smartGroupScan
	local target = sgs.targets[sgs.targetIndex]

	sgs.retries = (sgs.retries or 0) + 1
	if sgs.retries <= 1 then
		TSMAPI:CreateTimeDelay("groupScanRetry", 0.4, function()
			Scan:SendGroupPageQuery()
		end)
	else
		-- Skip to next item on consecutive timeouts so scan never gets stuck
		sgs.retries = 0
		Scan:AdvanceGroupTarget()
	end
end

function Scan:FinishSmartGroupScan()
	if not Scan.smartGroupScan then return end
	local sgs = Scan.smartGroupScan
	local totalAuctions = sgs.itemCount or 0
	local elapsed = max(1, time() - (sgs.startTime or time()))
	local finalData = sgs.data or {}
	local groupItems = Scan.groupItems

	Scan.smartGroupScan = nil
	Scan:DoneScanning()

	local itemsWithAuctions = 0
	for _ in pairs(finalData) do itemsWithAuctions = itemsWithAuctions + 1 end

	TSM:Print(format("Group scan complete! %d items updated (%d auctions found) in %s.", itemsWithAuctions, totalAuctions, SecondsToTime(elapsed)))
	TSM.Data:ProcessData(finalData, groupItems)
end

function Scan:StartGetAllScan()
	TSM.db.profile.lastGetAll = time()
	Scan.isScanning = "GetAll"
	Scan.isBuggedGetAll = nil
	Scan.groupItems = nil
	TSMAPI.AuctionScan:StopScan()
	Scan:GetAllScanQuery()
end

function Scan:DoneScanning()
	TSMAPI:CancelFrame("groupScanQueryDelay")
	TSMAPI:CancelFrame("groupScanWatchdog")
	TSMAPI:CancelFrame("groupScanRetry")
	TSMAPI:CancelFrame("groupScanNext")
	TSMAPI:CancelFrame("groupScanColdDelay")
	Scan.smartGroupScan = nil
	TSMAPI:CancelFrame("marketScanQueryDelay")
	TSMAPI:CancelFrame("marketScanWatchdog")
	TSMAPI:CancelFrame("marketScanRetry")
	TSMAPI:CancelFrame("marketScanNext")
	TSMAPI:CancelFrame("safeFullScanQueryDelay")
	TSMAPI:CancelFrame("safeFullScanWatchdog")
	TSMAPI:CancelFrame("safeFullScanRetry")
	TSMAPI:CancelFrame("safeFullScanNext")
	TSMAPI:CancelFrame("getAllStall")
	TSMAPI:CancelFrame("getAllStallWatcher")
	TSMAPI:CancelFrame("getAllTimeout")
	Scan.stallWatcherRunning = nil
	Scan:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
	if Scan.unregisteredAtrCore and Atr_core and Atr_core.RegisterEvent then
		Atr_core:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
		Scan.unregisteredAtrCore = nil
	end
	TSM.GUI:UpdateStatus(L["Done Scanning"], 100)
	Scan.isScanning = nil
	Scan.getAllLoaded = nil
	Scan.safeScan = nil
	Scan.marketScan = nil
end

function Scan:ProcessScanData(scanData)
	local data = {}

	for itemString, obj in pairs(scanData) do
		if TSMAPI:GetBaseItemString(itemString) == itemString then
			local itemID = obj:GetItemID()
			local quantity, minBuyout = 0, 0
			local records = NewRecordTable()
			for _, record in ipairs(obj.records) do
				local itemBuyout = record:GetItemBuyout()
				if itemBuyout and itemBuyout > 0 then
					if itemBuyout < minBuyout or minBuyout == 0 then
						minBuyout = itemBuyout
					end
					quantity = quantity + record.count
					AddWeightedRecord(records, itemBuyout, record.count)
				end
			end
			data[itemID] = {records=records, minBuyout=minBuyout, quantity=quantity}
		end
	end

	local now = time()
	TSM.db.factionrealm.lastCompleteScan = now
	TSM.Data:ProcessData(data, Scan.groupItems)
end

function Scan:ProcessImportedData(auctionData)
	local data = {}
	for itemID, auctions in pairs(auctionData) do
		local quantity, minBuyout, records = 0, 0, NewRecordTable()
		for _, auction in ipairs(auctions) do
			local itemBuyout, count = unpack(auction)
			if itemBuyout and itemBuyout > 0 and count and count > 0 then
				if itemBuyout < minBuyout or minBuyout == 0 then
					minBuyout = itemBuyout
				end
				quantity = quantity + count
				AddWeightedRecord(records, itemBuyout, count)
			end
		end
		data[itemID] = {records=records, minBuyout=minBuyout, quantity=quantity}
	end
	TSM.db.factionrealm.lastCompleteScan = time()
	TSM.Data:ProcessData(data)
end
