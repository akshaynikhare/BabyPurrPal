class_name Pet
extends Node3D
## One pet on stage: loads its GLB, swaps in toon + outline materials, layers
## one-shot reactions over the idle loop, drives the face blend shapes (blink,
## jaw, smile, ear perk) and owns the bone-attached touch zones. The procedural
## layers (head look, squash, idle life) live in HeadLook, BodyBounce and PetIdle.

## Nobody has touched the pet for a while and it waved; the stage adds the greeting.
signal called_to_play
## An idle break started with this clip; the stage may add a line (a yawn at night).
signal idle_break(clip: StringName)

const ZONE_LAYER := 1 << 4
const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const BLOB_SHADER := preload("res://shaders/blob_shadow.gdshader")
## Thin shells (belly, eyes, cheeks...) sit on top of these and must not get a hull.
const OUTLINED: Array[String] = ["body", "ear", "paw", "collar", "collar_tag", "tail_puff"]

## The 3D tongue sits in the mouth; any pull toward the camera draws it over the lower lip.
const TONGUE_BIAS := 0.0
const IDLE := PetClips.IDLE
const WALK := PetClips.WALK
const RUN := &"run"
## walk_in played this much faster stands in for a missing run loop.
const RUN_STAND_IN_SPEED := 1.8
## Turned a little toward screen-left for the 3/4 view.
const FACING_YAW := -0.38
const BLINK_SEC := 0.15
const MIN_BLINK_GAP := 3.4
const MAX_BLINK_GAP := 3.8
const FACE_SPEED := 7.0
## Only the ones the GLB has are used.
const IDLE_BREAKS: Array[StringName] = [&"look_around", &"stretch", &"yawn", &"scratch_ear", &"happy_wiggle"]
const NOSE_SEC := 0.25
const COME_PLAY_LOOK_SEC := 2.5
## The dog's floppy ears stick straight out at full ear_perk; a lift reads better.
const DOG_PERK_SCALE := 0.4
const SURPRISE_SQUASH := 0.12

var pet_id: StringName
## Mouth opening from talk-back playback, 0..1.
var jaw_talk := 0.0
var look: HeadLook
var bounce: BodyBounce
## A toy session owns the body: idle breaks, nods and reactions don't cut in.
var acting := false

var _model: Node3D
var _skeleton: Skeleton3D
var _head: MeshInstance3D
var _player: AnimationPlayer
var _clips: PetClips
var _droop: EarDroop
var _droop_tween: Tween
var _face_offset := Vector3.ZERO
var _belly_offset := Vector3.ZERO
var _zone_centers := {}
var _bounds := AABB()
var _mouth_bone: Node3D
var _hold_bone: Node3D
var _mouth_local := Vector3.ZERO

var _shape_jaw := -1
var _shape_blink_l := -1
var _shape_blink_r := -1
var _shape_smile := -1
var _shape_perk := -1
var _shape_nose := -1

var _smile := 0.0
var _squint := 0.0
var _perk := 0.0
var _perk_scale := 1.0
var _chomp_left := 0.0
var _mood_smile := 0.0
var _mood_squint := 0.0
var _mood_left := 0.0
var _rest_smile := 0.15
var _rest_perk := 0.0
var _pulse_perk_left := 0.0
var _nose_t := -1.0
var _nose_twitches := 2
## Face keys this frame (jaw, blink L, smile, perk, nose, blink R), matching
## _face_shapes; clips that animate the face may only raise them.
var _face := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _face_shapes := PackedInt32Array()

var _blink_left := 3.6
var _blink_t := -1.0
var _busy_left := 0.0
var _walking := false
var _listening := false
var _talking := false
var _nod_left := 0.0
var _idle := PetIdle.new()
var _idle_breaks: Array = []
var _pickers := {}
var _surprises := NoRepeatPicker.new(PetSounds.SURPRISES.size())
var _rng := RandomNumberGenerator.new()
## The clip's timed body sounds (PetSounds.CLIPS); a new clip drops the rest.
var _cue_tween: Tween
## The run patter plays until the run clip gives way.
var _running := false


