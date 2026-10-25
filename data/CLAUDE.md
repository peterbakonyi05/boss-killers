# data/

Plain resources edited by hand or in the Godot inspector. Their classes live in
`scripts/data/` (`Balance`, `LevelData`, `SpellData`). When adding a field, add it to
the class with a `##` comment **and** to the `.tres` file.

- `balance.tres` — enemy power per level, money per kill, wizard health/regen/revive,
  lava damage, shop prices.
- `levels/level_NN.tres` — title, scene path, unlocked tier, riddle ids, required
  items, goal text. A level "exists" when this file exists.
- `spells/<element>_<tier>.tres` — one magic set per element and tier (names,
  damage, cooldowns, shield, burn/slow/freeze numbers). Missing tiers fall back to
  the highest existing one. Each spell also has a twist: `*_style` (look in
  `SpellVisuals`), `*_pierce`, `weak_homing`, `strong_from_sky` (meteor),
  `ground_effect` + `ground_radius/time/power`, `shield_touch_dps`. Twists are
  checked in `smoke_test.gd` `_check_spell_twists`.
- `riddles.json` — `[{id, question, answers[3], correct}]`, kid-friendly.
- `themes/<style>.tres` — `LevelTheme`: fog, light, textures, props, spooky extras
  (see `scenes/levels/CLAUDE.md`, "Themes").
- `surfaces/<name>.tres` — placeholder materials for level CSG; the theme replaces
  them at runtime (`wall`, `floor`, `arena_floor`, `stone`, `glow`).

## Economy rules (keep these true)

Asked for by the players: after level 1 the team can buy **at most one cheap
upgrade per wizard**, and big magic must be saved up for over levels.

- Slot prices: quick shield 300 < fast spell 400 < big shield 600 < strong spell 900,
  +75% of the base per rank.
- A perfect level 1 run (every monster + every treasure chest) is ~888 money:
  ≥ 2 × cheapest (600) and < cheapest × 2 + second cheapest (1000).
- `tests/smoke_test.gd` `_check_economy()` computes the maximum from the level's
  monsters, arena waves and `treasure` chests and asserts this. Adding monsters,
  waves or chests changes the total — re-run it and retune `money_*` if it fails.
- Arenas take back the money from a failed try on team wipe (no farming).
- Enemy health/damage multiply by `level × enemy_power_per_level / 10`; money gets
  `+money_level_bonus` per level.
