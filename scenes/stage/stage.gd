extends Node3D
## The play stage: room, camera, the three pets, particles and talk-back.
## Turns touches, gestures and EventBus requests into pet reactions.

const CAMERA_POS := Vector3(0.0, 1.5, 4.0)
const CAMERA_TARGET := Vector3(0.0, 0.4, 0.0)
const CAMERA_FOV := 34.0
const ZOOM_FACTOR := 1.85
const ZOOM_SEC := 0.45
const WALK_SEC := 1.1
const EXIT_SEC := 0.7
const OFFSCREEN_X := 1.35
const STEP_TIMES: Array[float] = [0.0, 0.3, 0.65]
const SFX_GAP_SEC := 0.15
const CLOCK_SEC := 60.0
const PURR_DB := -2.0
const PURR_FADE_IN_SEC := 0.3
const PURR_FADE_OUT_SEC := 0.06
## A purr without a tail clip (the bunny's) fades out this slowly instead.
const PURR_UNTAILED_FADE_SEC := 0.3
## The pet's call after the child's echo sits this far under it.
const ECHO_CALL_DB := -6.0
## Smaller, more specific zones win where spheres overlap.
const ZONE_PRIORITY := {&"mouth": 0, &"paw_L": 1, &"paw_R": 1, &"cheeks": 2, &"ears": 3, &"belly": 4}
const MAX_RAY_HITS := 4
## Talk-back states in which the pet may babble on its own (mimic).
const MIMIC_STATES: Array[StringName] = [TalkBack.READY_TO_LISTEN, TalkBack.NOT_READY, TalkBack.DONT_HEAR, TalkBack.CANT_TALK]
## The pet watches a point this far in front of its face, on the finger's ray.
const LOOK_AHEAD := 0.6
const TAP_SQUASH := 0.1
## Petting: hearts, purr haptic and the pet's own response every tick.
const STROKE_TICK_SEC := 0.4
const STROKE_HEARTS := 2
const STROKE_MOOD_MS := 600
const STROKE_PURR_MS := 700
## A finger just outside the pet's screen box still counts as on the pet.
const BODY_MARGIN := 1.05

var _camera: Camera3D
var _room: Room
var _fx: ParticleFx
var _toys: ToySession
var _talkback: TalkBack
var _voice: PetVoice
var _purr: AudioStreamPlayer
var _purr_tween: Tween
## Pet id → its purr loop; the tail of the purr playing now (&"" for none).
var _purr_loops := {}
var _purr_tail: StringName = &""
var _pets: Array[Pet] = []
var _index := 0
var _switching := false

var _wide := Transform3D.IDENTITY
var _close := Transform3D.IDENTITY
var _zoomed := false
var _zoom_tween: Tween

var _talk_state: StringName = TalkBack.NOT_READY
## The first touch has started the mic and the ambience.
var _talk_started := false
## The clip TalkBack is playing is the child's echo (it came out of LISTEN).
var _echoing := false
var _purr_left := 0.0
var _clock_left := CLOCK_SEC
var _clock_phase: StringName
var _chime := 0
var _chime_names: Array[StringName] = []

var _ray := PhysicsRayQueryParameters3D.new()
var _touches := {}
var _multi_touch := false
var _pinch_base := 0.0
## The first finger: what it is turning out to be, and what its press hit.
var _stroke := StrokeTracker.new()
var _finger := -1
var _press_hit := {}
var _stroke_left := 0.0
var _body_center := Vector2.ZERO
var _body_radii := Vector2.ONE
var _tickles := TickleCounter.new()


