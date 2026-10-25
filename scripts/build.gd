class_name Build
## Helpers that build simple models out of Godot shapes (spheres, boxes, cones...).


static func mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


## A material that glows (works great with the glow effect in the dark caves).
static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func see_through(color: Color, energy := 0.5) -> StandardMaterial3D:
	var m := glow(color, energy)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic_specular = 1.0
	return m


## Glowing, swirly lava (move uv1_offset every frame to make it flow).
static func lava_material() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.05, 0.0))
	ramp.set_color(1, Color(1.0, 0.75, 0.2))
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.emission_enabled = true
	m.emission_texture = tex
	# Tinted orange so bright spots stay lava-colored instead of turning white.
	m.albedo_color = Color(1.0, 0.55, 0.3)
	m.emission = Color(1.0, 0.45, 0.12)
	m.emission_energy_multiplier = 1.6
	m.uv1_scale = Vector3(2, 2, 2)
	return m


static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


static func cylinder(radius: float, height: float, top_radius := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = 20
	return m


static func cone(radius: float, height: float) -> CylinderMesh:
	return cylinder(radius, height, 0.0)


static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 32
	m.ring_segments = 12
	return m


## Adds a mesh to parent and returns it.
static func part(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func light(parent: Node3D, color: Color, energy: float, light_range: float,
		pos := Vector3.ZERO, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.position = pos
	l.shadow_enabled = shadows
	parent.add_child(l)
	return l


static func collision_box(parent: Node, size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)
	return cs


static func collision_capsule(parent: Node, radius: float, height: float, pos := Vector3.ZERO) -> CollisionShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)
	return cs


static func collision_sphere(parent: Node, radius: float, pos := Vector3.ZERO) -> CollisionShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)
	return cs


static func label3d(parent: Node3D, text: String, pos: Vector3, font_size := 48,
		color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = font_size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l
