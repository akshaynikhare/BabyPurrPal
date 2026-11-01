class_name ToySession
extends Node3D
## Runs one toy at a time (ToyScript): the prop pops in, the pet drinks, eats or
## plays with it, the prop leaves and the pet shows its mood. Emits toy_started
## and toy_finished; app pause or a pet change cancels. Positions are in the
## pet's space, +Z its forward.

## The mood finale; the stage plays it like any reaction (sound, mood, purr, particles).
signal performed(reaction: Dictionary)

enum Slot { STEP, MOVE, SIZE, SQUASH, DRAIN }

const FLOOR_Y := 0.01
const FRONT_Z := 0.38
## Rolling toys come in and leave from off screen.
const SIDE_X := 0.9
const DROP_HEIGHT := 0.6
const BELL_Z := 0.3
const BELL_DROP := 0.9
## Ribbon top above the paws, so the bell's lip hangs at paw height.
const BELL_HANG := 0.12
const BAT_ROLL := 0.3
const BAT_SEC := 0.3
const HOP_HEIGHT := 0.14
const HOP_SEC := 0.42
const DRAIN_SEC := 0.3
const LOOK_SEC := 0.3
const SPARKLES := 4
const CRUMBS := 3
const DROPLETS := 3
## Pendulum on the bell's ribbon; a kick gives a first swing of about 35°.
const SWING_OMEGA := 7.0
const SWING_DAMPING := 0.12
const SWING_KICK := 4.3
const MAX_STEP := 1.0 / 30.0
const GULPS: Array[StringName] = [&"gulp_1", &"gulp_2", &"gulp_3"]
const LAPS: Array[StringName] = [&"lap_1", &"lap_2"]
const MUNCHES: Array[StringName] = [&"munch_1", &"munch_2", &"crunch"]
const BOUNCES: Array[StringName] = [&"bounce_1", &"bounce_2"]
const JINGLES: Array[StringName] = [&"jingle_1", &"jingle_2"]

var toy_id: StringName = &""
var _fx: ParticleFx
var _pet: Pet
var _prop: ToyProp
var _props := {}
var _data: Dictionary
var _steps: Array
var _step := -1
var _replaying := false
var _hits := 0
var _tweens: Array[Tween] = [null, null, null, null, null]
## Tweened, then applied every frame: the prop's origin in pet space, its blend
## to the held point at the mouth, tilt, pop size, landing squash.
var _offset := Vector3.ZERO
var _hold := 0.0
var _hold_offset := Vector3.ZERO
var _tilt := 0.0
var _size := 1.0
var _squash := 0.0
## Bell pendulum (angle, velocity).
var _swing := Vector2.ZERO


func _init(fx: ParticleFx = null) -> void:
	_fx = fx
	name = "ToySession"


func _ready() -> void:
	set_process(false)
	EventBus.app_paused.connect(cancel)
	EventBus.pet_changed.connect(func(_index: int, _name: String) -> void: cancel())


func is_running() -> bool:
	return toy_id != &""


## Starts a toy for this pet; ignored (false) while another one runs.
func start(id: StringName, pet: Pet) -> bool:
	if is_running() or not ToyScript.TOYS.has(id):
		return false
	toy_id = id
	_pet = pet
	_data = ToyScript.TOYS[id]
	_steps = _data.steps
	_step = -1
	_hits = 0
	_hold = 0.0
	_hold_offset = _data.get("hold", Vector3.ZERO)
	_tilt = 0.0
	_size = 0.0
	_squash = 0.0
	_swing = Vector2.ZERO
	_prop = _prop_for(id)
	_prop.reset()
	_prop.visible = false
	pet.acting = true
	pet.notice_touch()
	set_process(true)
	EventBus.toy_started.emit(id)
	_next_step()
	return true


## Drops the session at once: prop gone, pet free, toy_finished.
func cancel() -> void:
	if is_running():
		_end()


func _end() -> void:
	for i in _tweens.size():
		if _tweens[i]:
			_tweens[i].kill()
			_tweens[i] = null
	_prop.visible = false
	_pet.acting = false
	set_process(false)
	var id := toy_id
	toy_id = &""
	EventBus.toy_finished.emit(id)


func _process(delta: float) -> void:
	_swing = BodyBounce.step(_swing, SWING_OMEGA, SWING_DAMPING, minf(delta, MAX_STEP))
	_place()
	if _prop.visible and _hold < 0.5:
		_pet.look.glance(_prop.body.global_position, LOOK_SEC)


