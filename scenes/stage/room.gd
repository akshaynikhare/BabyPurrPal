class_name Room
extends Node3D
## Cozy pastel corner built from primitives: polka-dot walls, plank floor, rug,
## window, shelf, cushion and plant. Owns the one light and the
## environment, and tweens all of them between time-of-day looks.

const ROOM_SHADER := preload("res://shaders/room.gdshader")
const TOON_SHADER := preload("res://shaders/toon.gdshader")
const SKY_SHADER := preload("res://shaders/sky.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const PHASE_TWEEN_SEC := 1.6
const WALL_HEIGHT := 2.6
const WALL_LENGTH := 7.0

## Wall colours follow the old background gradients; light and ambient keep the pet readable.
const LOOKS := {
	&"sunrise": {
		wall = Color("#FFE3D3"), dots = Color("#FFF4EA"), floor = Color("#F2D2BC"), seam = Color("#E2B79D"),
		sky_top = Color("#FFB59A"), sky_bottom = Color("#FFF0E0"), orb = Color("#FFE08A"), orb_y = 0.62, stars = 0.0,
		light = Color("#FFE0C2"), light_energy = 0.32, ambient = Color("#FFF1E8"), ambient_energy = 0.86,
		rug = Color("#FFC4CF"), rug_ring = Color("#FFF4EA"), rug_rim = Color("#F49CB0"),
	},
	&"day": {
		wall = Color("#E3F0FB"), dots = Color("#FFFDF7"), floor = Color("#F3E2CB"), seam = Color("#DDC4A3"),
		sky_top = Color("#8FCBF2"), sky_bottom = Color("#E3F4FF"), orb = Color("#FFF2A8"), orb_y = 0.3, stars = 0.0,
		light = Color("#FFFFFF"), light_energy = 0.3, ambient = Color("#FFFCF6"), ambient_energy = 0.88,
		rug = Color("#FFD3DC"), rug_ring = Color("#FFF8EE"), rug_rim = Color("#F7A8BA"),
	},
	&"sunset": {
		wall = Color("#F1DDEA"), dots = Color("#FFE8D6"), floor = Color("#E9CDC3"), seam = Color("#D2AEA4"),
		sky_top = Color("#B79BDB"), sky_bottom = Color("#FFC59C"), orb = Color("#FFB37A"), orb_y = 0.7, stars = 0.15,
		light = Color("#FFD2B5"), light_energy = 0.32, ambient = Color("#F6E6F0"), ambient_energy = 0.84,
		rug = Color("#F8C3D2"), rug_ring = Color("#FFEDE2"), rug_rim = Color("#E79BB4"),
	},
	&"night": {
		wall = Color("#2B3561"), dots = Color("#46548A"), floor = Color("#3E4270"), seam = Color("#32365E"),
		sky_top = Color("#0B132B"), sky_bottom = Color("#1C2541"), orb = Color("#FFF6D5"), orb_y = 0.3, stars = 1.0,
		light = Color("#D2D4FF"), light_energy = 0.28, ambient = Color("#D3CBEA"), ambient_energy = 0.8,
		rug = Color("#8E7FC0"), rug_ring = Color("#A898D8"), rug_rim = Color("#7366A8"),
	},
}

var phase: StringName = &""

var _light: DirectionalLight3D
var _environment: Environment
var _wall: ShaderMaterial
var _floor: ShaderMaterial
var _rug: ShaderMaterial
var _sky: ShaderMaterial
var _from := {}
var _to := {}
var _tween: Tween


func _ready() -> void:
	_build_light_and_environment()
	_build_room()


func set_phase(next: StringName, animate: bool) -> void:
	if not LOOKS.has(next) or next == phase:
		return
	phase = next
	_to = LOOKS[next]
	if _tween:
		_tween.kill()
	if not animate or _from.is_empty():
		_from = _to
		_apply(1.0)
		return
	_tween = create_tween()
	_tween.tween_method(_apply, 0.0, 1.0, PHASE_TWEEN_SEC).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: _from = _to)


