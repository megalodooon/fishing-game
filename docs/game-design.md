# Game design overview

How the game fits together after the 2026-09-30 overhaul: what each system is for, how it ties into
progression, and where to change it.

## Controls

| Key | Opens |
|---|---|
| Tab | All menus (reopens the last one) |
| E | Bag |
| T | Tacklebox |
| J | Journal |
| R | Recipe book (in the bag or the book: R over an item shows every recipe that uses it) |
| K | Skills, Angler Level, Tide Tree, achievements and stats |
| O | Charm pouch |
| L | Collections |
| Q | Quests |
| C | Calendar |
| P | Pets |
| M | Sea chart |
| Esc | Pause (resume, settings, save) |
| 0 | Developer menu (cheats, including "Start: <festival>") |

While any of these is open, a strip of tabs across the top switches between them.

## Free play: how things open up

Nothing waits on the story except its own finale (the Deepnet Rig and the Abyssal Trench).
Everything else opens through play:

- **Places** need a skill level, a hull tier and a charter fee (see each `world/locations/*.tres`:
  `requiredSkill`, `requiredLevel`, `requiredHull`, `coinCost`, `requiredLeague`). Story quests still
  hand out free passes as rewards, so following the story is a fast lane, not the only lane.
- **Skills** (Fishing, Farming, Cooking, Sailing, Hunting, Trading, Foraging, Crafting, Alchemy) give a
  perk and coins every level. The Skills menu is a grid of all nine; click one for its level road,
  every level with what it unlocks: places, recipes, quests, shop stock, village projects, sea
  creatures and rare catches. It's built from the content, so anything with a `requiredSkill` shows
  up there on its own. Side quests are gated by skill levels too, so the quest log starts small.
- **Angler Level** (like the SkyBlock Level): one number for everything done. Skill levels,
  collection tiers, fish found, creatures beaten, quests, pearls, rare catches, crew tiers, Magical
  Power, recipes and festivals give Angler XP (100 per level). Each level adds max energy, every 3rd a
  charm pouch slot, every 5th a crew slot. See `player/angler_level.gd`.
- **Collections**: every fish, creature and item counts up to four tiers; tiers pay coins and XP and
  teach recipes. The collection case (L) shows each tier and what it teaches.
- **Village projects** (restoration board) need coins, materials and sometimes a skill level.

## What each system is for