func _init(id: StringName = &"cat") -> void:
	pet_id = id
	name = String(id).capitalize()


func _ready() -> void:
	_rng.randomize()
	if pet_id == &"dog":
		_perk_scale = DOG_PERK_SCALE
	_load_model()
	_build_zones()
	_build_shadow()
	_clips = PetClips.new(_player)
	_idle_breaks = _clips.variants_of(IDLE_BREAKS)
	_player.play(IDLE)
	rotation.y = FACING_YAW
	_blink_left = _rng.randf_range(MIN_BLINK_GAP, MAX_BLINK_GAP)


# Public ----------------------------------------------------------------------

## Plays one variant (picked without repeats) from a list of clip sequences; returns it.
func play_variant(key: StringName, variants: Array) -> Array:
	if variants.is_empty():
		return []
	if not _pickers.has(key):
		_pickers[key] = NoRepeatPicker.new(variants.size())
	var clips: Array = variants[(_pickers[key] as NoRepeatPicker).pick()]
	play_sequence(clips)
	return clips


func play_sequence(clips: Array) -> void:
	if not acting:
		_play(clips)


## Plays a toy action, or `stand_in` while this GLB lacks it, even while acting,
## then holds `rest` (sit_idle...) instead of idle if the GLB has it.
## Returns its length, 0 if neither exists.
func play_toy_clip(clip: StringName, stand_in: StringName, rest: StringName = &"") -> float:
	var length := _play([clip if _player.has_animation(clip) else stand_in])
	if _player.has_animation(rest):
		_player.clear_queue()
		_player.queue(rest)
	return length


## The run loop for a chase (walk_in, faster, while this GLB lacks it); the caller moves the pet.
## The run patter plays until the next clip starts.
func play_run() -> void:
	var real := _player.has_animation(RUN)
	_player.clear_queue()
	_player.play(RUN if real else WALK, PetClips.REACT_BLEND_SEC, 1.0 if real else RUN_STAND_IN_SPEED)
	_running = true
	AudioDirector.start_sfx(PetSounds.RUN)


func is_busy() -> bool:
	return _busy_left > 0.0


## A touch restarts the quiet clock that leads to "come play".
func notice_touch() -> void:
	_idle.touched()


## A quick nose wiggle, if this GLB has the nose_twitch shape key.
func twitch_nose(twitches: int = 2) -> void:
	if _shape_nose >= 0 and _nose_t < 0.0:
		_nose_t = 0.0
		_nose_twitches = twitches


## Face expression for a while: happy (smile), tickled (smile + squint), purr (happy eyes).
func set_mood(mood: StringName, ms: int) -> void:
	match mood:
		PetReactions.HAPPY:
			_mood_smile = 1.0
			_mood_squint = 0.2
		PetReactions.TICKLED:
			_mood_smile = 1.0
			_mood_squint = 0.75
		PetReactions.PURR:
			_mood_smile = 0.8
			_mood_squint = 0.65
		_:
			return
	_mood_left = maxf(_mood_left, ms / 1000.0)


## Three quick munches with the jaw.
func chomp() -> void:
	_chomp_left = 0.9


## A short ear perk (zone touch), on top of the talk-back state.
func perk_ears(seconds: float) -> void:
	_pulse_perk_left = seconds


func set_talk_state(state: StringName) -> void:
	_listening = state == TalkBack.LISTEN
	_talking = state == TalkBack.TALK
	look.set_listening(_listening)
	look.talking = _talking
	if _listening or _talking:
		_idle.touched()
	if _listening:
		_nod_left = _rng.randf_range(0.2, 0.6)
	match state:
		TalkBack.LISTEN:
			_rest_perk = 1.0
			_rest_smile = 0.3
		TalkBack.TALK:
			_rest_perk = 0.5
			_rest_smile = 0.5
		TalkBack.CELEBRATE:
			_rest_perk = 0.3
			_rest_smile = 0.6
			play_sequence([&"happy_bounce"])
			set_mood(PetReactions.HAPPY, 700)
		TalkBack.DONT_HEAR:
			_rest_perk = 0.0
			_rest_smile = 0.0
		_:
			_rest_perk = 0.0
			_rest_smile = 0.15
	_set_droop(state == TalkBack.DONT_HEAR)


