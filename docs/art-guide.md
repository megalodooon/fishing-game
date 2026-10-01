# Art guide

Most of the art in the game is generated placeholder art. Every piece is its own PNG, so redrawing
something means **painting over that file and saving it under the same name**. Godot reimports it
the next time the editor gets focus, and every scene and resource that uses it picks up the new art.
Nothing else needs to change as long as the new picture keeps the same size, and many kinds of art
(marked "any size" below) adjust to a new size on their own.

Tips:

- Keep the transparent background. See-through pixels matter: island ground is only walkable where
  the land art is opaque, and the chart keeps the boat clear of each place's icon.
- The game renders at 192x108 and is scaled up, so 1 pixel of art is 1 game pixel.
- Rename or move a file only from inside the Godot editor (FileSystem dock), so the references
  follow it.

## Where everything lives

| What | Folder (under `godot/`) | Size | Notes |
|---|---|---|---|
| Fish | `fishing/fish/assets/<area>/` | 16x16, 32x16 for long fish | Any size up to 32x16. The journal packs 32x16 fish into two slots. Held fish are scaled by species and weight. |
| Sea creatures (monsters) | `fishing/creatures/art/` | about 24-28 wide, 16-24 tall | Any size. |
| Rods | `fishing/rods/icons/` | 16x16 | Any size up to 16x16. |
| Tackle (rod parts) | `fishing/tacklebox/icons/` | 10x10 | Item icon. |
| Bait | `fishing/bait/icons/` | 10x11 | Item icon. |
| Materials | `items/materials/icons/` | 10x10 | Item icon. |
| Food | `items/snacks/icons/` | about 12x10 | Item icon. |
| Charms | `items/charms/icons/` | 11x12 | Item icon. |
| Treasure chests | `items/treasure/icons/` | 13x11 | Item icon. |
| Crab pots | `items/traps/icons/` | 12x11 | Item icon. |
| Key items (logbooks, pearls) | `items/key/icons/` | about 10x10 | Item icon. |
| Seeds and crops | `world/village/farm/icons/` | 9x11 | Item icon. |
| Aquarium tank icons | `world/village/aquarium/icons/` | 12x11 | |
| Item icons in general | | any size | Drawn centered in their slot. Up to 12x12 fits a slot best. |
| NPC standing sprites | `world/npcs/<id>.png` | 12x20 | **Any size.** Stood on its feet at the NPC's position; the !/? marker and the prompt move over its head. |
| NPC portraits | `world/portraits/<id>.png` | 24x24 | Any size up to 24x24, centered in the dialogue box frame. A new cast member's id and name go in `story/cast.gd`. |
| Pets | `world/village/pets/art/` | about 13-15 wide, 9-11 tall | Any size. |
| Island ground, one per screen | `world/islands/<island>/land/` | 192x108 | Opaque = walkable ground, see-through = sea. `landing.png` is the screen you arrive on: keep the pier on its left edge around y 48-60, where the player steps ashore (the `arrival` point on the Island node, (30, 54) by default). |
| Village ground | `world/village/land/` | 192x108 | Same as islands; `pier.png` is the arrival screen. |
| Island props and buildings | `world/islands/props/` | varies | Placed in the island scenes with an offset that stands them on their bottom edge. Keep the size, or fix the Sprite2D `offset` in the scene after resizing. |
| Village buildings and props | `world/village/buildings/`, `world/village/props/` | varies | Same as island props. |
| Boat | `boat/basic/` | 96x92 layers, bunk 16x11 | The deck, front, bottom, mast and sail are separate layers of the same size. The deck's opaque pixels are where the player can stand. |
| Sea chart icons | `world/map/icons/<place>.png` | islands 28x22, oceans 24x16 | Any size. The boat stops just outside an oval the size of the icon. The chart's water is a shader: its colors are on the WorldMap node (Water group) and each place's `chartTint`. |
| Chart boat and sailor | `world/map/icons/boat.png`, `player.png` | 13x5, 5x6 | |
| Weather icons | `world/weather/icons/` | 13x13 | |
| Clock and time icons | `ui/clock/icons/` | 13x13 | |
| Pause menu icons | `ui/pause/icons/` | 8x8 | |
| Festival fish | `fishing/fish/assets/events/` | 16x16, 32x16 for long fish | Same as other fish. |
| Festival items (petals, gifts, candy, festival tackle) | `items/events/icons/` | 16x16 | Item icon. Gifts also lie on the islands during the Gift Tide. |
| Rare catches, reforge stones, rare charms | `items/rare/icons/` | 16x16 | Item icon. |
| Tools and bag upgrades | `items/tools/icons/` | 16x16 | Item icon. `field_anvil.png` is also the anvil beside the village workbench. |
| Festival badges | `world/events/icons/` | 16x16 | Shown next to the clock (drawn at 12x12) and in notices. |
| Menu skins (frames, buttons, tabs, wells) | `ui/skins/art/` | 8-24 px squares | 9-slice pictures: the corners stay as drawn and the middle stretches. Each has a `.tres` in `ui/skins/` with its margins (how many pixels the corners are); keep them or change the margins in the Inspector. `ui/skins/themes/` holds each menu's look (which boxes and text colors). |
| Menu tab and unlock icons | `ui/hub/icons/` | 8x8, 6x6, 5x5 | Tab strip, skill, station and unlock-kind icons. |
| Forage and refined materials | `items/materials/icons/` | 16x16 | Item icon; forage icons also lie on the island ground. |
| Enchanted materials | `items/enchanted/icons/` | 16x16 | Item icon. Placeholders are the base icon with a violet glow. |
| Potions | `items/potions/icons/` | 16x16 | Item icon. |
| Crew contracts | `items/crew/icons/` | 16x16 | Item icon. Crew members show their product's icon on the board. |
| Tiered charms | `items/charms/icons/<family>_<tier>.png` | 16x16 | Tier 1 charm, 2 ring, 3 artifact, 4 relic. |
| Crew board, ballot box | `world/village/props/` | 20x22, 14x16 | Standing props in the village. |
| Forage spots | `world/forage/art/<kind>.png` | 40x16 (two 20x16 frames) | Left frame full, right frame gathered. Stood on the spot's position. |
| Foraging tools | `world/forage/icons/` | 16x16 | Item icon. |
| Harbor buildings and props | `world/village/buildings/bank.png`, `trophy_lodge.png`, `world/village/props/hunt_board.png`, `tide_altar.png` | 44x34, 40x32, 20x22, 18x24 | Placed in `village.tscn` (Harbor room). |
| Harbor ground | `world/village/land/harbor.png` | 192x108 | Same rules as the other village screens. |
| Trophy fish | `world/trophy/icons/` (base), `items/trophy/icons/<fish>_<tier>.png` | 16x16 | The tier items are the base fish with a medal in the corner. |
| Hunt bosses and parts | `world/hunts/art/`, `items/hunts/icons/` | creature size, 16x16 | Bosses are recolored, crowned creatures. |
| Digging, essence, scales | `items/digging/icons/`, `items/enchanting/icons/`, `items/trophy/icons/` | 16x16 | Item icons. |
| Event badges | `world/events/icons/` | 16x16 | Calendar, HUD and notices. |
| Achievement trophies | `world/achievements/icons/` | 12x12 | bronze, silver, gold, locked. |
| Conversation menu icons | `ui/dialogue/icons/` | 8x8 | Talk, jobs, shop, service, gift, bye. |
| New villagers | `world/npcs/` and `world/portraits/` (oriel, barnaby, odette) | 12x20, 24x24 | Same as the others. |
## Adding new things