func _ready() -> void:
	# 4x: Mali's Vulkan driver may round 2x down to off; on a tiler 4x is nearly free.
	get_viewport().msaa_3d = Viewport.MSAA_4X
	for i in 10:
		_chime_names.append(StringName("chime_%d" % i))
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = false
	_ray.collision_mask = Pet.ZONE_LAYER

	_room = Room.new()
	add_child(_room)
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	_camera.look_at_from_position(CAMERA_POS, CAMERA_TARGET)
	_wide = _camera.transform

	for id in PetReactions.PET_IDS:
		var pet := Pet.new(id)
		add_child(pet)
		pet.set_active(false)
		pet.called_to_play.connect(_on_called_to_play)
		pet.idle_break.connect(_on_idle_break)
		_pets.append(pet)
	_pets[_index].set_active(true)

	_fx = ParticleFx.new()
	add_child(_fx)
	_toys = ToySession.new(_fx)
	add_child(_toys)
	_toys.performed.connect(_on_toy_performed)
	_talkback = TalkBack.new()
	add_child(_talkback)
	_voice = PetVoice.new(_talkback, PetReactions.PET_IDS)
	add_child(_voice)
	_voice.use_pet(_current().pet_id)
	_talkback.set_pet(_current().pet_id)
	_purr = AudioStreamPlayer.new()
	_purr.bus = AudioDirector.LOOPS_BUS
	add_child(_purr)
	for pet_id: StringName in PetSounds.PURR:
		var path := AudioDirector.SFX_DIR + String(PetSounds.PURR[pet_id]) + ".ogg"
		if ResourceLoader.exists(path):
			_purr_loops[pet_id] = load(path)

	_clock_phase = TimeOfDay.current_phase()
	_room.set_phase(_clock_phase, false)

	EventBus.next_pet_requested.connect(_switch_pet.bind(1))
	EventBus.previous_pet_requested.connect(_switch_pet.bind(-1))
	EventBus.zoom_toggle_requested.connect(_on_zoom_toggle)
	EventBus.time_phase_cycle_requested.connect(_on_time_cycle)
	EventBus.toy_used.connect(_on_toy_used)
	EventBus.talkback_state_changed.connect(_on_talk_state)
	EventBus.mouth_amplitude_changed.connect(_on_mouth)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.app_paused.connect(_reset_touches)
	EventBus.app_resumed.connect(_on_app_resumed)
	_update_music()
	# Deferred so the UI layer, added after the stage, hears the starting state.
	_announce.call_deferred()


func _announce() -> void:
	EventBus.pet_changed.emit(_index, PetReactions.PET_NAMES[_index])
	EventBus.time_phase_changed.emit(_room.phase)
	EventBus.zoom_changed.emit(_zoomed)


func _process(delta: float) -> void:
	_clock_left -= delta
	if _clock_left <= 0.0:
		_check_clock()
	if _purr_left > 0.0:
		_purr_left -= delta
		if _purr_left <= 0.0:
			_stop_purr()
	match _stroke.phase:
		StrokeTracker.Phase.PENDING, StrokeTracker.Phase.DRAG:
			var before := _stroke.phase
			_on_phase(before, _stroke.update(Time.get_ticks_msec()))
		StrokeTracker.Phase.STROKE:
			_pet_stroke(delta)


func _check_clock() -> void:
	_clock_left = CLOCK_SEC
	var phase := TimeOfDay.current_phase()
	# Only follow the clock when it moves on, so a manual pick sticks until then.
	if phase != _clock_phase:
		_clock_phase = phase
		_set_phase(phase)


