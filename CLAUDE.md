# Boss Killers — notes for Claude

Two-player split-screen co-op wizard game, Godot 4.7, GDScript, built in code from
primitive shapes plus CC0 textures/models. Player-facing overview and controls: `README.md`.

## Working agreement

- **Gameplay first, graphics second.** Visuals are code-built shapes (`Build.*`) dressed
  with CC0 textures/models from `assets/` through level themes. Keep gameplay readable
  (telegraphs, paths) over looks; props never get collision.
- Audience is kids: readable UI text, telegraphed attacks, forgiving checkpoints.
- Match the existing style: short `##` doc comment on each class/exported var,
  plain words, tabs, typed GDScript (`var x := ...`, `-> void`).
- One commit per requested improvement; run the tests before committing.

## Commands

```sh
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . res://tests/smoke_test.tscn   # gameplay, level 1, ~50 s
$G --headless --path . res://tests/level_02_test.tscn   # jungle level + monsters, ~40 s
$G --headless --path . res://tests/menu_test.tscn    # menus + controller
$G --headless --path . --import                      # after adding a class_name or new .gd
$G --always-on-top --path . res://tests/screenshots.tscn -- <dir> [level=2]   # then Read the PNGs
```

Gotchas (all hit before):
- A **new `class_name` is unknown** to headless runs until `--import` refreshes
  `.godot/global_script_class_cache.cfg`. `--import` also writes the `.gd.uid` files,
  which are committed.
- A **parse error makes a test hang forever** (the script never loads, so it never
  quits). Run tests with a watchdog, e.g. background + `kill` after ~200 s, and read
  the full log, not just grep for PASS/FAIL.
- Screenshot scripts stall on macOS if the window is hidden: use `--always-on-top`.
- The user may have the Godot editor open on this project; don't fight it over files.

## Architecture map

| Where | What | More notes |
|---|---|---|
| `autoload/game_state.gd` | money, level, magic tiers, shop ranks, save file, riddles | `autoload/CLAUDE.md` |
| `autoload/player_input.gd` | builds `p1_*`/`p2_*` actions, controller assignment, menu buttons | `autoload/CLAUDE.md` |
| `data/` | `balance.tres`, spell sets, level data, riddles, themes, surface placeholders | `data/CLAUDE.md` |
| `assets/` | CC0 Poly Haven textures (`textures/<id>/`) and models (`models/<id>/<id>.gltf`) | `assets/CREDITS.md` |
| `scenes/game.gd` | runs a level: split screen, wizards, checkpoints, items, secrets, finish | — |
| `scenes/wizard/` | player movement, spells, shields, revive; camera rig | — |
| `scenes/enemies/` | `enemy.gd` state machine + one scene per monster | `scenes/enemies/CLAUDE.md` |
| `scenes/magic/` | `Projectile` (shape-query hits, pierce, homing, meteor from sky), `Shield` (touch burn/slow), `GroundEffect` (fire pool, frost patch) | — |
| `scenes/level_parts/` | arena, gate, checkpoint, lava, doors, chests, ... | `scenes/level_parts/CLAUDE.md` |
| `scenes/levels/` | level layouts (`level_01.tscn` caves, `level_02.tscn` jungle), themes and how to add a level style | `scenes/levels/CLAUDE.md` |
| `scenes/ui/`, `main_menu.gd` | HUD, overlay, pause, level complete, shop | `scenes/ui/CLAUDE.md` |
| `scripts/` | `Build` (meshes, materials, `pbr()` textures, `model()`), `FX` (particles, coins, text), `Props` (decoration kinds), `AmbientFX` (spooky mood), `SpellVisuals` (per-spell looks/impacts, flame and ice shaders), `UIUtil`, data classes | — |
| `tests/` | smoke, menu and screenshot scripts | `tests/CLAUDE.md` |

Flow: `main_menu.tscn` → `game.tscn` (loads `GameState.level_data().scene_path`) →
`LevelComplete` overlay → `ui/shop.tscn` → `game.tscn` again.

## Cross-cutting conventions

- **Groups** used for lookups: `wizards`, `enemies`, `arenas`, `checkpoints`,
  `interactable`, `projectiles`, `level`, `portals`, `gates`, `treasure`, `secrets`,
  `unsafe_ground` (floors that must not become a respawn point).
- **Physics layers:** 1 world, 2 players, 3 (bit 4) enemies, 5 (bit 16) shields,
  6 (bit 32) element targets (invisible zones like the lava freeze area).
- **Hit interface:** anything a projectile touches may implement
  `take_hit(p: Projectile) -> bool` (true = projectile is used up).
- **Interact interface** (group `interactable`): `can_interact(w)`, `get_prompt(w)`,
  `interact(w)`; the wizard picks the nearest within 3 m and shows the prompt.
- **Lava:** anything with `fall_in_lava()` gets it called by lava kill zones.
  **Water** (`WaterPool`, water `LavaTrench`) calls `fall_in_water()` on wizards only,
  so crocodiles and piranhas can live in it.
- `Game.instance` is the running game (null in menus/tests without a game);
  level parts call `Game.instance.toast(...)`, `collect_item`, `found_secret`.
- Enemy strength and money scale with `GameState.level` (see `data/CLAUDE.md`).