- **A fish**: a `FishData` .tres (copy one in `fishing/fish/species/`) with its icon, then add it to
  a `Biome`'s fish list (`oceans/.../*_biome.tres`). The collection log finds it on its own.
- **An item** (material, food, charm...): copy a .tres from the matching `items/` folder and give it
  a new icon. It shows up in the collection log automatically.
- **An NPC**: add their id, name and name color to `story/cast.gd`, drop `world/npcs/<id>.png` and
  `world/portraits/<id>.png` in, place an `Npc` node (copy one from `world/village/village.tscn`)
  and write their lines in `story/dialogue.txt` (`<id>_chat` for small talk, `<id>_ch<chapter>`
  for a chapter's story talk).
- **A place on the chart**: a scene, a `Location` .tres in `world/locations/` with its map icon, and
  the location added to the player's Atlas (`player/player.tscn`).
- **A festival**: a `GameEvent` .tres in `world/events/` (copy `gift_tide.tres`): its dates on the
  calendar, its fish page (a `Biome` with region "Festivals"), drops, pickups, host and stall. The
  calendar, the journal and the HUD pick it up on their own.
- **A rare catch**: an item plus a `RareDrop` .tres in `items/rare_drops/` saying where and how rare.
- **A reforge**: a `Reforge` .tres in `fishing/reforges/` (weight 0 and a `stone` for stone-only ones).
- **A recipe**: a `BaitRecipe` .tres in `items/recipes/` (or `fishing/bait/recipes/`,
  `items/snacks/recipes/`) with its `station` and what it takes to learn (`requiredFlag`,
  `requiredSkill` + `requiredLevel`). The recipe book, the skill tracks and the collection case list it.
- **Shop stock**: the `ShopStock` files in `world/village/shop/stock/`. Leave `price` at 0 to use the
  item's own price (`buyPrice` on the item, or its rarity's tier price).