func _place() -> void:
	var size := maxf(_size, 0.01)
	_prop.global_transform = Transform3D(_pet.global_basis.scaled(Vector3(size, size, size)), _pet.to_global(_offset))
	var body := _prop.body
	body.rotation = Vector3(_tilt, 0.0, _swing.x)
	body.scale = Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.5)
	if _hold > 0.0:
		body.position = _prop.to_local(_pet.mouth_point() + _pet.global_basis * _hold_offset) * _hold
	else:
		body.position = Vector3.ZERO
	if _prop.spin:
		_prop.spin.rotation.z = -_offset.x / _prop.spin_radius


func _prop_for(id: StringName) -> ToyProp:
	if not _props.has(id):
		var prop := ToyProp.new(id)
		add_child(prop)
		_props[id] = prop
	return _props[id]


func _tween(slot: Slot) -> Tween:
	if _tweens[slot]:
		_tweens[slot].kill()
	_tweens[slot] = create_tween()
	return _tweens[slot]


# Steps -----------------------------------------------------------------------

func _next_step() -> void:
	_step += 1
	if _step >= _steps.size():
		_end()
		return
	var step: Dictionary = _steps[_step]
	var clip_sec := 0.0
	if step.has("clip"):
		clip_sec = _pet.play_toy_clip(step.clip, step.get("stand_in", &""))
	_replaying = ToyScript.replays(step, clip_sec)
	var span := ToyScript.span(step, clip_sec)
	if step.has("cue"):
		_cue(step.cue, span)
	var tween := _tween(Slot.STEP)
	var at := 0.0
	var beats: Array = step.get("beats", [])
	for i in beats.size():
		var t: float = beats[i] * span
		tween.tween_interval(t - at)
		tween.tween_callback(_beat.bind(step, i))
		at = t
	tween.tween_interval(ToyScript.duration(step, clip_sec) - at)
	tween.tween_callback(_next_step)