# Input -----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	# Any first touch (UI included) starts the mic, so the permission prompt
	# follows a deliberate tap, and fades the room's ambience in.
	if not _talk_started and touch.pressed:
		_talk_started = true
		_talkback.start()
		_update_ambience()
	# Releases are tracked here, before the UI can swallow them, so a finger
	# that started on the stage is never left stuck "down".
	if (not touch.pressed or touch.canceled) and _touches.has(touch.index):
		_on_release(touch)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_on_press(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


## A press on the pet waits (StrokeTracker) to see whether it is a tap or a
## stroke; a press on the background chimes straight away.
func _on_press(event: InputEventScreenTouch) -> void:
	_touches[event.index] = event.position
	if _touches.size() == 1:
		_multi_touch = false
		_finger = event.index
		var pet := _current()
		pet.notice_touch()
		pet.look.follow(_screen_point(event.position, LOOK_AHEAD))
		_press_hit = _pick_zone(event.position)
		_measure_body()
		var on_pet := not _press_hit.is_empty() or _over_pet(event.position)
		if _stroke.begin(event.position, Time.get_ticks_msec(), on_pet) == StrokeTracker.Phase.TAP:
			_tap(_press_hit, event.position)
	elif _touches.size() == 2:
		_multi_touch = true
		_drop_finger()
		_pinch_base = _pinch_distance()


func _on_release(event: InputEventScreenTouch) -> void:
	_touches.erase(event.index)
	if _touches.size() < 2:
		_pinch_base = 0.0
	if not _touches.is_empty():
		return
	var start := _stroke.start
	var phase := _stroke.end()
	_current().look.stroking = false
	_current().look.release()
	_current().notice_touch()
	if _multi_touch or event.canceled:
		return
	if phase == StrokeTracker.Phase.PENDING:
		_tap(_press_hit, start)
	elif _stroke.may_swipe(phase):
		var swipe := PetGestures.classify_swipe(event.position - start, Time.get_ticks_msec() - _stroke.start_msec)
		if swipe == PetGestures.Swipe.NEXT:
			_switch_pet(1)
		elif swipe == PetGestures.Swipe.PREVIOUS:
			_switch_pet(-1)
		elif phase == StrokeTracker.Phase.DRAG:
			# Moved, but neither a swipe nor a stroke: still a touch on the pet.
			_tap(_press_hit, start)


## The first finger's gesture ends without a result (a second finger, app paused).
func _drop_finger() -> void:
	_stroke.cancel()
	_current().look.stroking = false
	_current().look.release()


## Fires the press once it has settled: a held tap, or the start of petting.
func _on_phase(before: StrokeTracker.Phase, after: StrokeTracker.Phase) -> void:
	if after == before:
		return
	if after == StrokeTracker.Phase.TAP:
		_tap(_press_hit, _stroke.start)
	elif after == StrokeTracker.Phase.STROKE:
		_current().look.stroking = true
		_stroke_left = 0.0


## Fingers held while the app was backgrounded (shade, permission dialog)
## never send a release.
func _reset_touches() -> void:
	_touches.clear()
	_multi_touch = false
	_pinch_base = 0.0
	_drop_finger()


func _on_app_resumed() -> void:
	_reset_touches()
	_check_clock()


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	_touches[event.index] = event.position
	if event.index == _finger and not _multi_touch:
		var pet := _current()
		pet.notice_touch()
		pet.look.follow(_screen_point(event.position, LOOK_AHEAD))
		var before := _stroke.phase
		_on_phase(before, _stroke.move(event.position, Time.get_ticks_msec(), _over_pet(event.position)))
	if _touches.size() < 2 or _pinch_base <= 0.0:
		return
	var distance := _pinch_distance()
	var pinch := PetGestures.classify_pinch(distance / _pinch_base)
	if pinch == PetGestures.Pinch.NONE:
		return
	_pinch_base = distance
	_set_zoom(pinch == PetGestures.Pinch.ZOOM_IN, true)


func _pinch_distance() -> float:
	var points := _touches.values()
	return maxf((points[0] as Vector2).distance_to(points[1]), 1.0)


func _tap(hit: Dictionary, screen_pos: Vector2) -> void:
	if hit.is_empty():
		_background_tap(screen_pos)
	else:
		_zone_tap(hit.zone, hit.position)


## The pet's on-screen ellipse, measured at each press (zoom and walks move it).
func _measure_body() -> void:
	var box := _current().body_bounds()
	var rect := Rect2(_camera.unproject_position(box.position), Vector2.ZERO)
	for i in range(1, 8):
		rect = rect.expand(_camera.unproject_position(box.get_endpoint(i)))
	_body_center = rect.get_center()
	_body_radii = (rect.size * 0.5 * BODY_MARGIN).max(Vector2.ONE)


func _over_pet(screen_pos: Vector2) -> bool:
	return ((screen_pos - _body_center) / _body_radii).length_squared() <= 1.0


## The world point under a screen position, `ahead` metres in front of the pet's face.
func _screen_point(screen_pos: Vector2, ahead: float) -> Vector3:
	return _camera.project_position(screen_pos, _camera.global_position.distance_to(_current().face_point()) - ahead)


## Casts through every overlapping zone sphere and keeps the most specific one.
func _pick_zone(screen_pos: Vector2) -> Dictionary:
	_ray.from = _camera.project_ray_origin(screen_pos)
	_ray.to = _ray.from + _camera.project_ray_normal(screen_pos) * 20.0
	var exclude: Array[RID] = []
	_ray.exclude = exclude
	var space := get_world_3d().direct_space_state
	var best := {}
	var best_rank := 99
	for i in MAX_RAY_HITS:
		var result := space.intersect_ray(_ray)
		if result.is_empty():
			break
		var zone: StringName = (result.collider as Node).get_meta(&"zone", &"")
		var rank: int = ZONE_PRIORITY.get(zone, 99)
		if rank < best_rank:
			best_rank = rank
			best = {zone = zone, position = result.position}
		exclude.append(result.rid)
		_ray.exclude = exclude
	return best


func _background_tap(screen_pos: Vector2) -> void:
	AudioDirector.play_sfx(_chime_names[_chime])
	_chime = (_chime + 1) % _chime_names.size()
	Haptics.play(&"tap")
	var at := _screen_point(screen_pos, 0.6)
	_fx.burst(&"bubble", at, 2)
	_fx.burst(&"sparkle", at, 2)


func _zone_tap(zone: StringName, at: Vector3) -> void:
	var pet := _current()
	var reaction := PetReactions.zone_reaction(pet.pet_id, zone)
	if _toys.is_running():
		# Don't cut the drink or the meal short: just a squash and the zone's sound.
		pet.bounce.squash(TAP_SQUASH)
		var sfx: Array = reaction.get("sfx", [])
		if not sfx.is_empty():
			AudioDirector.play_sfx(sfx[0])
		return
	var level := _tickles.tap(Time.get_ticks_msec()) if zone == &"belly" else TickleCounter.Level.GIGGLE
	var squash := TAP_SQUASH
	if level == TickleCounter.Level.GIGGLE:
		pet.play_variant(zone, PetReactions.ZONE_ANIMS[zone])
	else:
		var tickle: Dictionary = PetReactions.TICKLES[level]
		pet.play_sequence(tickle.anims)
		squash = tickle.squash
		reaction = reaction.duplicate()
		reaction.ms = tickle.ms
		reaction.wobble = tickle.wobble
	if zone == &"belly":
		# Each tickle level has its own voice, building from giggles to laughs.
		reaction = reaction.duplicate()
		reaction.voice = PetReactions.TICKLES[level].voice
	pet.bounce.squash(squash)
	if zone == &"ears":
		pet.perk_ears(0.7)
	_perform(reaction, _toward_camera(at))
	EventBus.pet_reacted.emit(zone)


## Petting: hearts drip at the finger and the purr haptic pulses; the cat purrs,
## the dog wiggles, the bunny twitches its nose and tooth-purrs.
func _pet_stroke(delta: float) -> void:
	_stroke_left -= delta
	if _stroke_left > 0.0 or not _stroke.over_pet:
		return
	_stroke_left = STROKE_TICK_SEC
	var pet := _current()
	_fx.burst(&"heart", _screen_point(_stroke.position, 0.15), STROKE_HEARTS)
	# Repeats while the child pets; must not keep the mic from hearing them.
	Haptics.play(&"purr", false)
	pet.set_mood(PetReactions.PURR, STROKE_MOOD_MS)
	match pet.pet_id:
		&"cat":
			_start_purr(STROKE_PURR_MS)
		&"dog":
			if not pet.is_busy():
				pet.play_sequence([&"happy_wiggle"])
		&"bunny":
			pet.twitch_nose(3)
			_start_purr(STROKE_PURR_MS)


# Reactions -------------------------------------------------------------------

func _perform(reaction: Dictionary, at: Vector3) -> void:
	var pet := _current()
	var sfx: Array = reaction.get("sfx", [])
	# A spoken line replaces its stand-in sound when the pet has it.
	if reaction.has("voice") and not _say(reaction.voice):
		sfx = reaction.get("fallback_sfx", sfx)
	for i in sfx.size():
		if i == 0:
			AudioDirector.play_sfx(sfx[i])
		else:
			create_tween().tween_callback(AudioDirector.play_sfx.bind(sfx[i])).set_delay(SFX_GAP_SEC * i)
	if reaction.has("haptic"):
		Haptics.play(reaction.haptic)
	var ms: int = reaction.get("ms", 500)
	if reaction.has("mood"):
		pet.set_mood(reaction.mood, ms)
	else:
		pet.set_mood(PetReactions.HAPPY, 500)
	if reaction.get("purr", false):
		_start_purr(ms)
	if reaction.get("chomp", false):
		pet.chomp()
	if reaction.has("wobble"):
		pet.bounce.wobble(reaction.wobble)
	if reaction.has("twitch"):
		pet.twitch_nose(reaction.twitch)
	var mimicked := false
	if reaction.get("mimic", false) and _talk_state in MIMIC_STATES:
		EventBus.test_voice_requested.emit()
		mimicked = true
	if reaction.has("fx") and (mimicked or not reaction.get("fx_needs_mimic", false)):
		_fx.burst(reaction.fx, at, reaction.count)


## A pet walking in can't take a toy yet; the session ignores presses while one runs.
## The pet names the toy as it appears.
func _on_toy_used(toy_id: StringName) -> void:
	if not _switching and _toys.start(toy_id, _current()):
		_say(PetReactions.toy_line(toy_id))


## Says a PetVoice line if all its clips exist.
func _say(line: StringName) -> bool:
	if not _voice.has(line):
		return false
	_voice.say(line)
	return true


func _on_toy_performed(reaction: Dictionary) -> void:
	_perform(reaction, _toward_camera(_current().zone_point(&"mouth")))


## Good morning at sunrise, nighty night at night, else a hello.
func _greet() -> void:
	var pet := _current()
	var greeting: Dictionary = PetReactions.GREETINGS[pet.pet_id].duplicate()
	greeting.voice = PetReactions.greeting_line(pet.pet_id, _room.phase)
	pet.play_variant(&"greet", PetReactions.MOOD_ANIMS[greeting.mood])
	_perform(greeting, _toward_camera(pet.zone_point(&"ears")))


## The pet waved after a quiet spell and asks to play (the dog whines); silent
## during the lullaby.
func _on_called_to_play() -> void:
	if Settings.get_value(&"lullaby_on"):
		return
	var pet := _current()
	_perform(PetReactions.COME_PLAY[pet.pet_id], _toward_camera(pet.zone_point(&"ears")))


## A yawn with the yawn clip at night; now and then a hum along with the lullaby.
func _on_idle_break(clip: StringName) -> void:
	if clip == &"yawn" and _room.phase == TimeOfDay.NIGHT:
		_say(PetReactions.YAWN)
	elif Settings.get_value(&"lullaby_on") and randf() < PetReactions.HUM_CHANCE:
		_say(PetReactions.HUM)


## The current pet's purr (the dog has none) fades in, or keeps going.
func _start_purr(ms: int) -> void:
	var pet_id := _current().pet_id
	if not _purr_loops.has(pet_id):
		return
	_purr_left = maxf(_purr_left, ms / 1000.0)
	if _purr.playing and _purr_tween == null:
		return
	if _purr_tween:
		_purr_tween.kill()
		_purr_tween = null
	if not _purr.playing:
		_purr.stream = _purr_loops[pet_id]
		_purr_tail = PetSounds.PURR_TAIL.get(pet_id, &"")
		_purr.volume_db = -30.0
		_purr.play()
	var tween := create_tween()
	tween.tween_property(_purr, "volume_db", PURR_DB, PURR_FADE_IN_SEC)


func _stop_purr() -> void:
	if not _purr.playing or _purr_tween:
		return
	_purr_tween = create_tween()
	_purr_tween.tween_property(_purr, "volume_db", -40.0, PURR_FADE_OUT_SEC if _purr_tail != &"" else PURR_UNTAILED_FADE_SEC)
	_purr_tween.tween_callback(_end_purr)


## The tail starts after the faded loop has stopped, so the two never overlap.
func _end_purr() -> void:
	_purr.stop()
	_purr_tween = null
	if _purr_tail != &"":
		AudioDirector.play_sfx(_purr_tail, PURR_DB - 6.0)


# Pets, zoom, time ------------------------------------------------------------

func _switch_pet(step: int) -> void:
	if _switching or _toys.is_running():
		return
	_switching = true
	AudioDirector.play_sfx(&"ui_swipe")
	_set_zoom(false, false)
	_drop_finger()
	_tickles.reset()
	var old := _current()
	old.jaw_talk = 0.0
	_purr_left = 0.0
	_stop_purr()
	_index = wrapi(_index + step, 0, _pets.size())
	var pet := _current()
	_voice.use_pet(pet.pet_id)
	_talkback.set_pet(pet.pet_id)
	# The next pet comes in from the right, the previous one from the left.
	var side := 1.0 if step > 0 else -1.0
	old.walk(old.position.x, -side * OFFSCREEN_X, EXIT_SEC, true)
	pet.jaw_talk = 0.0
	pet.set_talk_state(_talk_state)
	pet.walk(side * OFFSCREEN_X, 0.0, WALK_SEC, false).finished.connect(_on_walk_in_done)
	var steps := create_tween()
	var last := 0.0
	for t in STEP_TIMES:
		steps.tween_interval(t - last)
		steps.tween_callback(_footstep)
		last = t
	EventBus.pet_changed.emit(_index, PetReactions.PET_NAMES[_index])


func _footstep() -> void:
	AudioDirector.play_sfx(PetSounds.STEPS[_current().pet_id])
	Haptics.play(&"step")


func _on_walk_in_done() -> void:
	_switching = false
	_greet()


func _on_zoom_toggle() -> void:
	_set_zoom(not _zoomed, true)


func _set_zoom(zoomed: bool, feedback: bool) -> void:
	if zoomed == _zoomed:
		return
	_zoomed = zoomed
	if feedback:
		if zoomed:
			Haptics.play(&"bounce")
			AudioDirector.play_sfx(&"ui_zoom_in")
		else:
			Haptics.play(&"tap")
			AudioDirector.play_sfx(&"ui_zoom_out")
	if zoomed:
		var face := _current().face_point()
		face.x = 0.0
		var distance := CAMERA_POS.distance_to(face) / ZOOM_FACTOR
		var eye := face + (CAMERA_POS - face).normalized() * distance
		# Aim a little low so the face sits in the upper middle, clear of the toy bar.
		_close = Transform3D.IDENTITY.translated(eye).looking_at(face - Vector3(0.0, 0.12, 0.0))
	if _zoom_tween:
		_zoom_tween.kill()
	var from := _camera.transform
	var to := _close if zoomed else _wide
	_zoom_tween = create_tween()
	_zoom_tween.tween_method(func(t: float) -> void: _camera.transform = from.interpolate_with(to, t),
			0.0, 1.0, ZOOM_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	EventBus.zoom_changed.emit(zoomed)


## The sun button: its twinkle, unless the new phase has its own chime.
func _on_time_cycle() -> void:
	var phase := TimeOfDay.next_phase(_room.phase)
	if not TimeOfDay.CHIMES.has(phase):
		AudioDirector.play_sfx(&"twinkle")
	Haptics.play(&"twinkle")
	_set_phase(phase)


func _set_phase(phase: StringName) -> void:
	if phase != _room.phase and TimeOfDay.CHIMES.has(phase):
		AudioDirector.play_sfx(TimeOfDay.CHIMES[phase])
	_room.set_phase(phase, true)
	_update_ambience()
	EventBus.time_phase_changed.emit(phase)


## The phase's ambience once the room has woken up (first touch), if room sounds are on.
func _update_ambience() -> void:
	if _talk_started and Settings.get_value(&"ambience_on"):
		AudioDirector.play_ambience(TimeOfDay.ambience_for(_room.phase))
	else:
		AudioDirector.stop_ambience()


## The lullaby wins over the day music.
func _update_music() -> void:
	if Settings.get_value(&"lullaby_on"):
		AudioDirector.play_music(&"lullaby")
	elif Settings.get_value(&"music_on"):
		AudioDirector.play_music(&"day_music")
	else:
		AudioDirector.stop_music()


# Talk-back and settings --------------------------------------------------------

## After the child's echo (TALK that came out of LISTEN), a short call of the
## pet's own, under the echo.
func _on_talk_state(state: StringName) -> void:
	if state == TalkBack.TALK:
		_echoing = _talk_state == TalkBack.LISTEN
	elif state == TalkBack.CELEBRATE and _echoing:
		AudioDirector.play_sfx(PetSounds.ECHO_CALL[_current().pet_id], ECHO_CALL_DB)
	if state != TalkBack.TALK:
		_echoing = false
	_talk_state = state
	_current().set_talk_state(state)


func _on_mouth(value: float) -> void:
	_current().jaw_talk = value


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	match key:
		&"lullaby_on", &"music_on":
			_update_music()
		&"ambience_on":
			_update_ambience()


func _current() -> Pet:
	return _pets[_index]


func _toward_camera(point: Vector3) -> Vector3:
	return point + (_camera.global_position - point).normalized() * 0.15
