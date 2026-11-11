# MeredanUI Changelog

## Unreleased
- XP bar tooltip: how far along the way to level 60 you are
- Accent colour can now also be Blizzard's own class colour (Look page)
- Look page: optional gryphons (Horde: wyverns) at the bottom action bars, gold brown frame borders, and a "Blizzard" theme with Blizzard's frame colours
- Quest rewards: the coin on the most valuable choice is bigger and sits on the item icon
- "Back to Blizzard" (Profiles page): resets chat and the game settings mUI changed to Blizzard's defaults and turns mUI off – handy before uninstalling
- Item comparison: one-handed weapons show main hand and off hand separately when you dual wield, and the off hand is no longer compared with a main hand score
- Item comparison: weapons your class can learn at a weapon master get a grey comparison
- Rogues can use one-handed axes and druids polearms (WoW Forever)
- Questie: click an icon on the minimap to make the quest active
- "What's new" shows the five newest pages

## v0.4.0
- MeredanUI leaves beta: from now on regular releases, so the CurseForge app and other addon managers pick up updates with default settings. mUI is still in early access – feedback and bug reports are very welcome
- New Comfort helper: sparkle on the nearest herb, ore vein, quest object, chest or skinnable corpse – green for herbs, orange for ore, red for skinning (each only with the matching profession), yellow for quest objects, white for other objects like benches and mailboxes (own switch). Dimmed while out of reach, quest progress under the sparkle when you point at the object, off in combat (Quests page)
- New Comfort helper: class quest reminder. A toast tells you when a class quest for a new ability becomes available (Defensive Stance, Bear Form, Voidwalker, totems, Paladin mounts and more, including the new Forever quests) and where it starts for your race. Click the toast for a map pin with an arrow (Quests page)
- The Comfort style no longer turns on auto accept and auto turn-in of quests – both are opt-in on the Quests page now. Your current settings stay as they are
- "What's new" pages of new helpers have a "Turn on" checkbox
- Fixed a Lua error when reloading the UI in combat (quest item bar)
- Dungeon maps: Ragefire Chasm is now in the dungeon panel
- Dungeon maps: Wailing Caverns and Ragefire Chasm show WoW Forever's own loot and drop chances, including the new Forever items
- Dungeon maps: the "Quests" tab now also lists the new Forever dungeon quests and shows a faction icon for Horde or Alliance quests

## v0.4.0-beta.1
- Dungeon maps: a new panel next to the map shows the bosses with their portraits. Click a boss (in the list or on the map) to see its loot with drop chances, filtered for your class ("For me" / "All"). Items you have seen dropping in Forever get a check mark. Starting with Wailing Caverns, more dungeons follow one by one
- Dungeon maps: a "Quests" tab lists all quests of the dungeon for your race and class: done, in your quest log, or where the quest giver stands (click for a map pin, coordinates in the tooltip)
- Wishlist: star the loot you want. It opens in a window next to the map and in the character window, with the boss, drop chance, a try-on preview and your progress; item tooltips show "On your wishlist"
- New "What's new" window after updates with big new features, once per account. Open it again in the settings or with /mui news
- Questie: click an icon on the mUI map to make that quest the active one in the tracker (or set a map pin on the giver of a quest you don't have yet); "Hold Shift" for details now works on the mUI map
- Quest tracker: the objective with distance and arrow is shown for the active quest only
- Nameplates: a soft glow behind your hostile target
- Tooltip: "Rare", "Elite", "Rare Elite" or "Boss" behind NPC names (can be turned off)
- Emote bar: up to 12 emotes
- Fixed: a Lua error after reloading the UI in combat (quest item bar)

## v0.3.0-beta.6
- MeredanUI is now made for WoW Forever only
- New Comfort helpers, each with its own switch (all on with the Comfort style, off with Classic):
  - Quests: accept and hand in quests automatically, skip single conversation options; hold Shift to pause. Grey quests, reward choices and quests that cost gold or materials are left alone
  - Quest window: a gold coin marks the reward with the highest vendor value
  - Accept summons (out of combat) and resurrections, decline duels from strangers, skip cinematics you have seen before
  - Buff reminder: a toast for missing class buffs, outdated buff ranks and expired weapon oils or stones; the ready check counts classic elixirs
  - Item tooltips show how many you have on your other characters (bags, bank, mail, worn)
- Camera zooms further out for everyone
- Class touches: class icon in player tooltips and in front of names in guild, group, raid and whisper chat, class icon in the character window, class line in the tooltip in class colour, optional accent in your class colour (Appearance)
- Player buffs above the player frame: one row, shortest left to longest right
- Questie support: Questie icons on the mUI world map, mUI's quest tracker shows the turn-in NPC, the nearest objective with distance and a direction arrow coloured by distance, Questie-style right-click menu and Ctrl-click waypoint, new "Quests" settings page, Questie's settings window in the mUI look
- Other addons: Plater, Bagnon, Details, DBM, BigWigs, Bartender4 and others are detected. Pick in the setup or once in a dialog whether the addon or mUI does the job; mUI's settings for that part are greyed out while the addon is in charge
- Bagnon, Details, Plater, DBM and BigWigs get a matching mUI look and fixed spots that fit the mUI layout (each can be turned off)
- Dungeon maps: Blackrock Spire with all six floors, cleaner Zul'Farrak and Alcaz Prison maps; bosses without a portrait show a ring with a question mark
- Chat tabs "General" and "Combat Log" follow your game language
- Fixed: the bank closed right after opening it through a banker's conversation option
- Fixed: a disabled nameplate, bag or damage meter addon could switch off mUI's own module
- Lua errors from MeredanUI are reported anonymously through the Wago app (only if you use it), so bugs get fixed without a report
- Performance: nameplates, threat bar, quest tracker and idle work do much less

## v0.3.0-beta.5
- Dungeon maps: almost every dungeon and raid now has a new mUI map made from the game's own data, including all floors. Blackrock Spire, City of Dalaran and Alcaz Prison keep their previous maps for now
- Dungeon maps: floors are picked from a dropdown next to the dungeon name instead of a row of buttons
- Boss positions on the new maps still need to be checked and are not exact everywhere yet. If a boss is in the wrong spot, please let us know (feedback welcome!)
- World map: raids that are not in WoW Forever (Molten Core, Blackwing Lair, Zul'Gurub, Ahn'Qiraj, Naxxramas) are no longer shown; Onyxia's Lair is greyed out until it opens on December 9

## v0.3.0-beta.4
- Hall of Thanes: boss pins on the dungeon map
- Dungeon maps: a few boss and rare positions corrected (Wailing Caverns, Maraudon, Saltspine)

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