func _cue(cue: StringName, sec: float) -> void:
	match cue:
		&"pop_floor":
			_offset = Vector3(0.0, _ground(), FRONT_Z)
			_pop_in()
		&"pop_hover":
			_offset = _pet.to_local(_pet.zone_point(&"mouth")) + _hold_offset
			_tilt = _data.get("tilt", 0.0)
			_pop_in()
		&"drop":
			var ground := _ground()
			_offset = Vector3(0.0, ground + DROP_HEIGHT, FRONT_Z)
			_pop_in()
			var tween := _tween(Slot.MOVE)
			tween.tween_property(self, "_offset:y", ground, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(_land.bind(BOUNCES[0], 0.25))
			tween.tween_property(self, "_offset:y", ground + 0.07, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "_offset:y", ground, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(_land.bind(&"", 0.1))
		&"lower_in":
			var rest := Vector3(0.0, _pet.to_local(_pet.zone_point(&"paw_L")).y + BELL_HANG, BELL_Z)
			_offset = rest + Vector3.UP * BELL_DROP
			_pop_in()
			_tween(Slot.MOVE).tween_property(self, "_offset:y", rest.y, sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		&"roll_in":
			_offset = Vector3(SIDE_X, _ground(), FRONT_Z)
			_show(1.0)
			AudioDirector.play_sfx(&"roll")
			_tween(Slot.MOVE).tween_property(self, "_offset:x", 0.0, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		&"bounce_in":
			_offset = Vector3(SIDE_X, _ground() + 0.35, FRONT_Z)
			_show(1.0)
			var tween := _tween(Slot.MOVE)
			_arc(tween, Vector2(SIDE_X, 0.35), Vector2(0.5, 0.0), 0.05, 0.36)
			tween.tween_callback(_land.bind(BOUNCES[0], 0.25))
			_arc(tween, Vector2(0.5, 0.0), Vector2(0.18, 0.0), 0.16, 0.36)
			tween.tween_callback(_land.bind(BOUNCES[1], 0.18))
			_arc(tween, Vector2(0.18, 0.0), Vector2.ZERO, 0.06, 0.24)
			tween.tween_callback(_land.bind(BOUNCES[0], 0.1))
		&"lift":
			_lift(1.0, _data.get("tilt", 0.0), sec)
		&"lower":
			_lift(0.0, 0.0, sec)
		&"sniff":
			_pet.twitch_nose(3)
		&"pop_out":
			_pop_out(0.0)
		&"roll_off":
			AudioDirector.play_sfx(&"roll")
			var tween := _tween(Slot.MOVE)
			tween.tween_property(self, "_offset:x", -SIDE_X, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(_prop.hide)
		&"rise_away":
			_tween(Slot.MOVE).tween_property(self, "_offset:y", _offset.y + BELL_DROP, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_pop_out(sec - ToyScript.POP_SEC)
		&"finale":
			var reaction: Dictionary = PetReactions.TOYS[toy_id].duplicate()
			reaction.sfx = _data.end_sfx
			reaction.erase("chomp")
			_pet.twitch_nose(3)
			performed.emit(reaction)


func _beat(step: Dictionary, i: int) -> void:
	if _replaying:
		_pet.play_toy_clip(step.clip, step.get("stand_in", &""))
	var at := _prop.body.global_position
	match step.beat:
		&"gulp":
			AudioDirector.play_sfx(GULPS[i % GULPS.size()])
			_drain(ToyScript.level_after(i, (step.beats as Array).size(), _data.drain_to))
			Haptics.play(&"tap")
		&"lap":
			AudioDirector.play_sfx(LAPS[i % LAPS.size()])
			_fx.burst(&"bubble", at, DROPLETS)
			_drain(ToyScript.level_after(i, (step.beats as Array).size(), _data.drain_to))
			Haptics.play(&"tap")
		&"bite":
			_bite(MUNCHES[_hits % MUNCHES.size()], at)
		&"nibble":
			if _hits < ToyScript.LAST_STAGE:
				_bite(MUNCHES[_hits % 2], at)
		&"munch":
			AudioDirector.play_sfx(&"munch_2")
			Haptics.play(&"feed")
		&"chew":
			AudioDirector.play_sfx(MUNCHES[(MUNCHES.size() - 1 + _hits) % MUNCHES.size()])
			_hits += 1
			Haptics.play(&"feed")
		&"bat":
			AudioDirector.play_sfx(&"paw_tap")
			AudioDirector.play_sfx(&"roll")
			_fx.burst(&"bubble", at, DROPLETS)
			Haptics.play(&"tap")
			var tween := _tween(Slot.MOVE)
			tween.tween_property(self, "_offset:x", BAT_ROLL * step.side, BAT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "_offset:x", 0.0, BAT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		&"hop":
			AudioDirector.play_sfx(&"paw_tap")
			Haptics.play(&"tap")
			var tween := _tween(Slot.MOVE)
			_arc(tween, Vector2(_offset.x, 0.0), Vector2(_offset.x, 0.0), HOP_HEIGHT, HOP_SEC)
			tween.tween_callback(_land.bind(BOUNCES[1], 0.18))
		&"swing":
			_swing.y += SWING_KICK * step.side
			AudioDirector.play_sfx(JINGLES[_hits % JINGLES.size()])
			_hits += 1
			_fx.burst(&"sparkle", at, SPARKLES)
			Haptics.play(&"tap")


# Prop motion -------------------------------------------------------------------

func _ground() -> float:
	return FLOOR_Y + _prop.floor_lift


## Visible straight away, in place (a cue may fire after this frame's _process).
func _show(size: float) -> void:
	_size = size
	_prop.visible = true
	_place()


func _pop_in() -> void:
	_show(0.0)
	AudioDirector.play_sfx(&"pop_in")
	_fx.burst(&"sparkle", _pet.to_global(_offset) + Vector3.UP * 0.06, SPARKLES)
	_tween(Slot.SIZE).tween_property(self, "_size", 1.0, ToyScript.POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop_out(delay: float) -> void:
	var tween := _tween(Slot.SIZE)
	tween.tween_interval(maxf(delay, 0.0))
	tween.tween_callback(AudioDirector.play_sfx.bind(&"pop_out"))
	tween.tween_property(self, "_size", 0.0, ToyScript.POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_prop.hide)


## Toward (1) or away from (0) the held point at the mouth.
func _lift(to: float, tilt: float, sec: float) -> void:
	var tween := _tween(Slot.MOVE)
	tween.tween_property(self, "_hold", to, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "_tilt", tilt, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A hop along x; from/to are (x, height above the floor), peak is added at the middle.
func _arc(tween: Tween, from: Vector2, to: Vector2, peak: float, sec: float) -> void:
	tween.tween_method(_set_arc.bind(from, to, peak), 0.0, 1.0, sec)


func _set_arc(t: float, from: Vector2, to: Vector2, peak: float) -> void:
	_offset.x = lerpf(from.x, to.x, t)
	_offset.y = _ground() + lerpf(from.y, to.y, t) + 4.0 * peak * t * (1.0 - t)


func _land(sfx: StringName, squash: float) -> void:
	if sfx != &"":
		AudioDirector.play_sfx(sfx)
	var tween := _tween(Slot.SQUASH)
	tween.tween_property(self, "_squash", squash, 0.05)
	tween.tween_property(self, "_squash", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _bite(sfx: StringName, at: Vector3) -> void:
	_hits = ToyScript.stage_after(_hits)
	_prop.show_stage(_hits)
	AudioDirector.play_sfx(sfx)
	_fx.burst(&"star", at, CRUMBS)
	_pet.twitch_nose(2)
	Haptics.play(&"feed")


func _drain(level: float) -> void:
	if _prop.liquid:
		_tween(Slot.DRAIN).tween_property(_prop.liquid, "scale:y", level, DRAIN_SEC)
