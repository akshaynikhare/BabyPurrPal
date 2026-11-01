class_name ToySession
extends Node3D
## Runs one toy at a time (ToyScript): the prop pops in, the pet gets excited,
## sits or lies down (or chases the toy) and drinks, eats or plays with it in its
## paws, gets up, shows its mood and the prop leaves. Emits toy_started and
## toy_finished; app pause or a pet change cancels and puts the pet back home.
## The prop is placed in world space; the pet's home faces +Z.

## The mood finale; the stage plays it like any reaction (sound, voice, mood, purr, particles).
signal performed(reaction: Dictionary)

enum Slot { STEP, MOVE, SIZE, SQUASH, DRAIN, PET, SOUND }

const FLOOR_Y := 0.01
## Floor props sit where the seated and standing lap reach (0.34–0.41 forward).
const FRONT_Z := 0.37
## Toys roll and bounce in from off screen on the pet's left.
const SIDE_X := 0.9
const DROP_HEIGHT := 0.6
const BELL_Z := 0.3
const BELL_DROP := 0.9
## Ribbon top above the standing paws; seated paws are about BELL_SIT lower.
const BELL_HANG := 0.12
const BELL_SIT := 0.1
## The chase stays inside what the camera shows at the pet (about ±0.5 m,
## minus half the pet).
const CHASE_X := 0.34
const BALL_Z := 0.15
const RUN_SPEED := 0.9
const TURN_SEC := 0.15
## The pet stops this short of the toy; the pounce clip only arcs up, so the
## leap forward is ours, from 0.25 to 0.6 s into it.
const POUNCE_GAP := 0.4
const POUNCE_REACH := 0.28
const LEAP_START := 0.25
const LEAP_SEC := 0.35
const KICK_SEC := 1.0
## Lying on its back, the paws juggle the ball this high (without a hold bone).
const PAWS_Y := 0.4
const JUGGLE_PEAK := 0.12
const JUGGLE_SEC := 0.35
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
## Swallows before the cup is empty; the last one is a slurp, the next beat pops the cup.
const GULP_BEATS := 3
## AudioDirector sounds with several takes (one plays, never twice in a row).
const GULP := &"gulp"
const SLURP := &"slurp"
const BOUNCE := &"bounce"
const JINGLE := &"jingle"
const SFX_GAP_SEC := 0.15

var toy_id: StringName = &""
var _fx: ParticleFx
var _pet: Pet
var _prop: ToyProp
var _props := {}
var _data: Dictionary
var _steps: Array
var _step := -1
var _rest: StringName = &""
var _replaying := false
var _hits := 0
var _home := Transform3D.IDENTITY
var _tweens: Array[Tween] = [null, null, null, null, null, null, null]
## Tweened, then applied every frame: the prop's world position and axes, its
## blend to the paws (or mouth), tilt, pop size, landing squash.
var _pos := Vector3.ZERO
## Where a rolling toy will stop; the pet runs there.
var _target := Vector3.ZERO
var _basis := Basis.IDENTITY
var _hold := 0.0
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
	_home = pet.global_transform
	_data = ToyScript.TOYS[id]
	_steps = _data.steps
	_step = -1
	_rest = &""
	_hits = 0
	_basis = Basis.IDENTITY if _data.get("chase", false) else _home.basis
	_hold = 0.0
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


## Drops the session at once: prop gone, pet home and free, toy_finished.
func cancel() -> void:
	if not is_running():
		return
	_pet.global_transform = _home
	_pet.play_toy_clip(PetClips.IDLE, &"")
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
	_prop.global_transform = Transform3D(_basis.scaled(Vector3(size, size, size)), _pos)
	var body := _prop.body
	body.rotation = Vector3(_tilt, 0.0, _swing.x)
	body.scale = Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.5)
	if _hold > 0.0:
		body.position = _prop.to_local(_held_point()) * _hold
	else:
		body.position = Vector3.ZERO
	if _prop.spin:
		_prop.spin.rotation.z = -_pos.x / _prop.spin_radius


