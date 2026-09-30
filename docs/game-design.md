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
| K | Skills, Angler Level and stats |
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

Four seasons of one week each (28 days). Every week has a tournament (results Saturday 18:00) and a
Sunday market; every season ends with its festival (the Gift Tide fills the whole winter week).

## Menus and their looks

Each menu has its own look, set by a theme in `ui/skins/themes/`: shops are wooden counters, quest
boards cork, the quest log and dialogue parchment, the journal red leather, the recipe book brown
leather, the tacklebox green tin, collections a glass case, skills blue leather, the calendar paper.
The pictures are 9-slice PNGs in `ui/skins/art/`, so repainting them restyles every menu that uses
them. See `docs/art-guide.md`.
