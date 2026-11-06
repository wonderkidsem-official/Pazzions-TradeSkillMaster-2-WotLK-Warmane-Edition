-- TSMPerfBoost (Bronzebeard Edition) - Optimized for WoW 3.3.5a & TSM 2.8.3
local ADDON_NAME = "TSMPerfBoost"
local GetTime, collectgarbage = GetTime, collectgarbage
local InCombatLockdown = InCombatLockdown

local CONFIG = {
    gc_interval = 30,          -- run gentle step GC every 30s when out of combat
    gc_step = 20,              -- small step to prevent frame hitching
    fps_sample_interval = 1.0,
}

local state = {
    isScanning = false,
    nextGC = GetTime() + 15,
    lastFPS = 60,
}

_G.TSMPerfBoost = _G.TSMPerfBoost or {}
local PB = _G.TSMPerfBoost
PB.state = state
PB.CONFIG = CONFIG

-- FPS Sampling
local frameCounter, fpsTimer = 0, 0
local function SampleFPS(elapsed)
    frameCounter = frameCounter + 1
    fpsTimer = fpsTimer + elapsed
    if fpsTimer >= CONFIG.fps_sample_interval then
        state.lastFPS = frameCounter / fpsTimer
        frameCounter = 0
        fpsTimer = 0
    end
end

-- Safe, Low-Impact GC Management (Never in combat, never during active AH query)
local function SafeGC(now)
    if InCombatLockdown() or state.isScanning then return end
    if now >= state.nextGC then
        collectgarbage("step", CONFIG.gc_step)
        state.nextGC = now + CONFIG.gc_interval
    end
end

-- Event frame for window close cleanup (clean garbage after closing heavy frames)
local cleanupFrame = CreateFrame("Frame")
cleanupFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
cleanupFrame:RegisterEvent("MAIL_CLOSED")
cleanupFrame:RegisterEvent("TRADE_SKILL_CLOSE")
cleanupFrame:RegisterEvent("BANKFRAME_CLOSED")
cleanupFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
cleanupFrame:SetScript("OnEvent", function(self, event)
    if not InCombatLockdown() and not state.isScanning then
        -- Small stepped GC when heavy UI closes to free discarded temporary tables
        collectgarbage("step", 60)
        state.nextGC = GetTime() + CONFIG.gc_interval
    end
end)

-- Main lightweight OnUpdate ticker
local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function(self, elapsed)
    SampleFPS(elapsed)
    SafeGC(GetTime())
end)

-- Safe TSM 2.8.3 integration
local function HookTSM()
    if TSMAPI and TSMAPI.AuctionScan then
        if not PB._hooked then
            PB._hooked = true
            if TSMAPI.AuctionScan.RunQuery then
                hooksecurefunc(TSMAPI.AuctionScan, "RunQuery", function()
                    state.isScanning = true
                end)
            end
            if TSMAPI.AuctionScan.StopScan then
                hooksecurefunc(TSMAPI.AuctionScan, "StopScan", function()
                    state.isScanning = false
                end)
            end
        end
    end
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, name)
    if name == "TradeSkillMaster" or name == "TradeSkillMaster_Auctioning" or name == "TradeSkillMaster_AuctionDB" then
        HookTSM()
    end
end)
HookTSM()

-- User Slash Commands
SLASH_TSMPERFBOOST1 = "/tsmpb"
SlashCmdList["TSMPERFBOOST"] = function(msg)
    local cmd = (msg or ""):lower():trim()
    if cmd == "gc" then
        if InCombatLockdown() then
            print("|cFF50C0FF[TSMPerfBoost]|r: Cannot run GC in combat.")
        else
            local before = gcinfo()
            collectgarbage("collect")
            local after = gcinfo()
            print(format("|cFF50C0FF[TSMPerfBoost]|r: GC run. Memory: %d KB -> %d KB (Freed: %d KB)", before, after, before - after))
        end
    elseif cmd == "status" then
        local mem = gcinfo()
        print(format("|cFF50C0FF[TSMPerfBoost]|r: FPS: %.1f | Lua Mem: %.2f MB | Scanning: %s", state.lastFPS, mem / 1024, tostring(state.isScanning)))
    else
        print("|cFF50C0FF[TSMPerfBoost]|r: Commands: /tsmpb status | /tsmpb gc")
    end
end
