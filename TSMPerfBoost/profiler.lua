-- Simple profiler for TSMPerfBoost (counts calls in TSM 2.8.3)
local profiler = {
    enabled = false,
    hits = {},
    startTime = 0,
}

local function tick(name)
    if not profiler.enabled then return end
    profiler.hits[name] = (profiler.hits[name] or 0) + 1
end

local function HookIf(fnTable, fnName)
    if not fnTable or type(fnTable[fnName]) ~= "function" then return end
    hooksecurefunc(fnTable, fnName, function()
        tick(fnName)
    end)
end

local function InitHooks()
    if TSMAPI and TSMAPI.AuctionScan then
        HookIf(TSMAPI.AuctionScan, "RunQuery")
        HookIf(TSMAPI.AuctionScan, "FindAuction")
        HookIf(TSMAPI.AuctionScan, "StopScan")
    end
    local Crafting = _G.TradeSkillMaster_Crafting or (TSM and TSM.modules and TSM.modules.Crafting)
    if Crafting and Crafting.Cost then
        HookIf(Crafting.Cost, "GetCraftPrices")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", InitHooks)

SLASH_TSMperfprof1 = "/tsmprof"
SlashCmdList["TSMperfprof"] = function(msg)
    local cmd = (msg or ""):lower():trim()
    if cmd == "start" then
        profiler.enabled = true
        wipe(profiler.hits)
        profiler.startTime = GetTime()
        print("|cFF50C0FF[TSMPerfBoost]|r: Profiler started.")
    elseif cmd == "stop" then
        profiler.enabled = false
        print("|cFF50C0FF[TSMPerfBoost]|r: Profiler stopped.")
    elseif cmd == "report" then
        print(format("|cFF50C0FF[TSMPerfBoost]|r: Report (active %.1fs):", GetTime() - profiler.startTime))
        local count = 0
        for k, v in pairs(profiler.hits) do
            print(format(" - %s: %d calls", k, v))
            count = count + 1
        end
        if count == 0 then
            print(" - No hooked functions were called during profiling.")
        end
    else
        print("|cFF50C0FF[TSMPerfBoost]|r: Usage: /tsmprof start | stop | report")
    end
end
