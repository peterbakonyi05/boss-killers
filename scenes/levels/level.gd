extends Node3D
## Shared level script: applies the level theme (sky, fog, textures, props, spooky
## extras) and bakes the monster navigation when the level starts.

@export var nav_region: NavigationRegion3D
## How the level looks. See data/themes/ and scripts/data/level_theme.gd.
@export var theme: LevelTheme

var dresser: LevelDresser
var ambient: AmbientFX


func _ready() -> void:
	add_to_group("level")
	if nav_region == null:
		nav_region = get_node_or_null("Nav") as NavigationRegion3D
	if theme:
		_apply_theme()
	if nav_region:
		# Wait for the CSG floors and walls to build their meshes first.
		await get_tree().physics_frame
		await get_tree().physics_frame
		nav_region.bake_navigation_mesh(true)
	if theme:
		dresser = LevelDresser.new()
		dresser.name = "Dresser"
		add_child(dresser)
		var geometry := nav_region.get_node_or_null("Geometry") as Node3D if nav_region else null
		if geometry:
			dresser.dress(theme, geometry)
		ambient = AmbientFX.new()
		ambient.name = "AmbientFX"
		add_child(ambient)
		ambient.setup(theme, dresser)


func _apply_theme() -> void:
	var env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null:
		env = WorldEnvironment.new()
		add_child(env)
	env.environment = theme.make_environment()
	# Swap the placeholder surface materials (data/surfaces/*.tres) for the theme's.
	for node in find_children("*", "CSGShape3D", true, false):
		var csg := node as CSGShape3D
		var m: Material = csg.get("material")
		if m == null or not m.resource_path.begins_with("res://data/surfaces/"):
			continue
		var real := theme.surface_material(m.resource_path.get_file().get_basename())
		if real:
			csg.set("material", real)
