extends Node3D
## Shared level script: bakes the monster navigation when the level starts.

@export var nav_region: NavigationRegion3D


func _ready() -> void:
	add_to_group("level")
	if nav_region == null:
		nav_region = get_node_or_null("Nav") as NavigationRegion3D
	if nav_region:
		# Wait for the CSG floors and walls to build their meshes first.
		await get_tree().physics_frame
		await get_tree().physics_frame
		nav_region.bake_navigation_mesh(true)