## Walks along x from `from_x` to `to_x` with the walk loop, facing the way it goes.
func walk(from_x: float, to_x: float, duration: float, hide_after: bool) -> Tween:
	_walking = true
	_idle.touched()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	position.x = from_x
	rotation.y = PI * 0.5 if to_x > from_x else -PI * 0.5
	_player.clear_queue()
	_player.play(WALK, 0.1)
	var tween := create_tween()
	tween.tween_property(self, "position:x", to_x, duration)
	tween.tween_callback(_on_walk_done.bind(hide_after))
	if not hide_after:
		tween.tween_property(self, "rotation:y", FACING_YAW, 0.3).set_trans(Tween.TRANS_SINE)
	return tween


func set_active(active: bool) -> void:
	visible = active
	# Disabling also pulls the zone areas out of the physics space.
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func is_walking() -> bool:
	return _walking


## World position of a zone's centre (particles, toys).
func zone_point(zone: StringName) -> Vector3:
	return global_transform * (_zone_centers.get(zone, _face_offset) as Vector3)


## World position of the mouth as posed right now; a held toy follows the head.
func mouth_point() -> Vector3:
	return _mouth_bone.global_transform * _mouth_local


## Whether the GLB has the `hold` bone between the paws.
func has_hold() -> bool:
	return _hold_bone != null


## World position of the paws' hold bone as posed right now.
func hold_point() -> Vector3:
	return _hold_bone.global_position


## World-space point between the eyes, at rest; the zoom camera aims here.
func face_point() -> Vector3:
	return global_transform * _face_offset


## World-space box around the head and body at rest.
func body_bounds() -> AABB:
	return global_transform * _bounds


# Frame update ----------------------------------------------------------------

func _process(delta: float) -> void:
	_update_timers(delta)
	_update_face(delta)


func _update_timers(delta: float) -> void:
	if _busy_left > 0.0:
		_busy_left -= delta
	if _mood_left > 0.0:
		_mood_left -= delta
	if _pulse_perk_left > 0.0:
		_pulse_perk_left -= delta
	if _chomp_left > 0.0:
		_chomp_left -= delta

	_blink_left -= delta
	if _blink_left <= 0.0:
		_blink_left = _rng.randf_range(MIN_BLINK_GAP, MAX_BLINK_GAP)
		_blink_t = 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t > BLINK_SEC:
			_blink_t = -1.0
	if _shape_nose >= 0:
		var twitches := _idle.nose(delta)
		if twitches > 0:
			twitch_nose(twitches)

	if _walking:
		return
	if _listening:
		if _busy_left > 0.0:
			return
		_nod_left -= delta
		if _nod_left <= 0.0:
			_nod_left = _rng.randf_range(0.8, 1.6)
			play_sequence([&"listen_nod"])
		return
	match _idle.update(delta, _busy_left <= 0.0 and not _talking):
		PetIdle.Event.BREAK:
			if not acting and not _idle_breaks.is_empty():
				var clips := play_variant(&"idle_break", _idle_breaks)
				_blink_left = 0.3
				idle_break.emit(clips[0])
		PetIdle.Event.COME_PLAY:
			look.focus(COME_PLAY_LOOK_SEC)
			play_sequence([&"wave"])
			called_to_play.emit()
	if _idle.surprise(delta, _busy_left <= 0.0 and not _talking and not acting):
		_surprise()


## A sneeze (with a nose twitch) or a hiccup: its sound and a little squash.
func _surprise() -> void:
	var sound := PetSounds.SURPRISES[_surprises.pick()]
	AudioDirector.play_sfx(sound)
	bounce.squash(SURPRISE_SQUASH)
	if sound == &"sneeze":
		twitch_nose(3)
	_idle.delay_break()


