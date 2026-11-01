class_name ToyProp
extends Node3D
## One toy's prop with the pets' toon look: its GLB, or a toon ball in the toy's
## colour while the GLB is missing. Exposes the parts a session moves.

const PATH := "res://assets/props/%s.glb"
const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
## See-through or glinting surfaces get no hull.
const UNOUTLINED: Array[String] = ["liquid", "glass", "highlight"]
## Named parts; every node is a direct child of the GLB root.
const LIQUIDS := {&"milk": "milk_liquid", &"water": "water_liquid"}
const SPINS := {&"yarn": "yarn_ball", &"ball": "ball"}
## The glass goes up to the mouth with its milk; the saucer stays on the floor.
const CUP: Array[String] = ["milk_glass", "milk_liquid"]
const PLACEHOLDER_RADIUS := 0.06

static var _outline: ShaderMaterial

var toy_id: StringName
## Lifted to the mouth, tilted, squashed and swung.
var body: Node3D
## Rolls about its own centre.
var spin: Node3D
var spin_radius := 1.0
## Drains by scale.y.
var liquid: Node3D
## Height of the origin above the prop's lowest point.
var floor_lift := 0.0
var _stages: Array[Node3D] = []


func _init(id: StringName = &"") -> void:
	toy_id = id
	name = String(id).capitalize()


func _ready() -> void:
	var path := PATH % toy_id
	if ResourceLoader.exists(path):
		body = (load(path) as PackedScene).instantiate()
	else:
		body = _placeholder()
	add_child(body)
	for node in body.find_children("*", "MeshInstance3D", false, false):
		_apply_materials(node)
	floor_lift = -_bounds().position.y
	liquid = body.get_node_or_null(LIQUIDS.get(toy_id, ""))
	spin = body.get_node_or_null(SPINS.get(toy_id, ""))
	if spin is MeshInstance3D:
		spin_radius = (spin as MeshInstance3D).get_aabb().size.y * 0.5
	for i in ToyScript.LAST_STAGE + 1:
		var stage := body.get_node_or_null("%s_stage%d" % [toy_id, i])
		if stage:
			_stages.append(stage)
	if toy_id == &"milk":
		var cup := Node3D.new()
		cup.name = "Cup"
		add_child(cup)
		for part in CUP:
			var node := body.get_node_or_null(part)
			if node:
				node.reparent(cup, false)
		body = cup


## Back to whole, full and upright.
func reset() -> void:
	show_stage(0)
	if liquid:
		liquid.scale = Vector3.ONE
	if spin:
		spin.rotation = Vector3.ZERO
	body.transform = Transform3D.IDENTITY


## Shows exactly one stage mesh (0 whole .. 3 eaten), if the prop has stages.
func show_stage(stage: int) -> void:
	for i in _stages.size():
		_stages[i].visible = i == stage


## Same look as the pets (Pet._apply_materials). The glass keeps its own
## see-through material: the toon shader is opaque and would hide the milk.
func _apply_materials(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	for s in mesh.get_surface_count():
		var source := mesh.surface_get_material(s) as BaseMaterial3D
		var surface := source.resource_name if source else ""
		if surface == "glass":
			continue
		var material := ShaderMaterial.new()
		material.shader = TOON_SHADER
		material.set_shader_parameter(&"albedo", source.albedo_color if source else Color.WHITE)
		match surface:
			"highlight":
				material.set_shader_parameter(&"self_light", 1.0)
				material.set_shader_parameter(&"rim_strength", 0.0)
			"eye", "liquid":
				material.set_shader_parameter(&"self_light", 0.15)
				material.set_shader_parameter(&"rim_strength", 0.0)
			_:
				material.set_shader_parameter(&"rim_strength", 0.07)
		if surface not in UNOUTLINED:
			material.next_pass = _outline_material()
		mesh_instance.set_surface_override_material(s, material)


static func _outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	return _outline


## Resting on the floor at its origin, coloured like the toy's button.
func _placeholder() -> Node3D:
	var root := Node3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = PLACEHOLDER_RADIUS
	mesh.height = PLACEHOLDER_RADIUS * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = UiStyle.CREAM
	for pet in PetReactions.PET_IDS.size():
		for toy: Dictionary in ToyCatalog.toys_for(pet):
			if toy.id == toy_id:
				material.albedo_color = toy.fill
	mesh.material = material
	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	ball.position.y = PLACEHOLDER_RADIUS
	root.add_child(ball)
	return root


func _bounds() -> AABB:
	var box := AABB()
	var first := true
	for node in body.find_children("*", "MeshInstance3D", false, false):
		var mesh_instance := node as MeshInstance3D
		var part := mesh_instance.transform * mesh_instance.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box
