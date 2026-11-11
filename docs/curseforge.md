> 🌐 **Website:** [meredanui.com](https://meredanui.com) – screenshots, install guide and FAQ
>
> 🛠 **Early Access** – mUI is actively developed by a single person. Things may break, and some features are still rough around the edges.
> Your feedback is incredibly valuable: every bug report and idea directly shapes the addon. Found something? Open an issue on [GitHub](https://github.com/bswebdes/MeredanUI/issues) – a screenshot helps a lot.

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
- **Dungeon maps** for WoW Forever: bosses where they stand, their loot with drop chances, all dungeon quests and a **wishlist** with try-on
- **Comfort helpers** (each with its own switch): auto quests, summons, buff reminders, item counts across your characters
- **Plays nice with other addons:** Bagnon, Details, Plater, DBM and BigWigs take over their part in a matching mUI look
- **Setup wizard** with two styles (Classic / Comfort), profiles and layouts

### Recommended: Questie
MeredanUI works best together with **[Questie](https://github.com/Questie/Questie)**. It is built right in, so it feels like part of mUI:
- Questie's icons sit on the mUI map – click one to make the quest active, hold Shift for details
- the quest tracker shows the nearest objective, its distance and an arrow that turns green as you get close
- turn-in NPCs and quest items come straight from Questie

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
- Class quest starts: [QuestieDB](https://github.com/Questie/QuestieDB) (Forever data) – quest and NPC facts only, the reminder is MeredanUI's own
- Game data (flight routes, maps, instances) from Blizzard via [wago.tools](https://wago.tools)

The full list with license texts is in `CREDITS.txt` in the addon folder.

---

> 🛠 **Early Access** – mUI wird von einer einzelnen Person aktiv entwickelt. Es kann noch Fehler geben, manches ist noch nicht ganz rund.
> Dein Feedback ist Gold wert: Jede Fehlermeldung und jede Idee formt das Addon direkt mit. Etwas gefunden? Melde es auf [GitHub](https://github.com/bswebdes/MeredanUI/issues) – ein Screenshot hilft sehr.

**MeredanUI** ist ein klares, flaches Komplett-Interface für **WoW Forever**:
ein Addon, ein Look, ein Einstellungsfenster (`/mui`). Komplett auf Deutsch verfügbar.
