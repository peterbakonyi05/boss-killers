class_name LevelTheme
extends Resource
## How a level looks: sky, fog, light, surface textures, props and spooky extras.
## One file per style in data/themes/ (haunted_caves.tres, later forest, swamp, moon...).
## A level scene points at its theme with the `theme` export on its root node.

@export var theme_name := "Haunted Caves"

@export_group("Sky and fog")
@export var background_color := Color(0.03, 0.008, 0.012)
## Optional sky (for outdoor levels like forest or moon). Empty = plain background color.
@export var sky_material: Material
@export var ambient_color := Color(0.42, 0.24, 0.26)
@export var ambient_energy := 0.45
@export var fog_color := Color(0.18, 0.05, 0.04)
@export var fog_density := 0.012
## Low fog that hugs the ground (0 = off).
@export var fog_height_density := 0.0
@export var fog_height := 0.0
@export var volumetric_fog_density := 0.02
@export var volumetric_fog_albedo := Color(0.9, 0.55, 0.45)
@export var volumetric_fog_emission := Color(0.04, 0.004, 0.002)
@export var glow_intensity := 0.9
@export var exposure := 1.1
@export var saturation := 1.1

@export_group("Surfaces")
## Texture folders in assets/textures/ (Poly Haven ids). Empty = flat color.
@export var wall_texture := "rock_wall_10"
@export var wall_tint := Color(1, 1, 1)
## Texture repeats per meter (smaller = bigger stones).
@export var wall_uv_scale := 0.25
@export var floor_texture := "burned_ground_01"
@export var floor_tint := Color(1, 1, 1)
@export var floor_uv_scale := 0.2
@export var arena_floor_texture := "monastery_stone_floor"
@export var arena_floor_tint := Color(1, 1, 1)
@export var arena_floor_uv_scale := 0.15
## Pillars, ruins, gravestones and other built stone.
@export var stone_texture := "mossy_stone_wall"
@export var stone_tint := Color(1, 1, 1)
## Color of glowing cracks and other "glow" surfaces.
@export var glow_color := Color(1, 0.35, 0.05)
@export var normal_strength := 1.4

@export_group("Lights")
## Torch flame color (torches that keep their default color use this).
@export var torch_color := Color(1.0, 0.55, 0.2)
## 0 = steady, 1 = wild flicker; spooky torches sometimes almost go out.
@export var torch_flicker := 0.5

@export_group("Props")
## Prop kinds (see scripts/props.gd) placed against walls, picked at random.
@export var wall_props := PackedStringArray()
## Prop kinds hung high on walls (cobwebs, chains, cages).
@export var high_props := PackedStringArray()
## Small things scattered on floors (pebbles, bones).
@export var floor_props := PackedStringArray()
## Props per meter of wall (0.3 = about one every 3 m).
@export var wall_prop_density := 0.3
@export var high_prop_density := 0.12
## Small props per square meter of floor.
@export var floor_prop_density := 0.03
## Same seed = same layout every time the level loads.
@export var prop_seed := 1

@export_group("Mood")
## Floating particles near the wizards: "embers", "dust", "spores", "snow", "fireflies" or "".
@export var ambient_particles := "embers"
## Glowing ghost lights that drift around and flee from wizards.
@export var ghost_wisps := 8
@export var wisp_color := Color(0.5, 1.0, 0.8)
## Bat flocks that sometimes fly over the wizards.
@export var bats := true
## Pairs of glowing eyes that blink in dark corners and vanish when you come close.
@export var lurking_eyes := 6
@export var eye_color := Color(1.0, 0.85, 0.2)

## Surface names a level can use: put a material from data/surfaces/<name>.tres on a
## CSG shape and the theme swaps it for the real one when the level starts.
const SURFACES := ["wall", "floor", "arena_floor", "stone", "glow"]


## The theme of the level node is in (null outside a themed level).
static func of(node: Node) -> LevelTheme:
	var n := node
	while n:
		var t = n.get("theme")
		if t is LevelTheme:
			return t
		n = n.get_parent()
	return null


## The real material for a surface name (null for unknown names).
func surface_material(surface: String) -> Material:
	match surface:
		"wall":
			return Build.pbr(wall_texture, wall_tint, wall_uv_scale, true, normal_strength)
		"floor":
			return Build.pbr(floor_texture, floor_tint, floor_uv_scale, true, normal_strength)
		"arena_floor":
			return Build.pbr(arena_floor_texture, arena_floor_tint, arena_floor_uv_scale, true, normal_strength)
		"stone":
			return Build.pbr(stone_texture, stone_tint, wall_uv_scale * 1.6, true, normal_strength)
		"glow":
			return Build.glow(glow_color, 3.0)
	return null


func make_environment() -> Environment:
	var e := Environment.new()
	if sky_material:
		e.background_mode = Environment.BG_SKY
		e.sky = Sky.new()
		e.sky.sky_material = sky_material
	else:
		e.background_mode = Environment.BG_COLOR
		e.background_color = background_color
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient_color
	e.ambient_light_energy = ambient_energy
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = exposure
	e.glow_enabled = true
	e.glow_intensity = glow_intensity
	e.glow_bloom = 0.08
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.fog_enabled = true
	e.fog_light_color = fog_color
	e.fog_density = fog_density
	e.fog_height = fog_height
	e.fog_height_density = fog_height_density
	e.volumetric_fog_enabled = volumetric_fog_density > 0.0
	e.volumetric_fog_density = volumetric_fog_density
	e.volumetric_fog_albedo = volumetric_fog_albedo
	e.volumetric_fog_emission = volumetric_fog_emission
	e.volumetric_fog_length = 48.0
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.6
	e.adjustment_enabled = true
	e.adjustment_saturation = saturation
	return e
