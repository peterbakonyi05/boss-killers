# scenes/enemies/

All monsters use `enemy.gd` (`class_name Enemy`, a `CharacterBody3D`). Each `.tscn`
is just the script plus exported numbers:

| Scene | Look | Role | Special |
|---|---|---|---|
| `imp.tscn` | IMP | fast melee | `lunge_distance` (jumps at wizards) |
| `spitter.tscn` | IMP, `ranged` | shoots green bolts | `strafe_speed`; `stationary` for islands |
| `brute.tscn` | BRUTE | slow, slams (area) | `charge_speed` / `charge_cooldown` |
| `demon_knight.tscn` | KNIGHT, `is_boss` | boss: slam, volley, charge | enrages at 50%, summons 2 imps |
| `jaguar.tscn` | JAGUAR | fast pouncer | `prowl` (circles via `_strafe` between pounces), long `lunge_distance` with a leap arc |
| `anaconda.tscn` | SNAKE | slow, tail-sweep slam | strike = `charge_speed`; body `_segments` wiggle |
| `crocodile.tscn` | CROC | water ambusher, bites from the edge | `swim_leash`; lurks low (`_sink`), rises and opens `_jaw` to bite |
| `piranha.tscn` | PIRANHA | jumps out of the water | `swim_leash`, `submerged` (not auto-aimed until it leaps), splash telegraph |
| `jungle_demon.tscn` | DEMON, `is_boss` | boss: slam, thorn volley, charge, **roots** | roots: glowing ring under each wizard, then spikes; enrages, summons 2 jaguars |

Base health/damage are level-1 values; `_ready` multiplies by `GameState.enemy_scale()`.

## Behaviour (`_think` state machine)

`idle` → (wizard within `aggro_range`, or `always_aggro` for arena spawns) →
`roar` (once per monster; dim eyes flare, big ones shake nearby cameras) →
`chase` ⇄ `windup` (telegraph) → attack. Kinds: `melee`, `slam`, `shoot`, `volley`,
`charge`, `roots` (Jungle Demon). Lunges/charges are short straight "dashes" (`_start_dash`, `_update_dash`)
that only hit if the wizard is still there; a charge into a wall stuns (`DIZZY!`).

Water monsters (`swim_leash > 0`) have no gravity and no nav paths: their origin is
placed **at the water surface**, they swim straight at wizards but never further than
`swim_leash` from home (`_swim_direction`). Piranhas have `collision_mask = 0` so they
can swim under walkways and leap through them.

Status effects: fire burns (DoT) and shatters frozen monsters for ×1.5; ice stacks
slow, enough stacks freeze (half time on bosses). Imps only flinch from big hits.

Rules of thumb:
- Every attack must be **telegraphed** (windup scale/arm/eyes, ground circle, charge
  line) so kids can dodge or shield.
- Bosses must call `Game.instance.show_boss(self)` (done in `_ready` when `is_boss`).
- Summons go through the parent arena's `summon(kind, pos)` so the arena waits for them.
- `die()` gives money (`money_dropped`), coins, and emits `died`.

## Look

Models are built in `_build_imp/_brute/_knight/_jaguar/_snake/_croc/_piranha/_demon` from `Build` primitives with CC0 textures (`_skin(color, roughness, texture)`); `_add()`
registers meshes for hit-flash/slow overlays. Forward is −Z of `_model`. Keep shapes
simple; imp wings (`_wings`) flap in `_animate`. Scariness comes mostly from behaviour and glowing eyes, keep eyes bright.
