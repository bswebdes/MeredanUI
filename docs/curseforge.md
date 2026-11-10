# CurseForge – Projekttexte

## Description

> ⚠️ **Beta** – MeredanUI is in active development. Expect bugs and changes between versions.
> Found a bug or have an idea? Please report it on [GitHub Issues](https://github.com/bswebdes/MeredanUI/issues) – that's the fastest way to get it fixed.

**MeredanUI** is a clean, flat all-in-one interface for **WoW Forever**.
One addon, one look, one settings window (`/mui`).

### Why mUI?
Like many players, I used one of the big all-in-one UIs for years and knew it inside out. But with every expansion it grew more
features, more options, more to set up – until I simply didn't enjoy it anymore. I went looking for
something simpler and never really found it.

When I came back to WoW and WoW Forever launched, I decided to build my own interface: one that looks
the way I always wanted and just works. It kept getting better, so now I'm sharing it.

The idea behind mUI:
- **Install it and be happy right away.** No hours of setup, no YouTube tutorials needed.
- **Fixed, clean layouts** instead of moving every frame yourself – you can adjust settings, but you don't have to.
- **An everyday helper:** the things I actually need while playing, in one place.
- **Made from one mould:** everything looks like it belongs together, instead of a pile of old addons
  that are only barely kept alive.

New features are welcome – as long as they're genuinely useful and don't bloat it.

### Highlights
- **Unit frames** for player, target, party and raid: big name on top, health and power as numbers in the bar
- **Action bars**, micro menu and key binding mode
- **Bags, bank and mail** in one style, auto-restock of ammunition and class reagents at vendors
- **Auction house** with sell helper and a ledger (income, expenses, fees)
- **Chat** with emoji, RP mode and a cleaner look
- **Minimap**, info bars, XP and reputation bars, flight timer
- **Nameplates**, combat text, damage meter, loot window and loot rolls
- **WoW Forever extras:** class reagents and ammo counter (arrows/bullets by weapon), swing timer, pet helper, spell ranks
- **Setup wizard** with two styles (Classic / Comfort), profiles and layouts

### Commands
- `/mui` – settings (also via the addon menu at the minimap)
- `/mui t` – test mode
- `/mui help` – all commands

### Privacy
If you use the Wago app, MeredanUI sends anonymous statistics through Wago Analytics: which style, modules and helpers are switched on, and Lua errors from MeredanUI – so bugs get fixed even when nobody reports them. Nothing is sent without the Wago app.

### Languages
English and German (deDE).

### About this project
MeredanUI is an **original addon**, written from scratch – it is **not a fork, port or edit** of another UI
(ElvUI, Tukui, etc.). It bundles a few open-source libraries and assets and uses public game data; all
of them are listed below with their license and a link. No textures, code or art from other UI addons
are included. How MeredanUI differs from them: these parts are
building blocks only (frame engine, button handling, media, data tables) – the layout, look, settings,
windows and all features are MeredanUI's own code. The source code is public on
[GitHub](https://github.com/bswebdes/MeredanUI) (all rights reserved).

### Credits
**Libraries** (unchanged, in `libs/`)
- [oUF](https://github.com/oUF-wow/oUF) – MIT License – unit frame engine; MeredanUI's frames, layout and look are its own
- [LibActionButton-1.0](https://github.com/Nevcairiel/LibActionButton-1.0) – BSD License – action button handling
- [LibSharedMedia-3.0](https://www.wowace.com/projects/libsharedmedia-3-0) – LGPL v2.1
- [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler) – BSD License
- [LibStub](https://www.wowace.com/projects/libstub) – Public Domain

**Fonts, icons, emoji**
- Fonts "mUI" based on [Blue Highway](https://typodermicfonts.com) by Raymond Larabie – CC0 1.0 (public domain), renamed and letter spacing adjusted
- [Cinzel](https://github.com/NDISCOVER/Cinzel) by Natanael Gama – SIL Open Font License 1.1
- [Material Design Icons](https://pictogrammers.com/library/mdi/) (Pictogrammers) and [Material Symbols](https://fonts.google.com/icons) (Google) – Apache License 2.0
- [Twemoji](https://github.com/twitter/twemoji) by Twitter, Inc. and contributors – CC-BY 4.0 (converted to game textures)

**Dungeon maps**
- Maps of WoW Forever's new dungeons: [Atlas de Azeroth: Forever](https://santiago-reyes-portfolio.vercel.app/post/proyecto-atlas-de-azeroth-forever) by Santiago Reyes ([sreyesmaps.com](https://sreyesmaps.com)) – used with his permission, watermark untouched

**Data**
- Classic flight times: [InFlight Taxi Timer](https://github.com/LudiusMaximus/InFlight) by LudiusMaximus – used as a data table only, MeredanUI's flight timer and map are its own
- Dungeon entrance positions: [HandyNotes_DungeonLocations (Classic)](https://github.com/callie-g/HandyNotes_DungeonLocations-classic) – coordinates only
- WoW Forever stat weights: [WoWSims](https://github.com/wowsims) (MIT) presets and Forever Codex simulations
- Game data (flight routes, maps, instances) from Blizzard via [wago.tools](https://wago.tools)

The full list with license texts is in `CREDITS.txt` in the addon folder.

---

> ⚠️ **Beta** – MeredanUI wird gerade aktiv entwickelt. Fehler und Änderungen zwischen Versionen sind normal.
> Fehler oder Ideen bitte über [GitHub Issues](https://github.com/bswebdes/MeredanUI/issues) melden.

**MeredanUI** ist ein klares, flaches Komplett-Interface für **WoW Forever**:
ein Addon, ein Look, ein Einstellungsfenster (`/mui`). Komplett auf Deutsch verfügbar.
