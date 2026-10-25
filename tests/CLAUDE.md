# tests/

Plain scenes that run checks and quit; no test framework. Each prints `PASS  ...` /
`FAIL  ...` lines and a summary line, exit code 1 on any failure.

| Scene | Mode | Covers |
|---|---|---|
| `smoke_test.tscn` | headless, ~50 s | economy budget, nav connectivity, spells, shields, burn/freeze, lava, ice door, secrets, arenas (waves, gates, money take-back), team wipe/revive, items/portal, monster moves (roar, lunge, charge, boss summon), level completion |
| `menu_test.tscn` | headless, seconds | title join + start, shop navigation and buying with simulated controller presses, focus recovery |
| `screenshots.tscn` | window | gameplay PNGs (`01_start` … `18_monster_closeup`) into the folder given after `--` |
| `menu_screenshots.tscn` | window | title, level complete, shop PNGs |

Running safely:

```sh
G=/Applications/Godot.app/Contents/MacOS/Godot
( $G --headless --path . res://tests/smoke_test.tscn > log.txt 2>&1 & PID=$!
  for i in $(seq 1 200); do sleep 1; kill -0 $PID 2>/dev/null || break; done; kill $PID 2>/dev/null )
grep -E "FAIL|SCRIPT ERROR|SMOKE" log.txt
```

- A parse error never quits (the test just hangs), hence the watchdog; check the
  log for `SCRIPT ERROR`. New `class_name`s need `$G --headless --path . --import` first.
- Screenshot runs need `--always-on-top` on macOS. Look at the PNGs with Read.

Writing checks:
- Tests call internals directly (`wizard.cast(true)`, `enemy.hit(...)`, private
  fields like `_cooldowns`, `_dash_left`); that's fine here.
- Use `_frames(n)` (physics frames) and `_wait_for(callable, max_frames)` instead of
  long fixed sleeps; `_spawn(scene, pos)` adds an aggressive monster.
- Tests reuse one game instance, so order matters: later sections assume earlier
  ones cleared monsters/doors. Add new sections near related ones.
- Always set `GameState.save_enabled = false` so the real save file is untouched.