## Between the paws on the hold bone, or at the mouth while the GLB has none.
func _held_point() -> Vector3:
	if _pet.has_hold():
		return _pet.hold_point() + _pet.global_basis * (_data.get("grip", Vector3.ZERO) as Vector3)
	return _pet.mouth_point() + _pet.global_basis * (_data.get("hold", Vector3.ZERO) as Vector3)


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
	_rest = step.get("rest", _rest)
	var clip_sec := 0.0
	if step.has("clip"):
		clip_sec = _pet.play_toy_clip(step.clip, step.get("stand_in", &""), _rest)
	_replaying = ToyScript.replays(step, clip_sec)
	var cue_sec := 0.0
	if step.has("cue"):
		cue_sec = _cue(step.cue, ToyScript.span(step, clip_sec))
	var span := ToyScript.span(step, clip_sec, cue_sec)
	var tween := _tween(Slot.STEP)
	var at := 0.0
	var beats: Array = step.get("beats", [])
	for i in beats.size():
		var t: float = beats[i] * span
		tween.tween_interval(t - at)
		tween.tween_callback(_beat.bind(step, i))
		at = t
	tween.tween_interval(ToyScript.duration(step, clip_sec, cue_sec) - at)
	tween.tween_callback(_next_step)


## Starts the step's prop or pet move; returns how long it needs (0: the step's own span).
func _cue(cue: StringName, sec: float) -> float:
	match cue:
		&"pop_floor":
			_pos = _floor_point(_home * Vector3(0.0, 0.0, FRONT_Z))
			_pop_in()
		&"pop_hover":
			_pos = _pet.zone_point(&"mouth") + _home.basis * (_data.hold as Vector3)
			_tilt = _data.get("tilt", 0.0)
			_pop_in()
		&"drop":
			var ground := _floor_point(_home * Vector3(0.0, 0.0, FRONT_Z))
			_pos = ground + Vector3.UP * DROP_HEIGHT
			_pop_in()
			var tween := _tween(Slot.MOVE)
			tween.tween_property(self, "_pos:y", ground.y, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(_land.bind(BOUNCE, 0.25))
			tween.tween_property(self, "_pos:y", ground.y + 0.07, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "_pos:y", ground.y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(_land.bind(&"", 0.1))
		&"lower_in":
			var paw := _pet.zone_point(&"paw_L")
			_pos = _home * Vector3(0.0, 0.0, BELL_Z)
			_pos.y = paw.y + BELL_HANG + BELL_DROP
			_pop_in()
			_tween(Slot.MOVE).tween_property(self, "_pos:y", paw.y + BELL_HANG, sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		&"sit_bell":
			_tween(Slot.MOVE).tween_property(self, "_pos:y", _pos.y - BELL_SIT, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		&"roll_in":
			_pos = _floor_point(Vector3(SIDE_X, 0.0, BALL_Z))
			_show(1.0)
			_target = Vector3(-CHASE_X, _pos.y, _pos.z)
			AudioDirector.play_sfx(_roll_sfx())
			_tween(Slot.MOVE).tween_property(self, "_pos:x", _target.x, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		&"bounce_in":
			var ground := _floor_point(Vector3(SIDE_X, 0.0, BALL_Z))
			_pos = ground + Vector3.UP * 0.35
			_show(1.0)
			_target = Vector3(-CHASE_X, ground.y, ground.z)
			var tween := _tween(Slot.MOVE)
			var a := ground + Vector3(-0.45, 0.0, 0.0)
			var b := ground + Vector3(-0.85, 0.0, 0.0)
			var c := ground + Vector3(-1.1, 0.0, 0.0)
			_arc(tween, _pos, a, 0.05, 0.36)
			tween.tween_callback(_land.bind(BOUNCE, 0.25))
			_arc(tween, a, b, 0.16, 0.36)
			tween.tween_callback(_land.bind(BOUNCE, 0.18))
			_arc(tween, b, c, 0.06, 0.24)
			tween.tween_callback(_land.bind(BOUNCE, 0.1))
			tween.tween_property(self, "_pos:x", _target.x, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		&"lift":
			if _data.has("lift_sfx"):
				AudioDirector.play_sfx(_data.lift_sfx)
			_lift(1.0, sec)
		&"drink":
			var tween := _tween(Slot.MOVE)
			tween.tween_interval(sec * 0.15)
			tween.tween_property(self, "_tilt", _data.get("tilt", 0.0), sec * 0.1).set_trans(Tween.TRANS_SINE)
			tween.tween_interval(sec * 0.5)
			tween.tween_property(self, "_tilt", 0.0, sec * 0.1).set_trans(Tween.TRANS_SINE)
		&"sniff":
			_pet.twitch_nose(3)
		&"pop_out":
			_pop_out(0.0)
		&"chase":
			return _run_to(_target, POUNCE_GAP)
		&"leap":
			var tween := _tween(Slot.PET)
			tween.tween_interval(LEAP_START)
			tween.tween_property(_pet, "position", _pet.position + _pet.global_basis.z * POUNCE_REACH, LEAP_SEC).set_trans(Tween.TRANS_SINE)
		&"to_paws":
			_hop_to(_paws_point(), sec)
		&"drop_ball":
			_hop_to(_floor_point(_pet.global_position + _pet.global_basis.z * FRONT_Z), sec).tween_callback(_land.bind(BOUNCE, 0.18))
		&"roll_off":
			AudioDirector.play_sfx(_roll_sfx())
			var tween := _tween(Slot.MOVE)
			tween.tween_property(self, "_pos:x", SIDE_X if _pos.x < 0.0 else -SIDE_X, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(_prop.hide)
		&"home":
			var sec_run := _run_to(_home.origin, 0.0)
			var tween := _tweens[Slot.PET] if sec_run > 0.0 else _tween(Slot.PET)
			tween.tween_property(_pet, "rotation:y", _yaw_toward(_home.basis.get_euler().y), TURN_SEC * 2.0)
			tween.tween_callback(_pet.play_toy_clip.bind(PetClips.IDLE, &""))
			return sec_run + TURN_SEC * 2.0
		&"rise_away":
			_tween(Slot.MOVE).tween_property(self, "_pos:y", _pos.y + BELL_DROP, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_pop_out(sec - ToyScript.POP_SEC)
		&"finale":
			var reaction: Dictionary = PetReactions.TOYS[toy_id].duplicate()
			reaction.erase("chomp")
			reaction.sfx = _data.end_sfx
			if _data.has("end_voice"):
				reaction.voice = _data.end_voice
				reaction.fallback_sfx = _data.end_sfx
				reaction.sfx = []
			_pet.twitch_nose(3)
			performed.emit(reaction)
	return 0.0


func _beat(step: Dictionary, i: int) -> void:
	if _replaying:
		_pet.play_toy_clip(step.clip, step.get("stand_in", &""), _rest)
	var at := _prop.body.global_position
	match step.beat:
		&"gulp":
			if i >= GULP_BEATS:
				_pop_out(0.0)
				return
			AudioDirector.play_sfx(SLURP if i == GULP_BEATS - 1 else GULP)
			_drain(ToyScript.level_after(i, GULP_BEATS, _data.drain_to))
			Haptics.play(&"tap")
		&"lap":
			var last := i == (step.beats as Array).size() - 1
			AudioDirector.play_sfx(SLURP if last else PetSounds.DRINK[_pet.pet_id])
			_fx.burst(&"bubble", at, DROPLETS)
			_drain(ToyScript.level_after(i, (step.beats as Array).size(), _data.drain_to))
			Haptics.play(&"tap")
		&"bite":
			_bite(at)
		&"bite_out":
			if i == 0:
				_bite(at)
			else:
				_pop_out(0.0)
		&"nibble":
			if _hits < ToyScript.LAST_STAGE:
				_bite(at)
		&"gnaw", &"gnaw_out":
			if i > 0:
				_pop_out(0.0)
				return
			AudioDirector.play_sfx(_eat_sfx())
			_hits += 1
			_fx.burst(&"star", at, CRUMBS)
			Haptics.play(&"feed")
		&"pounce":
			_land(BOUNCE, 0.25)
			AudioDirector.play_sfx(&"paw_tap")
			Haptics.play(&"tap")
		&"kick":
			AudioDirector.play_sfx(&"paw_tap")
			AudioDirector.play_sfx(_roll_sfx())
			_fx.burst(&"bubble", at, DROPLETS)
			Haptics.play(&"tap")
			_target = Vector3(CHASE_X if _pos.x < 0.0 else -CHASE_X, _pos.y, _pos.z)
			_tween(Slot.MOVE).tween_property(self, "_pos:x", _target.x, KICK_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		&"juggle":
			AudioDirector.play_sfx(&"paw_tap")
			AudioDirector.play_sfx(_roll_sfx())
			Haptics.play(&"tap")
			_arc(_tween(Slot.MOVE), _pos, _paws_point(), JUGGLE_PEAK, JUGGLE_SEC)
		&"swing":
			_swing.y += SWING_KICK * step.side
			AudioDirector.play_sfx(JINGLE)
			_hits += 1
			_fx.burst(&"sparkle", at, SPARKLES)
			Haptics.play(&"tap")


# Pet motion --------------------------------------------------------------------

## Runs (and turns) toward a floor point, stopping `gap` short; returns how long it takes.
func _run_to(target: Vector3, gap: float) -> float:
	var from := _pet.global_position
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var distance := flat.length() - gap
	if distance < 0.05:
		return 0.0
	var direction := flat.normalized()
	var sec := distance / RUN_SPEED
	_pet.play_run()
	var tween := _tween(Slot.PET)
	tween.tween_property(_pet, "rotation:y", _yaw_toward(atan2(direction.x, direction.z)), TURN_SEC)
	tween.parallel().tween_property(_pet, "position", _pet.position + direction * distance, sec)
	return sec


## The nearest equivalent of `yaw` to the pet's current yaw, so it turns the short way.
func _yaw_toward(yaw: float) -> float:
	return _pet.rotation.y + wrapf(yaw - _pet.rotation.y, -PI, PI)


## Above the paws of a pet lying on its back.
func _paws_point() -> Vector3:
	if _pet.has_hold():
		return _pet.hold_point() + Vector3.UP * 0.15
	return _pet.global_position + Vector3.UP * PAWS_Y


# Prop motion -------------------------------------------------------------------

func _floor_point(point: Vector3) -> Vector3:
	return Vector3(point.x, FLOOR_Y + _prop.floor_lift, point.z)


## Visible straight away, in place (a cue may fire after this frame's _process).
func _show(size: float) -> void:
	_size = size
	_prop.visible = true
	_place()


func _pop_in() -> void:
	_show(0.0)
	var sounds: Array = _data.get("appear_sfx", [&"pop_in"])
	AudioDirector.play_sfx(sounds[0])
	if sounds.size() > 1:
		var tween := _tween(Slot.SOUND)
		for i in range(1, sounds.size()):
			tween.tween_interval(SFX_GAP_SEC)
			tween.tween_callback(AudioDirector.play_sfx.bind(sounds[i]))
	_fx.burst(&"sparkle", _pos + Vector3.UP * 0.06, SPARKLES)
	_tween(Slot.SIZE).tween_property(self, "_size", 1.0, ToyScript.POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop_out(delay: float) -> void:
	var tween := _tween(Slot.SIZE)
	tween.tween_interval(maxf(delay, 0.0))
	tween.tween_callback(AudioDirector.play_sfx.bind(&"pop_out"))
	tween.tween_property(self, "_size", 0.0, ToyScript.POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_prop.hide)


## Into (1) or out of (0) the paws; held upright there (the mouth fallback keeps its tilt).
func _lift(to: float, sec: float) -> void:
	var tween := _tween(Slot.MOVE)
	tween.tween_property(self, "_hold", to, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _pet.has_hold():
		tween.parallel().tween_property(self, "_tilt", 0.0, sec).set_trans(Tween.TRANS_SINE)


func _hop_to(to: Vector3, sec: float) -> Tween:
	var tween := _tween(Slot.MOVE)
	_arc(tween, _pos, to, JUGGLE_PEAK, sec)
	return tween


## A hop in world space with `peak` added at the middle.
func _arc(tween: Tween, from: Vector3, to: Vector3, peak: float, sec: float) -> void:
	tween.tween_method(_set_arc.bind(from, to, peak), 0.0, 1.0, sec)


func _set_arc(t: float, from: Vector3, to: Vector3, peak: float) -> void:
	_pos = from.lerp(to, t) + Vector3.UP * (4.0 * peak * t * (1.0 - t))


func _land(sfx: StringName, squash: float) -> void:
	if sfx != &"":
		AudioDirector.play_sfx(sfx)
	var tween := _tween(Slot.SQUASH)
	tween.tween_property(self, "_squash", squash, 0.05)
	tween.tween_property(self, "_squash", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _bite(at: Vector3) -> void:
	_hits = ToyScript.stage_after(_hits)
	_prop.show_stage(_hits)
	AudioDirector.play_sfx(_eat_sfx())
	_fx.burst(&"star", at, CRUMBS)
	_pet.twitch_nose(2)
	Haptics.play(&"feed")


## The pet's bite (nibble, gnaw, crunch), or the toy's own.
func _eat_sfx() -> StringName:
	return _data.get("eat_sfx", PetSounds.EAT[_pet.pet_id])


## Yarn rolls, the ball bounces.
func _roll_sfx() -> StringName:
	return _data.get("roll_sfx", &"roll")


func _drain(level: float) -> void:
	if _prop.liquid:
		_tween(Slot.DRAIN).tween_property(_prop.liquid, "scale:y", level, DRAIN_SEC)
