-- TSMPerfBoost cache helpers for TSM2
local CACHE = {}
CACHE.__index = CACHE

local cacheStore = {}
local function now() return GetTime() end
local function key(prefix, id) return prefix .. ":" .. tostring(id) end

function CACHE:Get(prefix, id, ttl, fetcher)
    ttl = ttl or (_G.TSMPerfBoostConfig and _G.TSMPerfBoostConfig.price_cache_ttl or 6)
    local k = key(prefix, id)
    local e = cacheStore[k]
    if e and (now() - e.t) < ttl then
        return e.v
    end
    local ok, v = pcall(fetcher)
    if not ok then v = nil end
    cacheStore[k] = { v = v, t = now() }
    return v
end

-- Safe wrappers for common TSM2 value sources.
-- TSM2 exposes price values as TSM:GetData or TSMAPI:GetData in some installs;
-- we attempt multiple fallbacks.

local function safeGetTSMData(itemString, sourceKey)
    local TSMglob = _G.TSM or _G.TradeSkillMaster
    if not TSMglob then return nil end
    -- Try TSM:GetData or TSM:GetValue or TSMAPI:GetData
    if type(TSMglob.GetData) == "function" then
        local ok, v = pcall(TSMglob.GetData, TSMglob, sourceKey, itemString)
        if ok then return v end
    end
    if type(TSMglob.GetValue) == "function" then
        local ok, v = pcall(TSMglob.GetValue, TSMglob, itemString, sourceKey)
        if ok then return v end
    end
    -- fallback nil
    return nil
end

_G.TSMPerfBoost_cache = setmetatable({}, CACHE)

function _G.TSMPerfBoost_cache:GetMarket(itemString)
    return self:Get("market", itemString, nil, function()
        return safeGetTSMData(itemString, "market") or 0
    end)
end

function _G.TSMPerfBoost_cache:GetMinBuyout(itemString)
    return self:Get("minbuyout", itemString, nil, function()
        return safeGetTSMData(itemString, "minbuyout") or 0
    end)
end

function _G.TSMPerfBoost_cache:GetRegion(itemString)
    return self:Get("region", itemString, nil, function()
        return safeGetTSMData(itemString, "regionmin") or 0
    end)
end