func _apply(t: float) -> void:
	_wall.set_shader_parameter(&"base_color", _mix(&"wall", t))
	_wall.set_shader_parameter(&"accent_color", _mix(&"dots", t))
	_floor.set_shader_parameter(&"base_color", _mix(&"floor", t))
	_floor.set_shader_parameter(&"accent_color", _mix(&"seam", t))
	_rug.set_shader_parameter(&"base_color", _mix(&"rug", t))
	_rug.set_shader_parameter(&"accent_color", _mix(&"rug_ring", t))
	_rug.set_shader_parameter(&"accent_color_2", _mix(&"rug_rim", t))
	_sky.set_shader_parameter(&"top_color", _mix(&"sky_top", t))
	_sky.set_shader_parameter(&"bottom_color", _mix(&"sky_bottom", t))
	_sky.set_shader_parameter(&"orb_color", _mix(&"orb", t))
	_sky.set_shader_parameter(&"orb_pos", Vector2(0.68, lerpf(_from.orb_y, _to.orb_y, t)))
	_sky.set_shader_parameter(&"stars", lerpf(_from.stars, _to.stars, t))
	_light.light_color = _mix(&"light", t)
	_light.light_energy = lerpf(_from.light_energy, _to.light_energy, t)
	_environment.ambient_light_color = _mix(&"ambient", t)
	_environment.ambient_light_energy = lerpf(_from.ambient_energy, _to.ambient_energy, t)
	_environment.background_color = _mix(&"wall", t)


func _mix(key: StringName, t: float) -> Color:
	return (_from[key] as Color).lerp(_to[key], t)


# Building --------------------------------------------------------------------

func _build_light_and_environment() -> void:
	_light = DirectionalLight3D.new()
	_light.shadow_enabled = false
	_light.light_specular = 0.0
	add_child(_light)
	_light.look_at_from_position(Vector3(1.6, 3.0, 2.6), Vector3.ZERO)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)


func _build_room() -> void:
	# The walls meet in a corner behind and left of the pet, turned for a 3/4 view.
	var corner := Node3D.new()
	corner.position = Vector3(-0.75, 0.0, -1.55)
	corner.rotation.y = -0.6
	add_child(corner)

	_wall = _room_material(1, Vector2(WALL_LENGTH, WALL_HEIGHT))
	_wall.set_shader_parameter(&"spacing", 0.16)
	_wall.set_shader_parameter(&"dot_radius", 0.15)
	_wall.set_shader_parameter(&"floor_shade", 0.1)
	# Wall A runs right along local +x; wall B runs toward the camera along local +z.
	_plane(corner, Vector2(WALL_LENGTH, WALL_HEIGHT), Vector3(WALL_LENGTH * 0.5, WALL_HEIGHT * 0.5, 0.0), Vector3.ZERO, _wall)
	_plane(corner, Vector2(WALL_LENGTH, WALL_HEIGHT), Vector3(0.0, WALL_HEIGHT * 0.5, WALL_LENGTH * 0.5), Vector3(0.0, PI * 0.5, 0.0), _wall)

	_floor = _room_material(2, Vector2(10.0, 10.0))
	_floor.set_shader_parameter(&"spacing", 0.22)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(10.0, 10.0)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = _floor
	floor_node.position = Vector3(5.0, 0.0, 5.0)
	corner.add_child(floor_node)

	var trim := _toon(Color("#FFF6EA"))
	_box(corner, Vector3(WALL_LENGTH, 0.08, 0.03), Vector3(WALL_LENGTH * 0.5, 0.04, 0.015), trim)
	_box(corner, Vector3(0.03, 0.08, WALL_LENGTH), Vector3(0.015, 0.04, WALL_LENGTH * 0.5), trim)

	_build_window(corner, Vector3(1.15, 1.08, 0.0))
	_build_shelf(corner, Vector3(0.0, 0.95, 0.75))
	_build_plant(corner, Vector3(0.28, 0.0, 0.28))
	_build_cushion(corner, Vector3(1.65, 0.0, 0.55))

	_rug = _room_material(3, Vector2.ONE)
	var rug_mesh := CylinderMesh.new()
	rug_mesh.top_radius = 0.6
	rug_mesh.bottom_radius = 0.6
	rug_mesh.height = 0.012
	rug_mesh.radial_segments = 40
	rug_mesh.rings = 1
	var rug := MeshInstance3D.new()
	rug.mesh = rug_mesh
	rug.material_override = _rug
	rug.position = Vector3(0.0, 0.006, 0.05)
	rug.scale = Vector3(1.0, 1.0, 0.72)
	add_child(rug)


