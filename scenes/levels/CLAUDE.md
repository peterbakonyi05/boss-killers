# scenes/levels/

A level is a `Node3D` with `level.gd` (bakes navigation at start). Required children:
`WorldEnvironment`, `Nav` (NavigationRegion3D) with `Nav/Geometry` holding every
walkable CSG floor/wall (`use_collision = true`), at least one `Checkpoint` with
`start_active`, and an `ExitPortal`. Hook it up with `data/levels/level_NN.tres`.

Only CSG under `Nav/Geometry` is baked into the nav mesh. Level parts (doors,
breakable walls, lava) are not, so monsters may try to path through closed doors.

## Editing the .tscn by hand / script

Levels are big text scenes, usually edited with small Python scripts:
- Transforms are `Transform3D(basis rows..., x, y, z)`. Rotations used:
  `0,0,1, 0,1,0, -1,0,0` turns local −Z (a part's front) to world −X;
  `0,0,-1, 0,1,0, 1,0,0` → +X; `-1,0,0, 0,1,0, 0,0,-1` → +Z.
- Floors are boxes with their **top at y = 0** (center y −0.5). Walls are 8 tall,
  centered at y 3. Wizards jump ≈1.6 m high and ≈4.5 m far.
- Children of an `Arena` use coordinates relative to the arena.
- Bump `load_steps` and add an `ext_resource` when instancing a new scene type.
- **Openings:** when cutting a doorway into a wall, the floor must continue *under*
  the wall thickness, or there is a 1 m hole (the nav check in the smoke test
  catches this).

## Level 1 layout (`level_01.tscn`, path runs along −Z, x ≈ 0)

| z (m) | Section |
|---|---|
| 0 … −12 | Start room (checkpoint) |
| −12 … −40 | Corridor A; **secret 1**: `CrackedWall` at x −4.5, z −30 → room with chest |
| −40 … −64 | Arena1 "Imp Den" (3 waves) |
| −64 … −92 | Corridor B with `LavaTrench` at −78 (ice bridge) |
| −92 … −116 | Arena2 "Brute Pit" (3 waves) |
| −116 … −136 | Ambush Tunnel, monsters in side alcoves (checkpoint at −118) |
| −136 … −176 | Lava River Cavern: walkway over `CavernLava`, spitters on islands, `LavaTrench2` at −168; **secret 2**: stepping stones to a ledge chest at (−9.5, 1.4, −174.5) |
| −176 … −190 | Riddle room (`RiddleStone`); **secret 3**: `SecretIceWall` at x 6.5, z −180 → shrine chest |
| −190 … −196 | `IceDoor` (fire melts) |
| −196 … −236 | BigArena "Hall of the Demon Knight" (boss, drops the Key) |
| −236 … −252 | Portal room, `ExitPortal` at −247 |

Changing monsters or chests changes the money budget: run the smoke test
(`data/CLAUDE.md`, economy rules). Smoke/screenshot tests use some of these
coordinates and node names (`Imp4`, `LavaTrench`, `IceDoor`, `CrackedWall`, ...).
