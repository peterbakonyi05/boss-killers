# scenes/ui/ (and scenes/main_menu.gd)

All UI is built in code with `UIUtil` (`label`, `button`, `panel_style`, `theme`,
`hint_row`, `bar`) and `ButtonIcon` (PS5 glyphs, or the keyboard key for a player).

- `hud.gd` — one per player viewport: health, spell cooldown slots, help list,
  interact prompt, riddle panel (answers with D-pad / `answer_1..3`, no Buttons).
- `team_overlay.gd` — shared layer: money, items, goal, toasts, boss bar, fades, intro.
- `pause_menu.gd` — Options pauses for both; `process_mode = ALWAYS`.
- `level_complete.gd` — money earned, secrets found, new magic, button to the shop.
- `shop.gd` — upgrades per wizard/slot, greys out unaffordable ones.
- `../main_menu.gd` — both players join with Cross, then the menu appears.

## Controller rules (menus must work without a mouse)

- Every menu needs a focused button: grab focus when shown **and** call
  `UIUtil.ensure_focus(default_button)` in `_process`, so focus comes back after a
  stray mouse click.
- Cross/Circle reach buttons through `ui_accept`/`ui_cancel`, which only works because
  `PlayerInput._add_menu_buttons()` adds the controller buttons.
- When a menu hides during gameplay, release focus (`gui_release_focus()`), or
  Cross (jump) can press an invisible button.
- Extra shortcuts read `PlayerInput.just_pressed(p, "pause"/"back")` for both players.
- `tests/menu_test.tscn` drives these menus with fake controller events; extend it
  when adding a menu.
