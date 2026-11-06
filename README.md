# Pazzion's TradeSkillMaster (TSM 2) — WotLK 3.3.5a (Warmane Optimized Edition)

[![WoW Version](https://img.shields.io/badge/World%20of%20Warcraft-3.3.5a%20(WotLK)-blue.svg)](https://github.com/wonderkidsem-official/Pazzions-TradeSkillMaster-2-WotLK-Warmane-Edition)
[![Server Compatibility](https://img.shields.io/badge/Optimized%20For-Warmane%20(Icecrown%20%7C%20Lordaeron)-orange.svg)](https://www.warmane.com)
[![TSM Version](https://img.shields.io/badge/TSM%20Core-2.8.3%20Stable-green.svg)](https://tradeskillmaster.com)
[![License](https://img.shields.io/badge/License-Community%20Open%20Source-lightgrey.svg)](LICENSE.txt)

A heavily optimized, disconnect-proof fork of **TradeSkillMaster (TSM 2.8.3)** specifically re-engineered for **World of Warcraft 3.3.5a**, with dedicated fixes for **Warmane** high-population realms (Icecrown, Lordaeron, Onyxia).

---

## 🌟 Why This Fork Exists (The Warmane Problem)

On massive private realms like **Warmane Icecrown** (12,000+ players online simultaneously), the Auction House frequently holds **160,000+ active auctions**. Standard WotLK TSM builds break down under this load in three fatal ways:

1. **The Fatal "GetAll" Disconnect:**  
   Blizzard's native `GetAll` scan attempts to dump all 160,000+ auctions in a single uncompressed ~35 MB network socket packet. The 3.3.5a client's socket buffer instantly overflows, dropping the connection and kicking you to the login screen with *"Disconnected from server"*.
2. **The 25-30 Minute "Group Scan" Crawl:**  
   Standard TSM's query generator groups items by common text prefixes (e.g. searching `"Potion"` or `"Herb"`). On Warmane, searching `"Herb"` returns **230 pages (11,500 auctions)**! Searching 148 profession items resulted in scanning over **44,000+ irrelevant auctions**, locking the player at the Auctioneer for 25-35 minutes.
3. **Stale Tooltips & Frozen Pricing:**  
   Even after a group scan finished, original TSM failed to update `lastScan` timestamps. Item tooltips continued showing outdated days-old scan data, causing Crafting and Shopping formulas to return `nil` or miscalculate profits.

---

## 🚀 Key Features & Pazzion's Optimizations

### 1. ⚡ Exact-Item Smart Group Scan (~1-3 Minutes)
* **Replaces the sluggish 44,000-auction prefix crawl.**
* Instead of broad category floods (like downloading 230 pages of Level 1 Peacebloom when you only need WotLK herbs), this fork queries each item in your selected groups by its **EXACT NAME**.
* Items with 0 auctions on the AH advance in **0.05 seconds**.
* Items with active auctions download only their 1-2 actual pages in **~1 second**.
* **Result:** A full 148-item profession group finishes in **~2-3 minutes** instead of 30 minutes. Small custom groups finish in **under 30 seconds** with **0% disconnect risk**!

### 2. 🟢 Fast Market Scan (~1-1.5 Minutes)
* Added a dedicated **Fast Market Scan** button directly in the AuctionDB interface.
* Safely paginates through essential economy classes (**Trade Goods, Consumables, Gems, Glyphs**) page-by-page with 50 ms query intervals and a 6-second watchdog timeout.
* Fully bypasses Blizzard's socket overflow crash while still capturing all primary trade goods.

### 3. 🎯 AuctionDB Tooltip & LastScan Bugfix
* Every scanned item is immediately stamped with `lastScan = time()`.
* Tooltips instantly reflect live market data with green **`"Just now (X auctions)"`** indicators.
* Unlisted items (items with 0 current auctions) are cleanly reset with `quantity = 0` and `minBuyout = nil`, eliminating misleading phantom prices.

### 4. 🛡️ Watchdog & Anti-Freeze Auto-Recovery
* If the Warmane server drops a query packet or throttles requests, a built-in watchdog timer retries the request or smoothly advances to the next item so your scan **never hangs or freezes**.

### 5. 🏎️ TSMPerfBoost Companion Included
* Includes the **TSMPerfBoost** helper addon out-of-the-box.
* Optimizes Lua table memory pooling, throttles aggressive garbage collector pauses, and accelerates item filtering across the 32-bit client.

---

## 📦 Included Modules

This repository contains the complete, fully compatible TSM 2 suite:

| Module | Description |
| :--- | :--- |
| **`TradeSkillMaster`** | The core framework, group management, and global profile system. |
| **`TradeSkillMaster_AuctionDB`** | **[Heavily Modded]** Market value calculation, Fast Market Scan, and Smart Group Scan. |
| **`TradeSkillMaster_Auctioning`** | Automated auction posting, undercutting, and cancel scans. |
| **`TradeSkillMaster_Crafting`** | Profit evaluation, material cost tracking, and craft queue generation. |
| **`TradeSkillMaster_Shopping`** | Deal-finding, auction sniping, and automated purchasing lists. |
| **`TradeSkillMaster_Accounting`** | Detailed transaction logs, sales, purchases, and net profit tracking. |
| **`TradeSkillMaster_Mailing`** | Mass mailing, auto-sending crafting mats to bank alts. |
| **`TradeSkillMaster_Warehousing`** | Automated guild bank and personal bank deposit/withdrawal management. |
| **`TradeSkillMaster_ItemTracker`** | Account-wide inventory tracking across characters, bags, and mailboxes. |
| **`TradeSkillMaster_Destroying`** | Automated milling, prospecting, and disenchanting interface. |
| **`TSMPerfBoost`** | **[Pazzion's Bonus]** Lua memory pooling & performance acceleration addon. |

---

## 📥 Installation

1. Click the green **Code** button at the top of this repository and select **Download ZIP** (or clone the repository).
2. Exit World of Warcraft completely.
3. Open the downloaded ZIP file.
4. Copy all **11 folders** directly into your WoW AddOns directory:
   ```text
   World of Warcraft\Interface\AddOns\
   ```
5. Ensure the resulting structure inside `Interface\AddOns\` looks like:
   ```text
   Interface\AddOns\TradeSkillMaster\
   Interface\AddOns\TradeSkillMaster_Accounting\
   Interface\AddOns\TradeSkillMaster_AuctionDB\
   Interface\AddOns\TradeSkillMaster_Auctioning\
   Interface\AddOns\TradeSkillMaster_Crafting\
   Interface\AddOns\TradeSkillMaster_Destroying\
   Interface\AddOns\TradeSkillMaster_ItemTracker\
   Interface\AddOns\TradeSkillMaster_Mailing\
   Interface\AddOns\TradeSkillMaster_Shopping\
   Interface\AddOns\TradeSkillMaster_Warehousing\
   Interface\AddOns\TSMPerfBoost\
   ```
6. Launch World of Warcraft, open the **AddOns** menu on your Character Selection screen, make sure **"Load out of date AddOns"** is checked, and ensure all TSM modules are enabled.

---

## 🎮 How to Use in Game

1. Visit any Auctioneer in Dalaran, Orgrimmar, Stormwind, etc.
2. Open the **AuctionDB** tab at the bottom of the Auction House window.
3. **To Scan Your Professions/Groups:**
   * Select your desired profession group(s) in the left tree (e.g. *Alchemy*, *Jewelcrafting*, *Tailoring*).
   * Click the green **`[Scan Selected Groups]`** button on the bottom right.
   * Watch the real-time progress bar: `[1/148] Lichbloom (Page 1/2) - 1%`.
   * Finished in ~1-3 minutes with 100% updated tooltips!
4. **To Scan the General Economy:**
   * Click the green **`[Fast Market Scan (1m)]`** button on Row 1 to scan all primary profession materials and consumables safely.

---

## 🇹🇷 Türkçe Açıklama (Özet)

Bu sürüm, **Warmane** (Icecrown, Lordaeron vb.) 3.3.5a sunucularındaki devasa müzayede hacmi (160.000+ eşya) sebebiyle yaşanan çökme ve aşırı yavaşlama problemlerini çözmek için **Pazzion** tarafından özel olarak optimize edilmiş TSM 2 paketidir.

### Neler Düzeltildi?
1. **GetAll Disconnect Sorunu Giderildi:** Tek seferde 35 MB veri indirmeye çalışıp oyundan atan Blizzard hatası yerine, bağlantıyı koparmayan güvenli sayfalama sistemi entegre edildi.
2. **Akıllı Grup Taraması (Scan Selected Groups):** Eskiden "Herb" diye aratıp tüm sunucunun 230 sayfalık (11.500 adet) gereksiz 1 level otlarını indiren ve 30 dakika süren sistem kaldırıldı. Yerine seçtiğiniz gruptaki eşyaları **birebir tam adıyla** arayan nokta atışı tarama getirildi. 148 eşyalık devasa meslek listeleri **2-3 dakikada**, küçük gruplar **30 saniyede** taranır.
3. **Tooltip ve Fiyat Güncellemesi:** Taranan tüm eşyalarda anında yeşil renkte `"Just now"` görünür; satıcısı olmayan eşyaların hayalet fiyatları temizlenir.
4. **TSMPerfBoost Pakete Dahil Edildi:** 32-bit WoW istemcisinin bellek yönetimini ve çöp toplama (garbage collection) performansını artıran yardımcı modül eklendi.

---

## ⚖️ License & Credits

* Original TradeSkillMaster framework created by the **TradeSkillMaster Team** ([tradeskillmaster.com](https://tradeskillmaster.com)).
* WotLK 3.3.5a backport & Warmane optimization suite developed by **Pazzion** ([@wonderkidsem-official](https://github.com/wonderkidsem-official)).
* Distributed freely for the World of Warcraft community under Blizzard's UI Add-On Development Policy.