func _build_window(parent: Node3D, center: Vector3) -> void:
	var size := Vector2(0.62, 0.74)
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	_sky.set_shader_parameter(&"aspect", size.x / size.y)
	_plane(parent, size, center + Vector3(0.0, 0.0, 0.01), Vector3.ZERO, _sky)
	var frame := _toon(Color("#FFF8EE"), true)
	var t := 0.045
	_box(parent, Vector3(size.x + t * 2.0, t, 0.08), center + Vector3(0.0, size.y * 0.5 + t * 0.5, 0.04), frame)
	_box(parent, Vector3(size.x + t * 2.0 + 0.08, t, 0.1), center + Vector3(0.0, -size.y * 0.5 - t * 0.5, 0.05), frame)
	_box(parent, Vector3(t, size.y, 0.08), center + Vector3(-size.x * 0.5 - t * 0.5, 0.0, 0.04), frame)
	_box(parent, Vector3(t, size.y, 0.08), center + Vector3(size.x * 0.5 + t * 0.5, 0.0, 0.04), frame)
	_box(parent, Vector3(0.025, size.y, 0.03), center + Vector3(0.0, 0.0, 0.03), frame)
	_box(parent, Vector3(size.x, 0.025, 0.03), center + Vector3(0.0, 0.0, 0.03), frame)
	var curtain := _toon(Color("#FFC8D4"), true)
	for side in [-1.0, 1.0]:
		var c := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.07
		capsule.height = size.y + 0.16
		capsule.radial_segments = 12
		capsule.rings = 4
		c.mesh = capsule
		c.material_override = curtain
		c.position = center + Vector3(side * (size.x * 0.5 + 0.08), -0.03, 0.09)
		c.scale = Vector3(1.0, 1.0, 0.45)
		parent.add_child(c)


func _build_shelf(parent: Node3D, at: Vector3) -> void:
	var wood := _toon(Color("#E8C49A"), true)
	_box(parent, Vector3(0.16, 0.035, 0.6), at + Vector3(0.08, 0.0, 0.0), wood)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	sphere.radial_segments = 16
	sphere.rings = 8
	ball.mesh = sphere
	ball.material_override = _toon(Color("#8ED9C8"), true)
	ball.position = at + Vector3(0.08, 0.072, -0.17)
	parent.add_child(ball)
	_box(parent, Vector3(0.09, 0.09, 0.09), at + Vector3(0.08, 0.062, 0.02), _toon(Color("#FFD166"), true))
	_box(parent, Vector3(0.07, 0.07, 0.07), at + Vector3(0.08, 0.052, 0.17), _toon(Color("#C9B6F2"), true))


func _build_plant(parent: Node3D, at: Vector3) -> void:
	var pot := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.11
	cyl.bottom_radius = 0.085
	cyl.height = 0.2
	cyl.radial_segments = 16
	cyl.rings = 1
	pot.mesh = cyl
	pot.material_override = _toon(Color("#F4A99B"), true)
	pot.position = at + Vector3(0.0, 0.1, 0.0)
	parent.add_child(pot)
	var leaf := _toon(Color("#8FD3A4"), true)
	var offsets: Array[Vector3] = [Vector3(0.0, 0.34, 0.0), Vector3(-0.07, 0.27, 0.05), Vector3(0.07, 0.28, -0.03)]
	for o in offsets:
		var bush := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		sphere.radial_segments = 14
		sphere.rings = 7
		bush.mesh = sphere
		bush.material_override = leaf
		bush.position = at + o
		parent.add_child(bush)


func _build_cushion(parent: Node3D, at: Vector3) -> void:
	var cushion := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.radial_segments = 20
	sphere.rings = 10
	cushion.mesh = sphere
	cushion.material_override = _toon(Color("#C9B6F2"), true)
	cushion.position = at + Vector3(0.0, 0.08, 0.0)
	cushion.scale = Vector3(1.0, 0.32, 0.8)
	parent.add_child(cushion)


# Helpers ---------------------------------------------------------------------

func _room_material(pattern: int, size: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROOM_SHADER
	m.set_shader_parameter(&"pattern", pattern)
	m.set_shader_parameter(&"size", size)
	return m


func _toon(color: Color, outlined := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter(&"albedo", color)
	m.set_shader_parameter(&"rim_strength", 0.05)
	if outlined:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter(&"thickness_px", 2.4)
		m.next_pass = outline
	return m


func _plane(parent: Node3D, size: Vector2, at: Vector3, rot: Vector3, material: Material) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.orientation = PlaneMesh.FACE_Z
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.rotation = rot
	parent.add_child(node)


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