## Plays the clip's timed body sounds, and ends the run patter once the run gives way.
func _on_clip_started(clip: StringName) -> void:
	if _cue_tween:
		_cue_tween.kill()
		_cue_tween = null
	if _running and clip != RUN:
		_running = false
		AudioDirector.stop_sfx(PetSounds.RUN)
	var cues: Array = PetSounds.CLIPS.get(_clips.base_of(clip), [])
	if cues.is_empty():
		return
	_cue_tween = create_tween()
	var at := 0.0
	for cue: Array in cues:
		var sound := PetSounds.pick(cue[1], pet_id)
		if sound == &"":
			continue
		_cue_tween.tween_interval(cue[0] - at)
		_cue_tween.tween_callback(AudioDirector.play_sfx.bind(sound))
		at = cue[0]


func _update_face(delta: float) -> void:
	var k := 1.0 - exp(-FACE_SPEED * delta)
	var mood_on := _mood_left > 0.0
	_smile = lerpf(_smile, _mood_smile if mood_on else _rest_smile, k)
	_squint = lerpf(_squint, _mood_squint if mood_on else 0.0, k)
	_perk = lerpf(_perk, 1.0 if _pulse_perk_left > 0.0 else _rest_perk, k)
	var blink := sin(PI * _blink_t / BLINK_SEC) if _blink_t >= 0.0 else 0.0
	var eyes := maxf(blink, _squint)
	var jaw := jaw_talk
	if _chomp_left > 0.0:
		jaw = maxf(jaw, 0.55 * absf(sin(_chomp_left * TAU * 1.67)))
	look.talk = jaw_talk
	var nose := 0.0
	if _nose_t >= 0.0:
		_nose_t += delta
		nose = absf(sin(PI * _nose_twitches * minf(_nose_t / NOSE_SEC, 1.0)))
		if _nose_t >= NOSE_SEC:
			_nose_t = -1.0
	_face[0] = jaw
	_face[1] = eyes
	_face[2] = _smile
	_face[3] = _perk * _perk_scale
	_face[4] = nose
	_face[5] = eyes
	# Zeroed before the AnimationPlayer runs (it's our child, so it processes
	# after us); keys a clip doesn't animate then come back from _face alone.
	for i in _face_shapes.size():
		if _face_shapes[i] >= 0:
			_head.set_blend_shape_value(_face_shapes[i], 0.0)


## The clip has written its face keys; ours win wherever they are larger, so talk,
## blinks, moods and ear perks keep showing through yawns and scratches.
func _on_mixer_applied() -> void:
	for i in _face_shapes.size():
		var shape := _face_shapes[i]
		if shape >= 0:
			_head.set_blend_shape_value(shape, maxf(_head.get_blend_shape_value(shape), _face[i]))


func _play(clips: Array) -> float:
	if _walking or clips.is_empty():
		return 0.0
	var length := _clips.play(clips)
	if length > 0.0:
		_busy_left = length
		_idle.delay_break()
	return length


func _on_walk_done(hide_after: bool) -> void:
	_walking = false
	if hide_after:
		set_active(false)
		return
	_player.play(IDLE, PetClips.IDLE_BLEND_SEC)
	_idle.delay_break()


