# Fishing Game

A small pixel-art fishing game made with Godot 4.7.

**Play it in the browser:** https://megalodooon.github.io/fishing-game/

The web version is rebuilt and redeployed automatically on every push to `main`
(see `.github/workflows/deploy-web.yml`).

## Controls

| Action | Input |
|---|---|
| Walk | W A S D |
| Equip / unequip the rod | 1 |
| Charge and cast | Hold and release the left mouse button |
| Reel in | Left or right click while the line is out |
| Cancel a charge | Right click |
| Speed up / slow down the boat | Right / left arrow |
| Stop / restart the boat | Up arrow |
| Skip one hour (test scene) | Down arrow |

## Project layout

- `godot/` - the Godot project (open `godot/project.godot`).
- `docs/optimization-report.md` - what was optimized, how it was measured and the results.
