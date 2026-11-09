# MeredanUI Changelog

## v0.3.0-beta.3
- Dungeon maps on the world map (WoW Forever): click a dungeon portal to open its map, with boss and rare portraits where they stand. Ragefire Chasm, Wailing Caverns and the Hall of Thanes use new mUI maps made from the game's own data on a themed background; the other classic dungeons use Blizzard's maps for now
- World map: entrances of Forever's new dungeons are shown (approximate at first, exact once you have been inside)
- New fishing bag (WoW Forever): opens when you equip a fishing pole. Catches of the current fishing trip, catches per hour, lure bar (click to apply), fishing logbook per zone with escape rate, "Rare catch!" toasts. Right-click a catch to use it. Optional: double right-click into the world to cast (Comfort)
- Bags: fishing bag button in the header while a pole is equipped; keyring tab (WoW Forever, only with keys); quiver and ammo pouch always come last. The "Separate bags" layout was removed, it now uses "Sections"
- New skins: guild and communities window (incl. guild ranks), group finder, macros, calendar, hunter stable, battleground scoreboard, socketing, tabard, guild charter, clock, death recap, addon list, ready check, dressing room, quantity dialog
- Guild: overview tab with classes, level ranges, founding date and main/alt counts; members inactive for 14+ days are marked faintly red
- New collections window (WoW Forever)
- Queue status as a sticky entry on top of the toasts, with waiting time and all listed activities
- Action bars: three optional extra bars, new visibility "In combat", per-bar key binding and macro text, key binding text size
- Buffs & debuffs: new time display as a bar below the icon; permanent auras show no bar; sorted by remaining time
- Nameplates: friendly NPCs and companions on name-only mUI plates, new settings for which names to show, name size, NPC titles and companion owners
- Menus and tooltips: Surf Green highlights and section titles instead of Blizzard yellow
- Settings: larger window with new Modules, Skins and Changelog pages; background opacity setting; theme "Classic green" is now "mUI (sage)"
- Auction house and mailbox stay off when another auction or mail addon is loaded
- /mui help is shorter: settings, key bindings and preview
- Group frames: members joining during combat show up right away
- Performance improvements and many small fixes

## v0.3.0-beta.2
- Status bars now use MeredanUI's own flat texture; third-party bar textures were removed
- Mythic+: LibKeystone is no longer bundled; party keystones show when another addon (e.g. BigWigs) provides it
- Font license files are included next to the fonts

## v0.3.0-beta.1
- New group tools bar on the left edge, replacing Blizzard's raid leader bar: ready check, role check, 10-second countdown, unit and ground markers (work in combat), ping restriction and leave group. Shows only what you are allowed to use
- Legacy trees: cleaner background without the divider line
- New legacy window (WoW Forever): rewards, challenges (categories, search, filter, tracking, objectives) and the three legacy trees (spend points, apply, undo, reset) in the mUI look, tabs on the right. Respects Blizzard's unlock; /mui legacy opens a preview
- New flight map (WoW Forever): a large, centered window instead of the small square one. Zoom with the mouse wheel, drag to move
- Flight times: the flight map tooltip shows how long a flight takes, and the flight timer counts down from the first flight on. Known times come from your own flights, otherwise from built-in estimates (Classic times plus the new Forever routes, marked "approx."), including the Frequent Flier legacy talent
- Chat: "changed/left/joined channel" messages on zone changes are hidden
- World map: reveal the whole map and show level ranges on zone names, colored by your level, plus the zone's faction (Alliance blue, Horde red, contested yellow, with faction crests) (Comfort style, toggles in the map's Display menu). Forever has no level data for zones, so mUI brings its own, including the new Forever zones
- World map: map pin button moved onto the map; the map no longer opens zoomed in too far
- World map: dungeon and raid entrances work in WoW Forever (blue and green portal icons with name tooltip, larger on zone maps). For portals hidden in caves or mountains, hovering marks the outside entrances on the zone map (with a note, e.g. when a key is needed)
- Bags: items that fit an empty equipment slot get a green frame, and their tooltip says which slot they fill. Only gear your class can actually wear is marked (Comfort style, can be turned off)
- Upgrade marker is now a flat triangle. Tooltips show a green triangle for upgrades and a red one for downgrades next to the percentage
- Talent advisor: a star marks the recommended leveling build for each class
- Talents respect Blizzard's unlock level again (key and micro menu button show Blizzard's message instead of opening early)
- Quest tracker: timed quests show the remaining time in red with an hourglass, blinking during the last minute
- Quest tracker: cleaner right-click menu with the quest name as title and icons
- Battle.net toasts (friend online/offline, invites) now show up reliably
- Weapon skill in the info bar shows your main weapon (ranged weapon for hunters, main hand for everyone else)
- Profession overview: profession artwork fills the cards without Blizzard's frame
- New name option: last name only
- The setup wizard now reliably appears on every character that hasn't done it yet
- New command /mui legacy to preview the Legacy window
- Fixed a Lua error in the quest window

## v0.2.0-beta.4
- Every character gets its own profile, named after the character (first and last name in WoW Forever); existing characters keep their settings
- The setup wizard now appears once per character instead of once per account
- Friends, spellbook and profession windows can be opened and closed in combat again
- Chat snaps back into place if something else moves it
- Shorter realm names in the gold overview, e.g. "Koratal (RP)"

## v0.2.0-beta.3
- Cleaner release notes (English changelog)

## v0.2.0-beta.2
- Auction ledger: sold and expired auctions are now recognized correctly (sales no longer show up as "expired" or "cancelled")

## v0.2.0-beta.1
First public beta.

- All-in-one interface for WoW Forever and Retail (Midnight): unit frames, group and raid frames, action bars, minimap, info bars, nameplates, tooltip, chat, bags, bank, mail, auction house, damage meter, loot window and loot rolls
- Setup wizard with two styles (Classic / Comfort) and layouts for melee, ranged, tank and healer
- WoW Forever: own character, talent, spellbook, profession, trainer, vendor and quest windows; talent advisor with leveling builds; class reagents and ammo counter (arrows or bullets, matching your ranged weapon); swing timer, pet helper, spell ranks, flight timer
- Auction house: buy, sell, your auctions and a ledger (income, expenses, fees)
- Auto-restock of ammunition and class reagents at vendors
- English and German
