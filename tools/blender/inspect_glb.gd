extends SceneTree
## Loads each pet GLB and checks the names the stage relies on.
## Run: godot --headless --path . -s tools/blender/inspect_glb.gd   (exit code 0 = pass)

const PETS: Array[String] = ["cat", "dog", "bunny"]
const SHAPES: Array[String] = ["jaw_open", "blink_L", "blink_R", "smile", "ear_perk"]
const BONES: Array[String] = ["root", "spine", "chest", "head", "ear_L", "ear_R", "tail",
	"arm_L", "arm_R", "leg_L", "leg_R", "hold"]
const ANIMS: Array[String] = ["idle_breathe", "happy_bounce", "giggle", "paw_highfive_L",
	"paw_highfive_R", "listen_nod", "walk_in", "look_around", "stretch", "ear_perk",
	"yawn", "scratch_ear", "happy_wiggle", "laugh_tumble", "wave",
	"drink", "lap", "bite", "chew", "bat_paw_L", "bat_paw_R", "sniff",
	"excited", "sit_down", "sit_idle", "stand_up", "sit_hold_eat", "sit_hold_drink", "sit_lap",
	"sit_bat_L", "sit_bat_R", "lie_down", "lie_play", "get_up", "laugh", "head_shake",
	"run", "pounce", "jump"]
const LOOPED: Array[String] = ["idle_breathe", "walk_in", "sit_idle", "lie_play", "run"]
const MAX_TRIS := 15000

var _fails := 0


func _init() -> void:
	for pet in PETS:
		_inspect(pet)
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("  FAIL: " + msg)


func _inspect(pet: String) -> void:
	var path := "res://assets/characters/%s.glb" % pet
	var packed := load(path) as PackedScene
	_check(packed != null, "%s loads" % path)
	if packed == null:
		return
	var root := packed.instantiate()
	print("== %s" % pet)
	var total := 0
	var shapes: Dictionary = {}
	var skeleton: Skeleton3D = null
	var player: AnimationPlayer = null
	for n in _walk(root):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var tris := 0
			for s in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			total += tris
			var names: Array[String] = []
			for b in mi.get_blend_shape_count():
				var bn := String(mi.mesh.get_blend_shape_name(b))
				names.append(bn)
				shapes[bn] = root.get_path_to(mi)
			var mats: Array[String] = []
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				mats.append(m.resource_name if m else "?")
			print("  mesh %s: %d tris, surfaces %s, blend shapes %s" % [root.get_path_to(mi), tris, mats, names])
		elif n is Skeleton3D:
			skeleton = n
		elif n is AnimationPlayer:
			player = n
	print("  total tris: %d" % total)
	_check(total <= MAX_TRIS, "%s has %d tris (> %d)" % [pet, total, MAX_TRIS])
	for s in SHAPES:
		_check(shapes.has(s), "%s missing blend shape %s" % [pet, s])
	if pet == "bunny":
		_check(shapes.has("nose_twitch"), "bunny missing blend shape nose_twitch")
	if shapes.has("jaw_open"):
		print("  jaw/blink node: %s  (property blend_shapes/jaw_open)" % shapes["jaw_open"])

	_check(skeleton != null, "%s has a Skeleton3D" % pet)
	if skeleton:
		var bones: Array[String] = []
		for i in skeleton.get_bone_count():
			bones.append(skeleton.get_bone_name(i))
		print("  skeleton %s bones: %s" % [root.get_path_to(skeleton), bones])
		for b in BONES:
			_check(b in bones, "%s missing bone %s" % [pet, b])
		if pet == "bunny":
			_check("ear_L_tip" in bones and "ear_R_tip" in bones, "bunny ear tip bones")

	_check(player != null, "%s has an AnimationPlayer" % pet)
	if player:
		var anims: Array[String] = []
		for a in player.get_animation_list():
			var anim := player.get_animation(a)
			anims.append("%s(%.2fs%s)" % [a, anim.length, ", loop" if anim.loop_mode != Animation.LOOP_NONE else ""])
		print("  animations: %s" % ", ".join(anims))
		for a in ANIMS:
			_check(player.has_animation(a), "%s missing animation %s" % [pet, a])
		for a in LOOPED:
			if player.has_animation(a):
				_check(player.get_animation(a).loop_mode != Animation.LOOP_NONE, "%s %s should loop" % [pet, a])
	root.free()


func _walk(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
