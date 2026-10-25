# autoload/

Two autoload singletons (registered in `project.godot`).

## GameState (`game_state.gd`)

- Team state: `money`, `level` (1..`MAX_LEVEL` = 12), `tiers` (magic tier per element),
  `ranks[element][slot]` (shop upgrades). `joined` = which players pressed join.
- Saved to `user://save.json` by `save_game()` (after a level, after buying, entering
  the shop). Tests set `save_enabled = false` and call `reset_progress()`.
- `level_data()` falls back to the newest **built** level file; enemies still use
  the real `level` for strength. `complete_level()` raises tiers and the level.
- Money: `money_for(size)` = balance money × level bonus. `add_money()` emits
  `money_changed` (negative amounts are used to take back arena money).
- Shop: `base_price(slot)` per slot, `upgrade_price()` grows with rank and rounds
  to 10s, `buy_upgrade()`, `upgrade_mult()` is the strength bonus.
- Riddles come from `data/riddles.json` via `get_riddles(ids)`.

## PlayerInput (`player_input.gd`)

- Builds actions `p1_<name>` / `p2_<name>` at startup (`rebuild()`) from the `KEYS`,
  `PAD_BUTTONS` and `PAD_AXES` tables. Use `PlayerInput.pressed/just_pressed(p, name)`,
  `get_move(p)`, `get_look(p)` — never raw InputMap names in gameplay code.
- `player_device[p]` = controller id per player; joins/swaps via `assign_device()`;
  hot-plug handled in `_on_joy_connection_changed`.
- Keyboard always works for both players (testing). Godot's `ui_*` actions have
  no controller buttons by default: `_add_menu_buttons()` adds Cross → `ui_accept`,
  Circle → `ui_cancel` for every device. Keep that, or menus break on controllers.
- `PAD_ICONS` maps actions to on-screen icon names used by `ButtonIcon`.
