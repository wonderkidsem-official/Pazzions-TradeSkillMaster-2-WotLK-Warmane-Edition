-- filterboost.lua
-- Fast item link and helper utilities for TSM on 3.3.5a

local PB = _G.TSMPerfBoost or {}
PB.filter = PB.filter or {}

local function QuickItemID(link)
    if not link then return nil end
    local itemID = link:match("item:(%d+)")
    return tonumber(itemID)
end
PB.filter.QuickItemID = QuickItemID

local itemCache = {}
local itemCacheCount = 0
function PB.filter.GetItemInfoFast(itemID)
    if not itemID then return end
    local c = itemCache[itemID]
    if c then return unpack(c) end

    local name, link, quality, ilvl, req, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemID)
    if name then
        if itemCacheCount > 2000 then
            wipe(itemCache)
            itemCacheCount = 0
        end
        itemCache[itemID] = { name, link, quality, ilvl, req, class, subclass, maxStack, equipSlot, texture, vendorPrice }
        itemCacheCount = itemCacheCount + 1
    end
    return name, link, quality, ilvl, req, class, subclass, maxStack, equipSlot, texture, vendorPrice
end
