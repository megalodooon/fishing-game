# The big update: plan

Working checklist for the update that came out of the first full playthrough (to day 8). Decisions
from the question round are at the bottom. Phases run in order; each ends with a headless test run
and a local commit. Nothing is pushed until the last phase.

## Phase 1: Foundations (everything else builds on these)

- [ ] Split `Progress` into **per-player** state and **world** state (`WorldState`: story chapter and
      flags, quests, village projects, donations, farm, traps, council, unlocked places, clock).
- [ ] Save format v2: `{world, players: {name: {...}}, host}`. Old saves show as outdated.
- [ ] Character naming on a new game (and for a guest joining a world for the first time).
- [ ] Stacks of 100 for items, fish never stack.

## Phase 2: Multiplayer (2 players, host-owned world)

- [ ] `Net` autoload: host/join over ENet behind `MultiplayerPeer` (Steam peer drops in later), UPnP
      auto port-forward, short join code, LAN fallback, clear error when UPnP/CGNAT blocks it.
- [ ] Title: Singleplayer / Multiplayer → Host (pick a slot) / Join (code or IP).
- [ ] Handshake: version check, guest name, host sends world and the guest's character (new guest → naming).
- [ ] Each peer runs its own location; the other player is drawn as an avatar when you're in the same
      place (position, facing, held item, cast line, boat). Guest gets a pale tint and name tags.
- [ ] World state replication (host authoritative, key-level dictionary sync; guest changes go
      through the host).
- [ ] Shared clock from the host; the day ends when both are asleep ("waiting for X"); Esc doesn't
      pause in MP. Pass out → wake in front of your house.
- [ ] Location-shared things: fishing spots, forage, dropped items, NPC positions (deterministic from
      the clock), farm tiles, festival pickups. The first player in a location owns its spawns.
- [ ] Sea chart shows both players; **boarding**: request from the chart (travel to an occupied
      place, or while already there), owner accepts, rider stands on the owner's deck and fishes, the
      owner sails.
- [ ] Co-op creature fights: the other player can join within a few seconds, creature HP scales,
      both get drops.
- [ ] Shared story scenes (play for everyone nearby, the triggering player chooses); shared quests with
      split/scaled rewards; village costs scale with 2 players.
- [ ] Host saves everything (guest data streamed to the host and on disconnect).
- [ ] Two-instance automated test (host + join headless, scripted checks).

## Phase 3: UI and UX

- [ ] Remove the title "sea" effect everywhere it's used.
- [ ] Main menu redesign, saves menu with player names, global Settings (audio, video, rebinding,
      gameplay/accessibility).
- [ ] Toasts: small corner toasts, stacked and merged; compact banner for big moments (level up,
      advancement, chest, quest).
- [ ] Smaller quest tracker, smaller hover callouts and prompts; declutter the screen generally.
- [ ] Dialogue: player portrait and NPC portraits, better buttons and layout.
- [ ] Quest log redesign (clean, intuitive).
- [ ] Pause menu redesign (no big color block).
- [ ] Journal: no dark outlines (rarity outline only), scrollable right page, Fish/Sea creature tabs
      when a place has creatures.
- [ ] Recipe book: rarity outlines only.
- [ ] Inventory: more saturated rarity outlines, effects for golden/shiny/giant fish.
- [ ] Coins shown on the Tab hub. Tab/E close dialogues and shops.
- [ ] Tackle descriptions: "Common Bobber", not "Common Tackle: ...".
- [ ] Sea chart: clear path line, nicer boat movement.
- [ ] Skills/Tide tree: say exactly what each node does; make it feel substantial.

## Phase 4: World

- [ ] Islands: follow camera clamped to the island, no long walk from the arrival point, island water
      animates.
- [ ] Village becomes a big hub island; interiors (own scenes) for the house, Market Hall + Fishmonger,
      Bank + Harbor Office, Museum/Aquarium + Tavern. Bank moves into the village.
- [ ] Dropped items: forage drops onto the ground, drag out of the bag to drop, 15 s despawn, synced in MP.
- [ ] Farming: hold to plant, planting costs energy.

## Phase 5: Systems

- [ ] Equipment (Hat, Gear, 2 Charms) replaces the charm pouch; charms equip from the bag; unique
      effects, not just stats; sleep: pass out at 2 AM, gear can push it, hard cap 48 h awake.
- [ ] Creature combat: 1 heart to start; hearts and damage from rod, equipment, levels.
- [ ] Fix the crab fight lag spike; fix fish sticking at the top in the bar minigame.
- [ ] Food: much smaller energy values.
- [ ] Unique fishing tech (radar shows the fish over its spot for a while, etc.).
- [ ] NPC likes/dislikes/loves/hates visible and meaningful.
- [ ] Fewer junk drops; go over every system for function, fun and performance.
- [ ] Lighthouse: remove the glow bait recipe from the Lightning Eel explanation.

## Phase 6: Economy

- [ ] Simulate income per day; target ~200-350 coins by the end of day 4, fishing is the main income.
- [ ] Quests, collections, achievements: items and XP, small coins. Seeds and shop prices rebalanced.
- [ ] Multiplayer price/reward scaling.

## Phase 7: Story (25-50 h; 100% in 100+ h)

- [ ] New tutorial: Pip explains, then guides the first fish step by step.
- [ ] Rewrite every scene: distinct voices, emotional beats, hardships, a twist ending. Player is
      named, "they" in text. Story paced across the locations and skill gates.

## Phase 8: Fun

- [ ] Festival minigames and event shop; village visitors with quest chains.
- [ ] Tavern games (playable against your friend); boat races and fishing derbies.

## Phase 9: Polish and ship

- [ ] Performance pass, QoL, every system once more, docs, push.

## Decisions (question round)

See the memory note; summary: 2 players, desktop ENet now (Steam later), host's save holds everything,
shared clock and sleep together, shared story/village/farm/places/side quests with scaled rewards,
boarding by request, co-op fights, 1 heart, Hat/Gear/2 Charms, ~200-350 coins by day 4, stacks of 100
(fish unstackable), follow camera, small corner toasts, old saves break, generated placeholder PNGs.
