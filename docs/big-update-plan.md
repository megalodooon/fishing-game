# The big update: plan

Working checklist for the update that came out of the first full playthrough (to day 8). Decisions
from the question round are at the bottom. Phases run in order; each ends with a headless test run
and a local commit. Nothing is pushed until the last phase.

## Phase 1: Foundations (everything else builds on these)

- [x] Split `Progress` into **per-player** state and **world** state (`WorldState`: story chapter and
      flags, quests, village projects, donations, farm, traps, council, unlocked places, clock).
- [x] Save format v2: `{world, players: {name: {...}}, host}`. Old saves show as outdated.
- [x] Character naming on a new game (and for a guest joining a world for the first time).
- [x] Stacks of 100 for items, fish never stack.

## Phase 2: Multiplayer (2 players, host-owned world)

- [x] `Net` autoload: host/join over ENet behind `MultiplayerPeer` (Steam peer drops in later), UPnP
      auto port-forward, short join code, LAN fallback, clear error when UPnP/CGNAT blocks it.
- [x] Title: Singleplayer / Multiplayer → Host (pick a slot) / Join (code or IP).
- [x] Handshake: version check, guest name, host sends world and the guest's character (new guest → naming).
- [x] Each peer runs its own location; the other player is drawn as an avatar when you're in the same
      place (position, facing, held item, cast line, boat). Guest gets a pale tint and name tags.
- [x] World state replication (host authoritative, key-level dictionary sync; guest changes go
      through the host).
- [x] Shared clock from the host; the day ends when both are asleep ("waiting for X"); Esc doesn't
      pause in MP. Pass out → wake in front of your house.
- [x] Location-shared things: fishing spots, forage, dropped items, NPC positions (deterministic from
      the clock), farm tiles, festival pickups. The first player in a location owns its spawns.
- [x] Sea chart shows both players; **boarding**: request from the chart (travel to an occupied
      place, or while already there), owner accepts, rider stands on the owner's deck and fishes, the
      owner sails.
- [x] Co-op creature fights: the other player can join within a few seconds, creature HP scales,
      both get drops.
- [x] Shared story scenes (play for everyone nearby, the triggering player chooses); shared quests with
      split/scaled rewards; village costs scale with 2 players.
- [x] Host saves everything (guest data streamed to the host and on disconnect).
- [x] Two-instance automated test (host + join headless, scripted checks).

## Phase 3: UI and UX

- [x] Remove the title "sea" effect everywhere it's used.
- [x] Main menu redesign, saves menu with player names, global Settings (audio, video, rebinding,
      gameplay/accessibility).
- [x] Toasts: small corner toasts, stacked and merged; compact banner for big moments (level up,
      advancement, chest, quest).
- [x] Smaller quest tracker, smaller hover callouts and prompts; declutter the screen generally.
- [x] Dialogue: player portrait and NPC portraits, better buttons and layout.
- [x] Quest log redesign (clean, intuitive).
- [x] Pause menu redesign (no big color block).
- [x] Journal: no dark outlines (rarity outline only), scrollable right page, Fish/Sea creature tabs
      when a place has creatures.
- [x] Recipe book: rarity outlines only.
- [x] Inventory: more saturated rarity outlines, effects for golden/shiny/giant fish.
- [x] Coins shown on the Tab hub. Tab/E close dialogues and shops.
- [x] Tackle descriptions: "Common Bobber", not "Common Tackle: ...".
- [x] Sea chart: clear path line, nicer boat movement.
- [x] Skills/Tide tree: say exactly what each node does; make it feel substantial.

## Phase 4: World

- [x] Islands: follow camera clamped to the island, no long walk from the arrival point, island water
      animates.
- [x] Village becomes a big hub island; interiors (own scenes) for the house, Market Hall + Fishmonger,
      Bank + Harbor Office, Museum/Aquarium + Tavern. Bank moves into the village.
- [x] Dropped items: forage drops onto the ground, drag out of the bag to drop, 15 s despawn, synced in MP.
- [x] Farming: hold to plant, planting costs energy.

## Phase 5: Systems

- [x] Equipment (Hat, Gear, 2 Charms) replaces the charm pouch; charms equip from the bag; unique
      effects, not just stats; sleep: pass out at 2 AM, gear can push it, hard cap 48 h awake.
- [x] Creature combat: 1 heart to start; hearts and damage from rod, equipment, levels.
- [x] Fix the crab fight lag spike; fix fish sticking at the top in the bar minigame.
- [x] Food: much smaller energy values.
- [x] Unique fishing tech (radar shows the fish over its spot for a while, etc.).
- [x] NPC likes/dislikes/loves/hates visible and meaningful.
- [x] Fewer junk drops; go over every system for function, fun and performance.
- [x] Restoration board: projects become a fund both players can chip into; coin costs scale with
      NetSession.players_in_world (x1.5 for two).
- [x] Lighthouse: remove the glow bait recipe from the Lightning Eel explanation.

## Phase 6: Economy

- [x] Simulate income per day; target ~200-350 coins by the end of day 4, fishing is the main income.
- [x] Quests, collections, achievements: items and XP, small coins. Seeds and shop prices rebalanced.
- [x] Multiplayer price/reward scaling.
  Done as data: fish basePrice x0.5, quest/aquarium coins x0.35 (rounded to 5, min 10), chest and creature coins x0.5, skill-level coins 20->8, collection tiers [10,30,90,280], cast energy 2->3, Bamboo Rod 1200->600. Estimate: ~27 fish/day at ~6 coins plus ~250 from early quests = ~750 earned by day 4, ~250-350 left after the usual early buys.

## Phase 7: Story (25-50 h; 100% in 100+ h)

- [x] New tutorial: Pip explains, then guides the first fish step by step.
- [x] Rewrite every scene: distinct voices, emotional beats, hardships, a twist ending. Player is
      named, "they" in text. Story paced across the locations and skill gates.

## Phase 8: Fun

- [x] Festival minigames and event shop; village visitors with quest chains.
- [x] Tavern games (playable against your friend); boat races and fishing derbies.

## Phase 9: Polish and ship

- [x] Performance pass, QoL, every system once more, docs, push.

## Decisions (question round)

See the memory note; summary: 2 players, desktop ENet now (Steam later), host's save holds everything,
shared clock and sleep together, shared story/village/farm/places/side quests with scaled rewards,
boarding by request, co-op fights, 1 heart, Hat/Gear/2 Charms, ~200-350 coins by day 4, stacks of 100
(fish unstackable), follow camera, small corner toasts, old saves break, generated placeholder PNGs.
