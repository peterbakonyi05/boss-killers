# scenes/levels/

A level is a `Node3D` with `level.gd` (applies the theme, bakes navigation at start).
Required children: `WorldEnvironment` (filled by the theme), `Nav` (NavigationRegion3D)
with `Nav/Geometry` holding every walkable CSG floor/wall (`use_collision = true`), at
least one `Checkpoint` with `start_active`, and an `ExitPortal`. Set the root's `theme`
export. Hook it up with `data/levels/level_NN.tres`.

## Themes (level styles)

`level.gd` reads `theme: LevelTheme` (`scripts/data/level_theme.gd`, files in
`data/themes/`) and at start:
1. builds the `Environment` (background/sky, fog, volumetric fog, glow, SSAO);
2. swaps every CSG material from `data/surfaces/<name>.tres` (`wall`, `floor`,
   `arena_floor`, `stone`, `glow`) for the theme's real PBR material. Those surface
   files are only editor placeholders: **always give level CSG one of them**;
3. after the nav bake, adds a `LevelDresser` (props along walls, high on walls and on
   floors; raycasts so they only land on `Nav/Geometry` floors, keeps clear of
   checkpoints/gates/doors/chests/portals/lava/torches; no collision) and `AmbientFX`
   (particles around wizards, ghost wisps, bat flocks, lurking eyes).
Hand-placed set pieces use the `Prop` part. `Torch` takes the theme's color/flicker.

**Adding a new style (forest, swamp, moon, village...):**
1. Pick CC0 textures/models (Poly Haven) into `assets/` (see `assets/CREDITS.md`,
   set textures to VRAM + mipmaps, normal maps `compress/normal_map=1`, add credits).
2. Copy `data/themes/haunted_caves.tres`, change fog/light colors, texture ids,
   `wall_props`/`high_props`/`floor_props` (kinds in `scripts/props.gd`; add new kinds
   there, to `Props.KINDS` and to the `Prop` enum), `ambient_particles`, wisps/bats/eyes.
   Outdoor levels can set `sky_material` (e.g. a `ProceduralSkyMaterial`).
3. Build the level with surface placeholders and set the root `theme`.
4. Run the smoke test (`_check_theme`) and screenshots (`16_props`, `17_prop_gallery`).

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

Theme: `haunted_caves`. Set pieces under `Props` (candles and graves in the riddle
room, coffin in the shrine, a fallen knight and statues in the portal room).

Changing monsters or chests changes the money budget: run the smoke test
(`data/CLAUDE.md`, economy rules). Smoke/screenshot tests use some of these
coordinates and node names (`Imp4`, `LavaTrench`, `IceDoor`, `CrackedWall`, ...).
