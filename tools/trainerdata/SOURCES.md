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

