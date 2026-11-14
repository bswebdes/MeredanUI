# Sources

Research data for trainer spells and class quests in WoW Forever. Date checked: 2026-11-14.
`SOURCES.md` is generated from this template by `build_trainer_spells.py` (the per-class part comes from
`advice/<CLASS>.json`). Edit this template, not `SOURCES.md`.

## Game data

| What | Source | Build / version |
|---|---|---|
| Spell IDs, names, ranks, spell level, school, tree | WoW Forever client tables via [wago.tools](https://wago.tools/db2) (product `wowf`): `SpellName`, `Spell` (rank text), `SpellLevels`, `SpellMisc` (school), `SkillLineAbility`, `SkillLine` | 1.60.1.70938 (newest Forever build on 2026-11-14) |
| Which spells each class trainer teaches, trainer level, cost | [WhatsTraining](https://github.com/fusionpit/WhatsTraining) addon, `forever` branch, `Classes/Camelot/*.lua` (MIT license). Costs are base prices before reputation discount. | commit `dd42564` (2026-11-03) |
| Spells learned from class quests (spell <- reward quest) | WhatsTraining `forever` branch, `Classes/Camelot/QuestSpells.lua` | commit `dd42564` |
| Class quests: IDs, chains, levels, races, start NPCs, coordinates, German names | [Questie database](https://github.com/Questie/QuestieDB), Forever data and corrections (same file list as `tools/build_class_quests.py`) | commit `4dbb824` |
| Spot checks of spell IDs (name + required level) | Wowhead Forever tooltips `nether.wowhead.com/forever/tooltip/spell/<id>`, results in `wowhead_check.txt` | live, 2026-11-14 |
| Official class changes | Blizzard news: [Mage and Shaman deep dive](https://worldofwarcraft.blizzard.com/en-us/news/24302097/world-of-warcraft-forever-class-deep-dives-mage-and-shaman), [Priest and Warrior deep dive](https://worldofwarcraft.blizzard.com/en-us/news/24301514/world-of-warcraft-forever-class-deep-dives-priest-and-warrior), [Hunter and Druid deep dive](https://worldofwarcraft.blizzard.com/en-us/news/24301515), [Rogue and Warlock deep dive](https://worldofwarcraft.blizzard.com/en-us/news/24310968/world-of-warcraft-forever-class-deep-dives-rogue-and-warlock), [Beta development notes](https://us.forums.blizzard.com/en/wow/t/2360696/1) | 2026-09 to 2026-11 |

How the sources were checked against each other:

- Every trainer entry was matched against the Forever client: the spell must have a name in the client and the
  client `SpellLevels` must match the trainer level. Entries without a client name (spells removed in Forever, e.g.
  Paladin Blessing of Salvation / Light, Fire Nova Totem) are dropped. Remaining level differences are listed in
  `checks.txt`.
- A random sample of spell IDs per class was compared with Wowhead Forever (`wowhead_check.txt`).
- Training costs have only one Forever source (WhatsTraining, scanned from the live trainers). Wowhead pages
  that show training costs could not be read by a script. Treat costs as good but single-sourced.
- Trainer data is not in the game client (no Trainer table in the readable DB2 files), so the trainer list itself
  also depends on WhatsTraining. The client agrees on every spell name and nearly every level.

## Known limits (all classes)

- Hunter pet skills (Great Stamina, Natural Armor, resistances ...) are listed with `learnedFrom = "pettrainer"`
  (sold by the pet trainer). Warlock demon tomes (vendor books for pet spells) are not included.
- Class quests from the Questie Forever data include endgame chains (tier 0.5, Zul'Gurub, AQ, Naxxramas class
  quests). Some of that content may not be open yet in Forever; they are marked `category = "endgame"`.
- The totem items from the Shaman element quests are taken from Classic Era rules (`verified = "classic_era"` on
  that unlock); the Forever sources do not say whether the totem items are still needed.
- Leveling advice for new Forever spells relies on early Forever guides (written during beta/launch week).

## Warrior

Leveling advice sources (read 2026-11-14):

- [World of Warcraft: Forever Class Deep Dives - Priest and Warrior](https://worldofwarcraft.blizzard.com/news/24301514) (official)
- [Warcraft Tavern - WoW Forever Warrior Leveling Guide](https://www.warcrafttavern.com/forever/guides/warrior-leveling/) (forever_guide)
- [Method.gg - WoW Forever Warrior Leveling Guide and Talents](https://www.method.gg/wow-forever/wow-forever-warrior-leveling-guide-and-talents) (forever_guide)
- [Warcraft Tavern - WoW Classic Warrior Leveling Guide](https://www.warcrafttavern.com/wow-classic/guides/warrior-leveling-guide/) (classic_guide)

**Forever differences that matter for training**

- Tactical Mastery (keep 10 rage) is baseline at 14; the talent became Improved Tactical Mastery (Blizzard deep dive).
- Victory Rush is new baseline at 20: instant, 30 s cooldown, heals 10% max health after a kill (Blizzard deep dive).
- Rend and Thunder Clap gained significant AP scaling; Thunder Clap usable in Defensive Stance with 6 s cooldown (Blizzard deep dive).
- Retaliation, Shield Wall and Recklessness no longer share cooldowns; Retaliation/Shield Wall cooldown 15 min (Blizzard deep dive).
- Battle Shout AP reduced but includes Improved Battle Shout; Improved Demoralizing Shout baseline (Blizzard deep dive).
- Sunder Armor threat scales with AP (Blizzard deep dive); rank 1 comes from the Defensive Stance quest (Method.gg).
- Rage from damage dealt is based on weapon speed; crits give 75% more rage (Blizzard deep dive).
- Bloodthirst no longer heals, grants 10% move speed instead (Blizzard deep dive).
- Slam rank 1 at 20 uses a new spell ID; Improved Slam (Arms) makes Slam not reset swing timer (Blizzard deep dive).

**Guide disagreements**

- Whirlwind: Warcraft Tavern Forever calls it strong for leveling in any spec vs several mobs; Method.gg calls it underwhelming solo but strong in groups.
- Warcraft Tavern Classic says train only rank 1 of Thunder Clap, Cleave, Overpower and Shield Bash, but its own level list later buys Overpower ranks 2-3.
- Warcraft Tavern Classic says skip Mocking Blow but also lists it at level 16.
- Rend: Classic guides did not prioritise Rend ranks; Forever gives Rend significant AP scaling (Blizzard, Method.gg), so ranks are recommended here.

**Open questions**

- Intercept rank 1 is not on the trainer list (ranks 2-3 are); presumably granted by the Berserker Stance quest at 30.
- Defensive Stance, Berserker Stance, Taunt and Sunder Armor rank 1 are not on the trainer list; quest-granted per Method.gg.
- No Forever guide read gives rank-by-rank skip advice; rank skips follow Classic guidance.

## Paladin

Leveling advice sources (read 2026-11-14):

- [Blizzard - Paladin: Champions of the Light (WoW Forever class deep dive)](https://worldofwarcraft.blizzard.com/en-us/news/24302099) (official)
- [Warcraft Tavern - Seal Twisting & Shockadins: Paladin Deep Dive for WoW Forever](https://www.warcrafttavern.com/forever/news/seal-twisting-shockadins-paladin-deep-dive-for-wow-forever/) (other)
- [Warcraft Tavern - WoW Forever Paladin Leveling Guide](https://www.warcrafttavern.com/forever/guides/paladin-leveling/) (forever_guide)
- [Method.gg - WoW Forever Paladin Leveling Guide and Talents](https://www.method.gg/wow-forever/wow-forever-paladin-leveling-guide-and-talents) (forever_guide)
- [Warcraft Tavern - WoW Classic Paladin Leveling Guide](https://www.warcrafttavern.com/wow-classic/guides/paladin-leveling-guide/) (classic_guide)

**Forever differences that matter for training**

- Holy Strike is a baseline instant attack learned at 6 (Blizzard deep dive).
- Judgement no longer consumes the seal (Blizzard deep dive) and is off the GCD (Method.gg).
- Seal of Fury is a new tank seal at 10; its Judgement taunts from 10 yards (Blizzard deep dive).
- Consecration (20) and Blessing of Kings (20) are baseline; Improved Blessing of Wisdom baseline (Blizzard deep dive).
- Lay on Hands cooldown 20 min, was 60 (Blizzard deep dive).
- Holy Shock moved to 21-point talent with 10 s cooldown; new Light's Vigil 31-point talent (Blizzard deep dive).
- Sanctity Aura and Blessing of Sanctuary removed; resistance auras affect the whole raid within 30 yd (Blizzard deep dive).
- Salvation is no longer a Blessing (Mass Salvation); not on the trainer list (Blizzard deep dive).
- Spell power scales Retribution Aura and seal Holy damage (Warcraft Tavern Forever).
- Holy Light rank 1 and Seal of Righteousness rank 1 are not on the trainer list (starting spells); Redemption rank 1 from class quest (Warcraft Tavern Forever).

**Guide disagreements**

- Blessing choice: Warcraft Tavern Classic prefers Blessing of Wisdom over Might (less drinking); Forever guides (Warcraft Tavern, Method.gg) say choose by spec, with Might/Kings for melee.
- Aura: Warcraft Tavern Classic buys every Devotion Aura rank; Warcraft Tavern Forever names Retribution Aura the main leveling aura.
- Consecration: Warcraft Tavern Forever uses it on cooldown for Protection/Shockadin; Method.gg says use it conservatively in open world because of mana.
- Instrument of the Law: Warcraft Tavern's summary says it makes Holy Wrath instant; Blizzard's post (as fetched) says it reduces Hammer of Wrath cast time.

**Open questions**

- Whether Exorcism and Holy Wrath are still restricted to undead/demons in Forever is not stated in the sources read; advice kept 'optional'.
- Seal of Command, Seal of Light, Seal of Wisdom, Seal of Justice, Turn Undead and Greater Blessings are not covered by the Blizzard post; Classic behavior assumed.
- No Forever guide read gives rank-by-rank skip advice; rank skips follow Classic guidance.

## Hunter

Leveling advice sources (read 2026-11-14):

- [World of Warcraft: Forever Class Deep Dives - Hunter and Druid](https://worldofwarcraft.blizzard.com/news/24301515) (official)
- [Method.gg - WoW Forever Hunter Leveling Guide and Talents](https://www.method.gg/wow-forever/wow-forever-hunter-leveling-guide-and-talents) (forever_guide)
- [Warcraft Tavern - WoW Forever Hunter Leveling Guide](https://www.warcrafttavern.com/forever/guides/hunter-leveling/) (forever_guide)
- [Warcraft Tavern - WoW Forever Hunter Guide](https://www.warcrafttavern.com/forever/guides/hunter/) (forever_guide)
- [Warcraft Tavern - WoW Classic Hunter Leveling Guide](https://www.warcrafttavern.com/guides/wow-classic-hunter-leveling-guide/) (classic_guide)
- [Blizzard forums (Classic) - Hunter skills and gold](https://us.forums.blizzard.com/en/wow/t/hunter-skills-and-gold/266973) (other)

**Forever differences that matter for training**

- Aimed Shot is baseline at 20 (no talent) and shares its cooldown with Multi-Shot; Arcane Shot no longer does (Blizzard deep dive).
- Improved Hunter's Mark and Improved Eyes of the Beast are baseline (Blizzard deep dive).
- Traps usable in combat on a 30s cooldown; fire and frost traps have separate cooldowns (Blizzard deep dive).
- Aspect of the Beast now grants melee attack power (melee Survival aspect) (Blizzard deep dive).
- Scorpid Sting now reduces target hit chance by 2% instead of Str/Agi (Blizzard deep dive, Warcraft Tavern).
- New talent abilities with trainer ranks: Summon Hawk (BM, shares cooldown with Arcane Shot), Sniper Shot (MM), Trueshot Aura moved to a 21-point talent with lower ranks, Counterattack 16-point talent (Blizzard deep dive).
- Disengage threat reduction doubled; pets scale from hunter gear and no longer take player stat buffs (Blizzard deep dive).
- Improved Tracking (Survival) increases damage vs the creature type you track (Blizzard deep dive, Warcraft Tavern).

**Guide disagreements**

- Arcane Shot: Method calls it near redundant after 25 (except long fights); Warcraft Tavern Forever still lists it in every rotation.
- Raptor Strike: Method says it loses almost all value after 10 (kite instead); Warcraft Tavern Forever uses it in melee range and for Survival.
- Multi-Shot (Classic forum): one poster says skip while leveling, others call it a top damage ability; Forever guides treat it as core AoE.
- Scorpid Sting: Warcraft Tavern Classic says skip; a Classic forum poster says train it. Forever changed it to -2% hit chance.
- Tracking: Classic guides skip most tracking; in Forever Survival's Improved Tracking adds damage vs the tracked type, so Survival may want them.

**Open questions**

- Multi-Shot appears only once (no ranks) in the Forever trainer list; whether it scales with level was not confirmed by a guide.
- Icy Veins and Mobalytics Forever hunter guides returned 403 and could not be read.
- No source covers whether pet resistance training (Arcane/Fire/Frost/Nature/Shadow Resistance) matters in Forever dungeons.

## Rogue

Leveling advice sources (read 2026-11-14):

- [World of Warcraft: Forever Class Deep Dives - Rogue and Warlock](https://worldofwarcraft.blizzard.com/en-us/news/24310968) (official)
- [Warcraft Tavern - Poison & Pets: Rogue & Warlock Deep Dive for WoW Forever](https://www.warcrafttavern.com/forever/news/poison-pets-rogue-warlock-deep-dive-for-wow-forever/) (other)
- [Method.gg - WoW Forever Rogue Leveling Guide & Talents](https://www.method.gg/wow-forever/wow-forever-rogue-leveling-guide-and-talents) (forever_guide)
- [Warcraft Tavern - WoW Forever Rogue Leveling Guide](https://www.warcrafttavern.com/forever/guides/rogue-leveling/) (forever_guide)
- [Warcraft Tavern - WoW Classic Rogue Leveling Guide](https://www.warcrafttavern.com/wow-classic/guides/rogue-leveling-guide/) (classic_guide)
- [Esports.net - WoW Classic Rogue Leveling Guide](https://www.esports.net/news/wow/classic-rogue-leveling-guide/) (classic_guide)

**Forever differences that matter for training**

- Sap no longer breaks Stealth (Blizzard deep dive).
- Expose Armor reduction raised to about 5 Sunder Armors and no longer blocks Sunder (deep dive) - more useful on long fights.
- Feint threat reduction doubled; Distract also lowers enemy stealth detection (deep dive).
- Poisons have more charges, can crit and stack with sharpening stones/Windfury (deep dive, Warcraft Tavern Forever).
- Mutilate is a new 21-point Assassination talent with trainer ranks at 40/50/60 (deep dive).
- New baseline Energy builder Shank; rogues can use one-handed axes (Warcraft Tavern Forever, deep dive).
- Weapon specializations removed; Combat's Hack and Slash works with any weapon (deep dive).

**Guide disagreements**

- Slice and Dice: Warcraft Tavern Classic says not worth using until 42; Method (Forever) calls it the main finisher and high priority, Warcraft Tavern Forever keeps it up in every spec.
- Backstab: Warcraft Tavern Classic says you can hardly use it solo (mobs face you); Method (Forever) says it beats Sinister Strike with daggers and is easier in groups.
- Garrote: Warcraft Tavern Classic sword build trains every rank; its dagger build skips it. In Forever it is core for Subtlety bleed builds only.

**Open questions**

- Blind and poisons are not in the Forever trainer list; guides still mention them (likely quest/vendor learned).
- No source covers what Stealth ranks 2-4 or Vanish rank 2 change in Forever.
- Icy Veins and Mobalytics Forever rogue guides returned 403 / were not readable; Wowhead Classic guide is JS-rendered.

## Shaman

Leveling advice sources (read 2026-11-14):

- [World of Warcraft: Forever Class Deep Dives - Mage and Shaman](https://worldofwarcraft.blizzard.com/news/24302097) (official)
- [Warcraft Tavern - WoW Forever Shaman Leveling Guide](https://www.warcrafttavern.com/forever/guides/shaman-leveling/) (forever_guide)
- [Method.gg - WoW Forever Shaman Leveling Guide and Talents](https://www.method.gg/wow-forever/wow-forever-shaman-leveling-guide-and-talents) (forever_guide)
- [Warcraft Tavern - WoW Forever Enhancement Shaman Guide](https://www.warcrafttavern.com/forever/guides/enhancement-shaman/) (forever_guide)
- [Warcraft Tavern - WoW Classic Shaman Leveling Guide](https://www.warcrafttavern.com/wow-classic/guides/shaman-leveling-guide/) (classic_guide)

**Forever differences that matter for training**

- Weapon imbues last 60 min (was 5) and stack with stones/oils (Blizzard deep dive).
- Fire Nova Totem removed; new Fire Nova spell erupts from your current fire totem and can be reused (Blizzard deep dive); threat goes to you (Method.gg).
- Windfury Totem and Flametongue Totem are party buffs, no longer weapon enchants; you don't benefit while using the matching weapon imbue (Blizzard deep dive).
- Persistent buff totems last 5 min, totem GCD 1.0 s, resistance totems apply raid-wide (Blizzard deep dive).
- New Call of the Elements (20), Totemic Recall (20), Totemic Projection (22) and extra totem sets; Blizzard listed Call of the Spirits at 30 and Call of the Ancestors at 40, the trainer list has Ancestors at 30 and Spirits at 40.
- Lightning Bolt rank 4+ casts in 2.5 s and Chain Lightning in 2.0 s (Blizzard deep dive).
- Lava Burst, Riptide, Stormstrike, Mana Tide are talent spells; Stormstrike moved to 16-point tier (Blizzard deep dive).
- Astral Recall is a second hearthstone with 15 min cooldown (Warcraft Tavern Forever).
- Lightning Bolt/Healing Wave rank 1, Searing/Stoneskin/Healing Stream Totem rank 1 are not on the trainer list (granted baseline or via class quests per Warcraft Tavern Forever).

**Guide disagreements**

- Classic guide (Warcraft Tavern Classic) suggests dropping Lightning Bolt from 10-29 for mana and saving Earth Shock for interrupts; Forever guides (Warcraft Tavern Forever) pull with Lightning Bolt and use Earth Shock as filler.
- Method.gg: use Rockbiter Weapon through level 30, then Windfury on a two-hander; Warcraft Tavern Forever lists Windfury Weapon or Rockbiter as the maintained imbue (Rockbiter mainly for tanking threat).
- Warcraft Tavern Classic says learn everything 1-20; no Forever guide gives a rank-skipping list, so rank advice here follows general practice.
- Elemental viability: Warcraft Tavern Forever says Elemental balance is in flux and mana-heavy; both Forever guides recommend Enhancement for solo leveling.

**Open questions**

- Trainer list names spell 437009 'Totemic Call' at 22; Blizzard calls the level-22 spell 'Totemic Projection' (moves totems, 25% base mana). Assumed same spell.
- Blizzard noted a beta bug where Totemic Recall did not refund mana; unclear if fixed at launch.
- Flametongue Weapon value for Enhancement dual wield in Forever is not covered by the guides read.

## Mage

Leveling advice sources (read 2026-11-14):

- [Warcraft Tavern - WoW Forever Mage Leveling Guide](https://www.warcrafttavern.com/forever/guides/mage-leveling/) (forever_guide)
- [Method.gg - WoW Forever Mage Leveling Guide and Talents](https://www.method.gg/wow-forever/wow-forever-mage-leveling-guide-and-talents) (forever_guide)
- [Warcraft Tavern - Scrolls & Totems: Mage & Shaman Deep Dive for WoW Forever (summary of Blizzard deep dive)](https://www.warcrafttavern.com/forever/news/scrolls-totems-mage-shaman-deep-dive-for-wow-forever/) (official)
- [hostedgg - WoW Forever Mage, Shaman, Rogue, Warlock kits (summary of Blizzard deep dives)](https://hostedgg.com/blog/wow-forever-mage-shaman-rogue-warlock-kits) (other)
- [Metabot - WoW Forever Mage changes (spell data diff vs Classic)](https://metabot.gg/en/wow-forever/changes/mage) (other)
- [Metabot - Arcane Wrath ability](https://metabot.gg/en/wow-forever/abilities/mage-arcane-wrath) (other)
- [Kami-labs - WoW Forever Mage: every reworked spell and talent](https://kami-labs.fr/en/wow-forever/mage-wow-forever-sorts-et-talents-modifies/) (other)
- [RankedBoost - Mage Downranking in WoW Forever](https://rankedboost.com/world-of-warcraft/forever/downranking/mage/) (other)
- [dtgre - WoW Forever spell training too expensive? What to buy, skip & save gold](https://www.dtgre.com/2026/11/wow-forever-spell-training-too-expensive-save-gold.html) (other)
- [Warcraft Tavern - WoW Classic Mage Leveling Guide](https://warcrafttavern.com/guides/mage-leveling-guide) (classic_guide)

**Forever differences that matter for training**

- Detect Magic is no longer trainable (Metabot changes).
- Arcane Intellect lasts 1 hour instead of 30 min (Metabot changes).
- New trainer spells: Frost Blast (24, weak frost attack with 40% slow), Frostfire Bolt (40, counts as Fire and Frost, 3s cast), Comprehend Scroll (6, Comprehension minor tradeskill) (Warcraft Tavern deep dive, Metabot).
- Ice Lance (Frost) and Arcane Blast (Arcane) are 11-point gold-medal talents; Ice Lance has an 8s cooldown and does 300% vs frozen targets; Arcane Blast stacks to 4, raising its mana cost and buffing other spells (Warcraft Tavern deep dive, Method, Metabot).
- Arcane Wrath is new (talent-gated, 3.5s cast, 6s CD, bonus damage from 5% max mana) (Metabot ability page).
- Cone of Cold duration 8 -> 6s, slow 50 -> 40%; Improved Blizzard max slow 65 -> 40%; Cold Snap CD 5 -> 10 min (deep dive via Warcraft Tavern/hostedgg, Metabot).
- Base damage of Fireball, Frostbolt, Scorch, Pyroblast etc. lowered while spell power scaling is higher (Metabot, Kami-labs) - higher ranks matter somewhat less, gear matters more.
- Arcane Concentration and Impact proc less when casting much lower-rank spells, which weakens downranking (deep dive via Warcraft Tavern).
- Mage Armor: mana regen from Spirit increased; Arcane Shielding also boosts Mage Armor resistances (deep dive via Warcraft Tavern).
- Dampen Magic healing reduction halved; Amplify Magic healing +50% (Metabot changes).
- Talents start at 10; Dual Specialization at 40 (deep dive via Warcraft Tavern).

**Guide disagreements**

- Blizzard: Method lists 'Blizzard slow nerfed in Forever' as a mage weakness; Warcraft Tavern Forever still recommends Blizzard for group AoE. Mobalytics (Kargoz, search summary only) says the mage AoE toolkit is dialed back, while Kami-labs expects Cone of Cold / Flamestrike / Frost to 'melt monster packs' thanks to spell power gear.
- Arcane timing: Warcraft Tavern Forever presents Arcane as a leveling spec (rush Missile Barrage); Method levels Frost to 42 and only takes Arcane Blast at 57; Mobalytics (search summary only) suggests Frost until 25 then respec Arcane.
- Ice Lance learn level: Warcraft Tavern and Metabot say rank 1 at level 20 (talent); the trainer list only shows ranks 2+ starting at 28.
- Arcane Wrath: Metabot says learned at level 25 (trainer); the trainer list shows it as talent-gated with rank 2 at 36. Warcraft Tavern says 'Talent Tree, level 25'.
- Classic Warcraft Tavern says train every skill 1-20; single-target Frost builds there skip Dampen Magic, Slow Fall, Flamestrike, Amplify Magic, Fireball and Blizzard past rank 1.

**Open questions**

- Frost Blast: cast time / cooldown not confirmed by a second source; no leveling guide covers it yet.
- Frostfire Bolt vs Frostbolt for Frost leveling after 40 is not compared by any guide read.
- Teleport: Dalaran (level 50 per Metabot/Kami-labs) is not on the trainer list.

## Warlock

Leveling advice sources (read 2026-11-14):

- [Warcraft Tavern - WoW Forever Warlock Leveling Guide](https://www.warcrafttavern.com/forever/guides/warlock-leveling/) (forever_guide)
- [Method.gg - WoW Forever Warlock Leveling Guide and Talents](https://www.method.gg/wow-forever/wow-forever-warlock-leveling-guide-and-talents) (forever_guide)
- [Blizzard - World of Warcraft: Forever Class Deep Dives - Rogue and Warlock](https://worldofwarcraft.blizzard.com/news/24310968) (official)
- [hostedgg - WoW Forever Mage, Shaman, Rogue, Warlock kits](https://hostedgg.com/blog/wow-forever-mage-shaman-rogue-warlock-kits) (other)
- [Metabot - WoW Forever Warlock changes (spell data diff vs Classic)](https://metabot.gg/en/wow-forever/changes/warlock) (other)
- [dtgre - WoW Forever spell training too expensive? What to buy, skip & save gold](https://www.dtgre.com/2026/11/wow-forever-spell-training-too-expensive-save-gold.html) (other)
- [Warcraft Tavern - WoW Classic Warlock Leveling Guide](https://warcrafttavern.com/guides/warlock-leveling-guide) (classic_guide)

**Forever differences that matter for training**

- Curse of Agony and Curse of Doom are now Banes (Bane of Agony, Bane of Doom); one Bane per warlock per target and it does not block a Curse, so utility Curses can run alongside (Blizzard deep dive).
- Curse of Shadows removed; Curse of the Elements now affects all magic damage and is learned at 20 instead of 8 (Blizzard deep dive, Metabot).
- Dark Pact removed (talent); Inferno, Ritual of Doom and Portal of Summoning are not on the 1-60 trainer list (Metabot, Warcraft Tavern says Inferno/Ritual of Doom not needed).
- Firestone and Spellstone are now weapon imbues that stack with Wizard Oil: Firestone = Fire damage + crit, Spellstone = Shadow damage + spell haste (Blizzard deep dive).
- Drain Soul has a progressive per-tick chance to give a Soul Shard (Blizzard deep dive); rank 1 finishing still reliable (Warcraft Tavern).
- Life Tap scales with Spirit (Blizzard deep dive).
- Demons scale from the warlock's stats; demons are still earned by class quests (Blizzard deep dive, Warcraft Tavern).
- Shadowburn (talent) now lasts 8s and has 30 yd range; Conflagrate and Incinerate are talent spells with trainer ranks (Metabot, Blizzard deep dive).
- Base damage of Shadow Bolt, Immolate, Corruption, Searing Pain, Soul Fire etc. is ~40-50% lower while spell power scaling is higher (Metabot).
- Meeting Stones no longer summon, so Ritual of Summoning is the only summon (Warcraft Tavern Forever).
- Talents start at 10; Dual Specialization at 40 (Blizzard deep dive).

**Guide disagreements**

- Soul Fire: Method treats it as a Demonology talent finisher; the trainer list and Metabot show it as a baseline trainer spell at 48 (Decimation talent reduces its cooldown per Blizzard).
- Conflagrate/Shadowburn levels: Warcraft Tavern says Shadowburn at 20 and Conflagrate at 25; Method's build takes Shadowburn at 24 and Conflagrate at 29 (both are talents, so it depends on the build).
- Curse of the Elements: Classic Warcraft Tavern lists it as skip until 60; Forever Warcraft Tavern adds it to the Affliction rotation at 40 (Banes no longer share the curse slot).
- Drain tanking: Method says it becomes available at 20 but recommends starting at 30.
- Spec choice: Method and Kargoz (Mobalytics, search summary only) favor Affliction; Kargoz also calls Demonology possibly one of the strongest; Icy Veins (search summary only) calls Destruction weak early.

**Open questions**

- Value of Create Firestone/Spellstone imbues vs Wizard Oil for leveling is not quantified by any guide read.
- Curse of Weakness / Curse of Recklessness effect values look much lower in Metabot data; their worth next to a Bane is untested in guides.