| System | Role | Where |
|---|---|---|
| Tackle Shop | Gear bought with coins, in tiers with one price per tier. Tier II opens at Fishing 5, III at 12, IV at 20. | `world/village/shop/stock/tackle_shop.tres` |
| Fishmonger (Gus) | Buys the catch at market prices, sells chum, and posts three **Harbor Orders** a day that pay well above market (all three add a crate). | `world/village/shop/daily_orders.gd` |
| Market Hall | Seeds, supplies, three discounted deals a day. | `stock/general_store.tres` |
| Sunday stalls | Rare bait and charms; farm goods and rare seeds. | `stock/sunday_rare.tres`, `stock/sunday_farm.tres` |
| Vending machine | Snacks for energy. | village scene |
| Recipe book + stations | All crafting. Hand recipes anywhere; workbench, kitchen, forge (Brann, Ember Isle) and cauldron (Moss, Mangrove Hollow) recipes at their station or with its portable kit (Tinker's Kit, Camp Stove, Field Anvil, Travel Cauldron). Hover an ingredient to see where it comes from; pin a recipe to track it on the HUD. | `items/recipes/` |
| Reforge anvil | Rerolls a rod's reforge (a name prefix plus stats) for coins; rare stones give special reforges. Beside the village workbench and at Brann's. | `fishing/reforges/` |
| Bag upgrades | Crafted satchels, packs, duffels and trunks add backpack slots for good. | `items/tools/` |
| Rare catches | Every fishing ground has rare things that come up with fish (sea glass, doubloons, mermaid's combs, Tide relics...). Each has a luck meter in the journal that guarantees it after enough catches. Relics craft into top charms. | `items/rare_drops/` |
| Festivals | One per season on the calendar (C): Blossom Derby, Starfall Night, Spooky Tide, Gift Tide. Festival fish bite everywhere, catches bring up festival things, pickups lie on every island each day, and the host's stall in the village square sells festival gear for festival currency. | `world/events/` |
| Forage | Every island's ground has things to pick up (shells, salt, sand, berries, feathers, roots, lichen, pumice, storm glass, deep coral...), new spots every day. Picking them up trains Foraging. Each island biome has a `forage` list. | `world/events/forage_node.gd` |
| Crew | Hired helpers (like SkyBlock minions) who gather one material while you're away, up to what they can hold; collect at the crew board by the house. Contracts are crafted after a collection tier; tiers II-VII cost that material (then its enchanted form) and make them faster with more storage. New tiers of different members open more crew slots. | `world/crew/` |
| Bazaar | Beside the Market Hall once it's restored: buy and sell every material, crop and enchanted material you've found, any time, at prices that drift daily. | `world/village/shop/bazaar.gd` |
| Enchanted materials | 32 of a material (16 for rare ones) press into its enchanted form, taught by that material's collection tier II. Better rods, tackle, charm upgrades, potions and crew tiers ask for them. | `items/enchanted/` |
| Charm pouch | Charms come in families that upgrade: charm, ring, artifact, relic (16 families). Only the best of a family counts. Charms in the pouch add Magical Power by rarity, which turns into luck, rare find and XP. Pouch slots grow with the Angler Level and Pouch Stitching. | `items/charms/charm_pouch.gd` |
| Potions | Brewed at the cauldron from a Glass Bottle (sand, or two broken bottles) and ingredients; they give hours of a stat. The Alchemy skill makes them last longer. | `items/potions/` |
| Harbor Council | A ballot box in the square: each week one of three villagers holds the seat and their perk helps all week. Vote for next week's. | `world/council/` |
| Tilly's seed stall | Every seed in the game on Meadow Isle (open from the start), rarer seeds by Farming level. | `stock/tilly_seeds.tres` |
| Gift Tide | The winter week: gifts on every island and in the catch. Open them for surprises or spend them at Wally's Workshop (Snowflake Bobber, Holly Charm, Jolly Rod). | `world/events/gift_tide.tres` |

## The year

Four seasons of two weeks each (56 days, `world/events/calendar.gd`). Each season has a one- or
two-day festival in its middle (Blossom Derby, Starfall Night, Spooky Tide, Gift Tide). Happenings
repeat all year: Oriel's Caravan every 6 days (rare, rotating stock), the Farming Contest on
Tuesdays and the Fishing Derby on Wednesdays (medals pay Contest Ribbons), Meteor Night every 9
days, the Spawning Run every 8, and Shark Frenzy for two days each season. Every week has the
Saturday tournament, and the Sunday market and council vote. Every villager has a birthday. A
happening only appears once the story has introduced it (`GameEvent.requiredFlag`). The calendar
(C) shows a season at a time, each day's happenings, and what's coming up.

## The final update (2026-10-01)

| System | What it is | Where |
|---|---|---|
| Forage spots | 31 hand-placed spots (berry bushes, tide pools, driftwood, reeds, ember vents...) that regrow after 1-4 days; F to gather. Some need a foraging tool (Iron Sickle, Coral Knife, Tidecutter), which also adds yield and rare finds. | `world/forage/` |
| Villagers | Daily schedules (they walk the island on a background-built path grid and go inside at night), friendship hearts (talk daily, two gifts a week, loved/liked/disliked/hated, birthdays x8), heart scenes at 2/4/6/8/10 hearts with gifts, friend discounts in their shops. | `world/npc/` |
| Conversations | Portrait card with name and hearts, a side menu (Talk, Jobs, Shop, Service, Gift, Bye), a job board with offer and hand-in cards, a gift picker that remembers reactions. | `ui/dialogue/dialogue_ui.gd` |
| Harbor Bank | Coin account with seasonal interest (capped so it never out-earns fishing) and an item vault with upgradeable pages. Barnaby, in the new Harbor screen. | `world/bank/` |
| Trophy fishing | 13 trophy fish, one per fishing ground, each with a condition (dawn, fog, a perfect cast, a bait, grandpa's rod, during an event...). Bronze/silver/gold/diamond with luck meters; Odette's Trophy Lodge fillets them for Trophy Scales and has levels. | `world/trophy/` |
| Sea hunts | Grim's hunters' board: five creature families with four tiers. Fill the meter, then the family's boss bites. Pays Sea Essence and trophy parts for hunt gear; hunt levels add fight damage. | `world/hunts/` |
| Enchanting | The tide altar: 11 rod enchantments up to V for Sea Essence and coins, gated by Alchemy. | `fishing/enchanting/` |
| Treasure digging | Dig maps (three tiers) and spades (three tiers): a trail of spots on an island with a HUD compass, ending in a chest. | `world/digging/` |
| Museum | Nora's museum wing: donate rare catches, relics, gold trophies, hunt trophies and rare charms for points and milestone rewards. | `world/museum/` |
| Tide Tree | A perk tree (16 nodes) grown with Tide Tokens from Angler Levels and the story. Skills menu, Tide Tree tab. | `player/tide_tree.gd` |
| Achievements | 85 achievements with Steam API names (`ACH_<ID>`), passed to GodotSteam when it's there. Skills menu, Feats tab. | `world/achievements/` |
| First-use intros | A short scene the first time each system is used, and hub tabs that stay hidden until they matter (Charms, Pets, Collections). | `story/features.gd` |

Story additions (no chapter renumbering): forage and friendship lessons (chapter 0), the Harbor Bank
and the first crew member (1), the museum and Odette's lodge (2), Finn's buried caches and the
ledger that proves Deepnet bought the loans before the storm (3), the hunters' board and Vera's run
for the council (4), Frostmaw (5), the tide altar (6), and Debt-Free (pay off the harbor) before the
finale. Plus 38 friendship favors and 14 system quests.

## Menus and their looks

Each menu has its own look, set by a theme in `ui/skins/themes/`: shops are wooden counters, quest
boards cork, the quest log and dialogue parchment, the journal red leather, the recipe book brown
leather, the tacklebox green tin, collections a glass case, skills blue leather, the calendar paper.
The pictures are 9-slice PNGs in `ui/skins/art/`, so repainting them restyles every menu that uses
them. See `docs/art-guide.md`.
