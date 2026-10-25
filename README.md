# Boss Killers

A split-screen co-op action game for two players, made with **Godot 4.7**.
One player is the **Fire Wizard**, the other the **Ice Wizard**. Together they
fight through the underworld, solve riddles, find secrets and beat bosses.

Graphics are placeholders built from simple shapes. The focus right now is
gameplay, behaviour and balance; real art comes last.

## Play

1. Install Godot 4.7 (the project uses Forward+).
2. Pair two PS5 DualSense controllers (Bluetooth) or use the keyboard.
3. Open the project in Godot and press Play, or run:

   ```sh
   /Applications/Godot.app/Contents/MacOS/Godot --path .
   ```

On the title screen each player presses **Cross** (or their jump key) to join.

### Controls

| Action        | Controller | Player 1 keys | Player 2 keys |
|---------------|------------|---------------|---------------|
| Move          | Left stick | WASD          | Arrows        |
| Camera        | Right stick| Q / Z         | , / .         |
| Jump          | Cross      | Space         | Right Shift   |
| Interact      | Square     | E             | Enter         |
| Strong spell  | R2         | F             | K             |
| Fast spell    | R1         | G             | L             |
| Big shield (hold) | L2     | R             | I             |
| Quick shield  | L1         | T             | O             |
| Pause         | Options    | Esc           | P             |
| Back          | Circle     | Backspace     | Delete        |
| Riddle answers| D-pad ← ↑ →| 1 2 3         | 8 9 0         |

Menus: D-pad to choose, Cross to press. In the shop, Options starts the next level.

## How the game works

- **Teamwork puzzles:** the Ice Wizard freezes lava and rivers into bridges, the Fire
  Wizard melts ice doors and burns thorn walls. Riddle stones give the Riddle Rune; the boss arena gives the Key.
  Both are needed to open the exit portal, and both wizards must step in.
- **Fights:** path monsters, and arenas that lock their gates and send waves.
  Monsters telegraph their attacks (imps lunge, brutes and bosses charge, spitters
  shoot; in the jungle jaguars prowl and pounce, anacondas strike and sweep their
  tails, crocodiles snap from the water and piranhas jump out of it). Fire burns, ice slows and freezes, and fire shatters frozen monsters.
- **Magic:** every spell does something different (tier 2 unlocks after level 1):

  | Wizard | Spell | What it does |
  |---|---|---|
  | Fire | Fireball (strong) | rolling fireball, leaves a small burning pool |
  | Fire | Flame Darts (fast) | quick embers that curve toward monsters |
  | Fire | Meteor (strong, tier 2) | falls from the sky onto the target (red warning ring), big blast and fire pool |
  | Fire | Twin Flames (fast, tier 2) | two flames spiralling around each other, they curve toward monsters |
  | Ice | Ice Comet (strong) | crystal comet, leaves a frost patch that slows monsters |
  | Ice | Frost Shards (fast) | spinning shards that fly through one monster into the next |
  | Ice | Glacier Spear (strong, tier 2) | long ice lance that goes through a whole line of monsters, ice spikes behind it |
  | Ice | Twin Icicles (fast, tier 2) | two spinning icicles that each go through one monster |

  Shields: fire domes burn monsters that push against them, ice domes slow them.
- **Falling:** a fallen wizard gets back up after a few seconds. If both fall,
  the team goes back to the last checkpoint. Falling into lava or piranha water
  hurts and puts you back on safe ground.
- **Money and shop:** monsters and treasure chests give team money. Between levels
  the shop sells upgrades; bigger magic costs more, so the team saves up.
- **Secrets:** cracked walls, hidden ledges and secret ice walls hide treasure.
  The level complete screen shows how many were found.
- Progress is saved to `user://save.json` after each level and after shopping.

Built levels:

| Level | Title | Style | Boss |
|---|---|---|---|
| 1 | The Burning Caves | Haunted Caves | Demon Knight |
| 2 | The Jungle of Shadows | Night Jungle: river, swamp boardwalk, piranha lagoon, temple ruins | Jungle Demon (roots burst up under the wizards, calls jaguars) |

Later level numbers replay the newest built layout with stronger monsters. Levels get
their look from a theme (`data/themes/`), so new styles like swamp or moon are quick to add.

## Tests

```sh
# Gameplay smoke test (headless, ~50 s)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/smoke_test.tscn
# Level 2 (jungle) test (headless, ~40 s)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/level_02_test.tscn
# Menus with simulated controller presses (headless, a few seconds)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/menu_test.tscn
# Screenshots (needs a window; --always-on-top or macOS may stall it)
/Applications/Godot.app/Contents/MacOS/Godot --always-on-top --path . res://tests/screenshots.tscn -- /tmp/shots
/Applications/Godot.app/Contents/MacOS/Godot --always-on-top --path . res://tests/screenshots.tscn -- /tmp/shots level=2
/Applications/Godot.app/Contents/MacOS/Godot --always-on-top --path . res://tests/menu_screenshots.tscn -- /tmp/shots
```

Each test prints `PASS`/`FAIL` lines and exits with code 1 on failure.

## Project layout

```
autoload/       GameState (money, level, saves) and PlayerInput (both players' controls)
assets/         CC0 textures and models from Poly Haven (see assets/CREDITS.md)
data/           Balance numbers, level settings, spell sets, themes, riddles (.tres / .json)
scenes/
  game.*        One level in split screen: wizards, checkpoints, items, finishing
  main_menu.*   Title screen with player join
  wizard/       Player wizard and camera
  enemies/      One monster script, one scene per monster type
  magic/        Projectiles, shields and ground effects (fire pool, frost patch)
  level_parts/  Reusable level pieces (arena, gate, lava, water, doors, chests, ...)
  levels/       Level layouts
  ui/           HUD, overlay, pause, level complete, shop
scripts/        Shared helpers: Build (shapes, textures, models), FX (particles), SpellVisuals,
                Props (decorations), AmbientFX (spooky mood), UIUtil, data classes
tests/          Headless tests and screenshot scripts
```

Most numbers to tweak live in `data/balance.tres`, `data/spells/*.tres` and the
monster scenes in `scenes/enemies/`.
