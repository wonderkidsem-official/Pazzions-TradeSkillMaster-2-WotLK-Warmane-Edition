TSMPerfBoost (Bronzebeard) - v2.0.0



Purpose:

Lightweight performance helpers for TradeSkillMaster 2.8.3 (TSM2) on Classic/3.3.5 servers such as Bronzebeard.

Goal: reduce AH-scan/stall lag, lower GC spikes, throttle UI updates during scans, and provide simple profiling.



Install:

1\. Place folder 'TSMPerfBoost' into Interface/AddOns/.

2\. Restart client or /reload.

3\. Open the Auction House and run a TSM scan to let the addon attach.



Usage:

/tsmpb status     -- show status (FPS, latency, blocking)

/tsmpb toggle     -- force blockUI toggle

/tsmpb gc         -- force full GC

/tsmprof start|stop|report -- profiler



Notes:

\- The addon attempts to hook multiple TSM2 APIs safely (TSM.Scan, TSM.Scan:StartScan, TSM.ScanStart), but will do nothing if it can't find TSM internals.

\- All hooks are non-destructive (hooksecurefunc / wrappers). If anything looks broken, disable the addon and /reload.