func _set_droop(on: bool) -> void:
	if _droop_tween:
		_droop_tween.kill()
	_droop.active = true
	_droop_tween = create_tween()
	_droop_tween.tween_property(_droop, "influence", 1.0 if on else 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	if not on:
		_droop_tween.tween_callback(func() -> void: _droop.active = false)


# Building --------------------------------------------------------------------

func _load_model() -> void:
	var id := String(pet_id)
	_model = (load("res://assets/characters/%s.glb" % id) as PackedScene).instantiate()
	add_child(_model)
	_skeleton = _model.get_node("%s_rig/Skeleton3D" % id)
	_head = _skeleton.get_node("%s_head" % id)
	_player = _model.get_node("AnimationPlayer")
	_shape_jaw = _head.find_blend_shape_by_name(&"jaw_open")
	_shape_blink_l = _head.find_blend_shape_by_name(&"blink_L")
	_shape_blink_r = _head.find_blend_shape_by_name(&"blink_R")
	_shape_smile = _head.find_blend_shape_by_name(&"smile")
	_shape_perk = _head.find_blend_shape_by_name(&"ear_perk")
	_shape_nose = _head.find_blend_shape_by_name(&"nose_twitch")
	_face_shapes = PackedInt32Array([_shape_jaw, _shape_blink_l, _shape_smile, _shape_perk, _shape_nose, _shape_blink_r])
	_player.mixer_applied.connect(_on_mixer_applied)
	# Also fires for queued clips, so every clip of a sequence gets its sounds.
	_player.animation_started.connect(_on_clip_started)
	var body: MeshInstance3D = _skeleton.get_node("%s_body" % id)
	_apply_materials(_head)
	_apply_materials(body)
	var nose := _surface_center(_head, "nose")
	_face_offset = nose + Vector3(0.0, 0.06, -0.12)
	_belly_offset = _surface_center(body, "belly")
	_bounds = _head.get_aabb().merge(body.get_aabb())
	_build_motion()
	_build_droop()
	if _skeleton.find_bone("hold") >= 0:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "hold"
		_skeleton.add_child(attachment)
		_hold_bone = attachment


func _apply_materials(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	for s in mesh.get_surface_count():
		var source := mesh.surface_get_material(s) as BaseMaterial3D
		var surface := source.resource_name if source else ""
		var material := ShaderMaterial.new()
		material.shader = TOON_SHADER
		material.set_shader_parameter(&"albedo", source.albedo_color if source else Color.WHITE)
		match surface:
			"eye_highlight":
				material.set_shader_parameter(&"self_light", 1.0)
				material.set_shader_parameter(&"rim_strength", 0.0)
			"eye", "mouth_inner", "mouth_deep":
				material.set_shader_parameter(&"self_light", 0.15)
				material.set_shader_parameter(&"rim_strength", 0.0)
			"tongue":
				material.set_shader_parameter(&"self_light", 0.15)
				material.set_shader_parameter(&"rim_strength", 0.0)
				material.set_shader_parameter(&"view_bias", TONGUE_BIAS)
			"cheek", "nose", "ear_inner":
				material.set_shader_parameter(&"self_light", 0.2)
				material.set_shader_parameter(&"rim_strength", 0.04)
			_:
				material.set_shader_parameter(&"rim_strength", 0.07)
		if surface in OUTLINED:
			material.next_pass = _outline_material()
		mesh_instance.set_surface_override_material(s, material)


static var _outline: ShaderMaterial

static func _outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	return _outline


func _surface_center(mesh_instance: MeshInstance3D, surface_name: String) -> Vector3:
	var mesh := mesh_instance.mesh
	for s in mesh.get_surface_count():
		var material := mesh.surface_get_material(s)
		if material and material.resource_name == surface_name:
			var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var sum := Vector3.ZERO
			for v in verts:
				sum += v
			return sum / maxf(verts.size(), 1)
	return mesh_instance.get_aabb().get_center()


## Squash first (it moves everything), then the head look; the ear droop is added after.
func _build_motion() -> void:
	bounce = BodyBounce.new()
	bounce.setup(_skeleton.find_bone("root"))
	_skeleton.add_child(bounce)
	look = HeadLook.new()
	look.setup(_skeleton.find_bone("chest"), _skeleton.find_bone("head"), _face_offset)
	_skeleton.add_child(look)


func _build_droop() -> void:
	_droop = EarDroop.new()
	_skeleton.add_child(_droop)
	for side in [1.0, -1.0]:
		var bone := _skeleton.find_bone("ear_L" if side > 0.0 else "ear_R")
		if pet_id == &"dog":
			# Floppy ears tuck back and in; a talking flick swings them forward a little.
			_droop.add_bone(bone, Vector3(1.0, 0.0, -0.4 * side), 0.45)
			look.add_ear(bone, Vector3(1.0, 0.0, -0.4 * side), -0.3)
		else:
			# Upright ears fall outward; a talking flick is a small outward twitch.
			_droop.add_bone(bone, Vector3(0.15 * side, 0.0, 1.0), -1.0 * side)
			look.add_ear(bone, Vector3(0.15 * side, 0.0, 1.0), -0.3 * side)
	_droop.influence = 0.0
	_droop.active = false


## Generous spheres for toddler fingers, positioned in model space at rest and
## parented to the bone that moves them.
func _build_zones() -> void:
	var nose := _surface_center(_head, "nose")
	var rest := func(bone: String) -> Vector3:
		return _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).origin
	var head_top: Vector3 = rest.call("head") + Vector3(0.0, 0.36, 0.0)
	if pet_id == &"bunny":
		head_top = rest.call("head") + Vector3(0.0, 0.32, 0.0)

	_add_zone(&"mouth", "head", nose + Vector3(0.0, -0.05, 0.03), 0.085)
	for side in [1.0, -1.0]:
		var suffix := "_L" if side > 0.0 else "_R"
		_add_zone(&"cheeks", "head", nose + Vector3(0.155 * side, -0.02, -0.05), 0.095)
		var arm: Vector3 = rest.call("arm" + suffix)
		_add_zone(&"paw" + suffix, "arm" + suffix, arm + Vector3(0.05 * side, -0.08, 0.07), 0.1)
		var ear: Vector3 = rest.call("ear" + suffix)
		match pet_id:
			&"dog":
				_add_zone(&"ears", "ear" + suffix, ear + Vector3(0.21 * side, -0.17, 0.02), 0.14)
			&"bunny":
				_add_zone(&"ears", "ear" + suffix, ear + Vector3(0.02 * side, 0.12, 0.0), 0.1)
				_add_zone(&"ears", "ear" + suffix + "_tip", rest.call("ear" + suffix + "_tip") + Vector3(0.0, 0.1, 0.0), 0.1)
			_:
				_add_zone(&"ears", "ear" + suffix, ear + Vector3(0.03 * side, 0.08, 0.0), 0.11)
	_add_zone(&"ears", "head", head_top, 0.21)
	_add_zone(&"belly", "chest", _belly_offset + Vector3(0.0, 0.0, 0.03), 0.18)
	_zone_centers[&"mouth"] = nose + Vector3(0.0, -0.05, 0.08)
	_zone_centers[&"cheeks"] = nose + Vector3(0.0, -0.02, 0.05)
	_zone_centers[&"ears"] = head_top + Vector3(0.0, 0.05, 0.1)
	_zone_centers[&"belly"] = _belly_offset + Vector3(0.0, 0.0, 0.12)
	_mouth_local = _skeleton.get_bone_global_rest(_skeleton.find_bone("head")).affine_inverse() * (_zone_centers[&"mouth"] as Vector3)


func _add_zone(zone: StringName, bone_name: String, model_point: Vector3, radius: float) -> void:
	var bone := _skeleton.find_bone(bone_name)
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	var area := Area3D.new()
	area.collision_layer = ZONE_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta(&"zone", zone)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)
	attachment.add_child(area)
	if zone == &"mouth":
		_mouth_bone = attachment
	# Attachment follows the bone's posed transform; offset back into bone space.
	area.position = _skeleton.get_bone_global_rest(bone).affine_inverse() * model_point
	if not _zone_centers.has(zone):
		_zone_centers[zone] = model_point


func _build_shadow() -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.62, 0.5)
	mesh.orientation = PlaneMesh.FACE_Y
	quad.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = BLOB_SHADER
	quad.material_override = material
	# Just above the rug.
	quad.position = Vector3(0.0, 0.02, -0.02)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
