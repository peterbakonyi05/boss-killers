# scenes/level_parts/

Reusable pieces placed in level scenes. Each is a script + a tiny `.tscn` that only
attaches the script; visuals and collision are built in `_ready` with `Build`.
Configure them with exported vars on the instance in the level scene.

| Part | What it does | Key exports / API |
|---|---|---|
| `Arena` | trigger closes child `Gate`s, spawns waves at child `Spawn*` markers, pulls the other wizard to `Entry`, opens gates when cleared, optional `reward_scene` | `wave_imps/spitters/brutes/knights/jaguars/anacondas/demons` (one number per wave), `size`; `summon()`, `reset()` (takes back money on team wipe) |
| `Gate` | iron bars rising from the floor | `close()`, `open()` |
| `Checkpoint` | walk-through zone + brazier; respawn point when both wizards fall | `start_active`, `zone_width`, `brazier_offset` |
| `LavaTrench` | lava gap; ice spells over it freeze a temporary bridge | `length`, `width`, `bridge_time`, `water` (river look, piranha bites). Leave a floor gap of exactly `length` |
| `LavaPool` | lava lake with kill zone and solid bottom (under walkways) | `size`, `depth`; origin = lava surface |
| `WaterPool` | murky jungle water with solid bottom; only wizards "fall in" (`fall_in_water`), so crocodiles/piranhas live in it | `size`, `depth`; origin = water surface |
| `IceDoor` | ice wall only fire melts, or a thorn wall fire burns | `width/height/thickness`, `melt_health`, `show_sign` (false = secret), `style` (`ice`/`thorns`) |
| `BreakableWall` | cracked rock wall, any player spell breaks it (secret passages) | `width/height/thickness`, `break_health` |
| `TreasureChest` | interact to open, gives money; counts as secret | `money`, `secret` |
| `ItemPickup` (`key_pickup`) | floating item, touch to collect | `item_id` |
| `RiddleStone` | interact → riddle UI; correct answer gives `item_id` | `riddle_ids` (empty = level's list) |
| `ExitPortal` | opens when `Game.has_all_items()`, both wizards inside finishes | — |
| `Torch` | wall torch with flicker and spooky guttering; default color comes from the theme | `color`, `energy`, `light_range`, `shadows` |
| `Prop` | hand-placed decoration of any `Props` kind, no collision | `kind`, `variant` (random seed) |
| `LevelDresser` | (no scene, made by `level.gd`) scatters theme props; exposes `dark_spots`/`open_spots` for `AmbientFX` | `dress(theme, geometry)` |
| `element_target.gd` | invisible Area on layer 32 that forwards projectile hits to a `handler` | used by LavaTrench |

Contracts (see root `CLAUDE.md`): `take_hit(p) -> bool`, the `interactable` trio,
`fall_in_lava()`. Parts that should not be respawn ground join `unsafe_ground`.

Adding a part: script with `class_name`, a 1-node `.tscn`, then run
`Godot --headless --path . --import` so the class is known to tests.
