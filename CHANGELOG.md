# MeredanUI Changelog

## v0.6.0
- New: favorites in the bags. Alt + right-click an item and tick Favorite: it stays at the top of your bags with gold corners. You can also drag items onto the Favorites heading
- New: optional second chat window bottom right for Trade chat, with its own copy button. Settings > Chat > "Set up second chat window", the setup wizard asks for it too
- New: small map above the chat (square button at the top right of the map). It fades while you move, mouse over shows it fully
- New: health and power text for player and target (Settings > Unit frames): value, percent, value and percent, value / max or off. The power text can be white or in the colour of the resource
- New: every settings page is sorted into clear sections, checkboxes sit in two columns
- New: OpenMap, Mapster and Leatrix Maps are detected. While one of them is enabled, the mUI map stays off
- Group frames show a mana bar for everyone who uses mana when the group has no roles assigned
- The "New in mUI" window only shows the five newest pages
- Fixed: enchanting through the trade window (the other player's "Will not be traded" slot) did nothing
- Fixed: using items from the mUI bags could be blocked now and then
- Fixed: "Interface action failed" when the map was open in combat with the mouse over a quest pin
- Fixed: inspecting a player showed most equipment slots as empty
- Fixed: boss names in the Hall of Thanes, the Drowned City and Krol'dok now match the game

## v0.5.16
- Fixed: items in the mUI bags could be blocked when used in combat

## v0.5.15
- Fixed: with Attack with abilities on, openers from stealth (Garrote, Cheap Shot, Ambush, Pounce, Ravage) failed with "You must be stealthed". Auto attack no longer starts while you are stealthed
- Player tooltips are tidied up again when the game rebuilds them (level line, race and class)

## v0.5.14
- Fixed: the setup could show up again on characters that had already finished it
- The mail icon on the minimap goes away once only read letters are left

## v0.5.13
- New frame material: Class metal (Appearance page, Frame material). Every character gets its own muted metal in its class colour, from brass for warriors and verdigris for hunters to copper for druids. Window frames, action buttons, item borders, dividers and the action bar end caps all take it on

## v0.5.12
- New Templates tab in the macro window: ready-made macros for your class, each with a short how-to, in English and German. Only macros for spells you already know can be created, and they are saved as macros for this character
- Players who are away or busy show <AFK> or <DND> after their name in the tooltip and on the target frame
- Distant NPCs (hostile and neutral) show their name again before their nameplate appears

## v0.5.11
- Right-click the gold display (info bar or bags) to forget a character you deleted or no longer play. Its gold, its items in tooltips and its mUI settings are removed

## v0.5.10
- PvP flag at a glance: while you are flagged, your faction crest sits as a faint watermark in your health bar. Hidden in battlegrounds and arenas
- Elite and rare at a glance: the classic dragons are back. Gold for elite, silver for rare and rare elite, on the target frame, on enemy nameplates and in the tooltip
- Enemy nameplates show the level in front of the percent, in the difficulty colour (grey, green, same level, orange, red, ?? for bosses)
- The target frame always shows the level. Long names are shortened instead of pushing the level out
- Players of the other faction who are not flagged for PvP show their name again
- Hardcore mode: your death number (#15) above YOU DIED, taken from the game's own statistics
- Fixed: Hardcore mode could not log you out. Logging out now starts when you click Try again
- Fixed: closing Beast Training left its list and Train button on screen, and casting it again did not close it
- Fixed: using an armor kit, oil or similar item while the character window was open closed the window
- Fixed: the mail icon on the minimap stayed after emptying the mailbox

## v0.5.9
- Fixed: game settings mUI changes only for a while (for example by RP mode) are now handed back properly. Before, things like enemy nameplates could stay hidden and neither the key binding nor the setting turned them back on
- Fixed: zooming out of the world map during combat no longer causes a blocked action message
- In dungeons, raids and battlegrounds, friendly pets and NPCs no longer get Blizzard's full nameplate bars. Blizzard doesn't let addons touch friendly nameplates there, so they stay off; players still show their names
- Fixed: /fstack no longer throws errors on nameplates in dungeons

## v0.5.8
- Attack with abilities. Harmful spells on mUI action buttons now also start your auto attack (Comfort style, can be turned off)
- Spells, professions and toys in the spellbook cast when you release the click, so dragging them onto a bar no longer casts them by accident
- New spell ranks automatically replace the previous rank on your action bars, and newly learned spells go to the first free slot (Comfort style)

## v0.5.7
- Battlegrounds got the full mUI treatment. The flag score at the top is now one versus board with both faction crests, and every capture lights up a gem. A small flag pulses on the crest while a team holds the enemy flag
- Flag carriers get their own mUI frames in the boss frame column, with the carried flag next to them. A click targets the carrier, and the quest log moves aside just like it does for boss frames
- The battleground scoreboard has a new look with faction crests, crests on the team tabs, a faction glow on every row and a gold band on your own row. The Honor column is no longer cut off and the team tabs show their full names
- Russian names and chat now show properly. The mUI fonts include Cyrillic letters, and the chat no longer drops Cyrillic text
- Nameplates get a thin gold frame on mouseover instead of a white wash over the health bar
- The tooltip Blizzard drew over soft-targeted nameplates is turned off, so you get the normal mUI tooltip on mouseover
- Recent allies are marked with a small icon behind the name in the tooltip instead of an extra line
- Fixed: several Lua errors in battlegrounds (buff reminder, ready check, AFK screen, scoreboard)

## v0.5.6
- The dungeon panel on the map now covers every dungeon open in Forever: bosses with their loot and drop chances, plus a quest tab. Loot and quests are updated from the latest guides, including Shaper's Terrace
- Boss pins on dungeon maps with several floors now sit on the floor where the boss really stands (Scholomance, Blackrock Spire, Dire Maul, Gnomeregan and more)
- Shadowfang Keep has a clearer map: four floors that fill the frame instead of seven mostly empty ones
- City of Dalaran has a new map in the same style as the other dungeons, with boss pins at their real spots

## v0.5.5
- Hunters: while Aspect of the Cheetah or Aspect of the Pack is up, its action bar button pulses with a turquoise edge, faster when a fight starts. Both aspects daze you when hit, so they are easy to forget. On by default in the Comfort style, can be turned off on the Action bars page
- New just-for-fun Hardcore mode (Appearance page, off by default). When you die the interface fades out, YOU DIED appears with who killed you and with what, plus a mocking line from a well-known NPC. Try again logs you out to character select after 20 seconds, Keep playing cancels it. A Test button shows the screen without dying. Not available on official Hardcore realms
- Talent advisor build names now follow your client language

## v0.5.4
- Fixed: Beast Training could not teach your pet anything (Lua error on Train and All learnable). It now opens in the mUI trainer window with your pet, its training points and a working Train button
- The pet tab of the spellbook shows how many abilities you learned at a pet trainer but haven't taught your pet yet. Hover it for the list
- Bags: the Reagents tab is gone, everything in the reagent bag sorts into the normal categories. Its free slots count as free and fade while you hold something that isn't a reagent
- Bags: quiver and ammo pouch no longer get their own row of empty slots, one slot at the end of Ammo shows how many are free

## v0.5.3
- The damage meter background is now see-through, so it covers less of the game. Bars, names and numbers stay fully visible
- The XP bar and the pet XP bar are slimmer and slightly see-through

## v0.5.2
- New option "3D portrait in the health bar" (Unit frames page, off by default). Your character and your target appear faintly inside their health bars, zoomed to the head and facing inward. The model only shows over the health you have, so the missing part stays easy to read

## v0.5.1
- Fixed: a Lua error in combat when the threat of your target's target changed (nameplate colours)
- Fixed: Blizzard's trainer window no longer flashes up for a moment before the mUI trainer opens

## v0.5.0
- A whole new look for mUI. Warm dark panels, a deep window frame with a lit edge, Cinzel titles, gems for active tabs and bevelled buttons. Choose iron (default) or bronze for the frame material and Cinzel or the mUI font for headings
- Unit frames, group frames, nameplates, cast bars, auras, the minimap, the XP bar, the class bar and the action buttons all follow the new look, with shaded bars in thin shells and item frames around icons
- Every mUI window (merchant, quests, trainer, professions, auction house, talents, collections, maps, damage meter, bags, bank, mail, fishing bag) and the skinned Blizzard windows (guild, calendar, macros, group finder, game menu and more) use the same frames, buttons, tabs, fields and scrollbars
- Action bar end caps can show Blizzard's gryphons, an animal for your class, or nothing
- New tooltips with an item or class icon in a frame, Cinzel names, faction and classification on one line and a slim health bar. Lines other addons add get a divider, and long item texts wrap again
- New level-up display that lists the trainer spells waiting for you and the class quests you can start
- Class trainer help for every class. A new spellbook tab lists the spells still to learn, the trainer marks recommended spells and ones you can skip, and spell tooltips explain why
- Class quests in the character window, grouped by chain with their state. Click a quest to put a pin on the map. Quests only one of which can be done show as a single row
- Chat got new extras. The arrow keys move the cursor without Alt, and up and down bring back what you sent (also slash commands and Battle.net whispers) even after a reload. Hovering an item, spell or quest link shows its tooltip, and Ctrl or Shift with the mouse wheel jumps to the top or bottom or scrolls a page
- Chat Comfort extras. "inv" in a message becomes a link that invites the player (or asks to join when they are looking for more), the same message from the same player in public channels shows only once every 3 minutes, and known player levels appear at their names. Each can be turned off on the Chat page
- Bagnon, Details, DBM, BigWigs and Plater follow the new look as well
- Windows fade in when they open, and opening a window while the game menu is up now closes the menu instead of pushing it aside
- Bags show a square glow on new items, and the sparkle setting moved to the Bags page
- Better performance in groups and raids (status icons, info bar, action bars, nameplate threat colours)
- The "Skip single conversation options" helper was removed
- Fixed: the logout popup no longer grows every second
- Fixed: action bars on mouseover stay hidden while a window in front of them has the mouse
- Fixed: the chat input box stays hidden while you are not typing

## v0.4.7
- Repairs are now paid from your own gold by default. The guild bank is only used if you turn on the new "Repair from the guild bank" setting (Bags page)
- Fixed: on new characters the setup now opens after the intro cinematic instead of being closed by it
- Fixed: with Questie 12.8 the direction arrow in the quest tracker and Questie's icons on the mUI map work again
- Item tooltips no longer list every character for the Hearthstone
- Bags and bank show your gold like the info bar, and hovering it lists the gold of all your characters
- Bags: the bag slots are grouped (normal bags, special bags, reagent bag) with a small gap between the groups
- Bags: empty slots of special bags are headed with the bag's own name (e.g. your ammo pouch) instead of "Quiver"

## v0.4.6
- Character window: item name, item level and enchant next to every gear slot, and the window is wider. The inspect window shows the same
- Bags: every free slot is shown at the bottom across the full width, so you can drop items straight onto a free slot
- Bags: sections flow left to right and wrap, so the window is narrower and has no gaps
- Bags: quest items get a gold border, hearthstones a sage one, and Uncommon and better items a thicker quality border (bank and guild bank too). Borders stay visible on items with a cooldown
- Bags: the "One big bag" layout was removed, there is only the section layout now
- Fixed: class icons in chat grow with the chat font size again

## v0.4.5
- Player buffs start at the right edge of the player frame again and grow to the left. The shortest-running buff sits on the right; when the row is full, the longest-running ones drop out
- Questie: its quest icon on nameplates sits right next to the mUI bar and stays visible on your target

## v0.4.4
- Auction house: new "Scan auction house" button in the Buy tab with a progress bar – saves the cheapest price of every item (Blizzard allows a scan every 15 minutes). Searches and the Sell tab update prices too
- Item tooltips show the auction house price (×stack with the total). Red when a vendor pays more. Can be turned off on the Tooltip page (Comfort)
- Selling: copper prices for single items, and undercut buttons 0 % / 1 % / 5 % / 10 % – by default 1 copper below the cheapest instead of 1 silver
- Auction history, last used prices and scanned prices are now kept per server and faction, and characters with the same first name are told apart
- Quest tracker: sorted by level by default (the focus quest stays on top). The old order is still there as "Current zone first"
- Quest tracker: with "Collapse finished quests" the focus quest stays open, so you keep its arrow and distance
- Questie: its quest icon on nameplates sits right next to the mUI bar and no longer jumps when you target the unit

## v0.4.3
- Chat: new size setting (Small / Medium / Large) on the Chat page – Medium is the size you had so far, Large gives you a lot more room
- Fixed: rogue Poisons were missing in the professions window
- Removed the "Back to Blizzard" button again: mUI's game settings are temporary now, so there is nothing left to reset

## v0.4.2
- Game settings mUI needs for its look (nameplates, chat style, camera zoom, sparkle ...) are now only set while mUI runs and no longer saved by the game – if you remove mUI, your own settings are back on the next start
- mUI no longer changes the "always compare items" setting
- Item comparison: tiny differences (e.g. only a little stamina) show as "Slightly better" or "Slightly worse"
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
- Fixed: the right border of fields in the settings window was cut off
- Fixed: gryphon artwork in the wrong place after a reload in combat

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
