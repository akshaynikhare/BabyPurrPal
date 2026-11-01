extends TestCase
## TalkBack state machine with the device, input, clock and permission faked.
## Settings are changed in memory only (never saved) and restored after each test.

const RECORD_AUDIO := "android.permission.RECORD_AUDIO"
const FRAME := 1.0 / 60.0
## The lullaby heard through the phone speaker (about -30 dBFS), and a child
## talking over it (a 300 Hz tone at about -15 dBFS).
const MUSIC_RMS := 0.0316
const SPEECH_AMP := 0.25


class FakeTalkBack extends TalkBack:
	var clock := 1000000
	var pending := PackedVector2Array()
	var device_is_open := false
	var opens := 0
	var android := false
	var granted := false
	var requests := 0
	var jobs: Array = []
	var voice: AudioStream

	func _play_voice(stream: AudioStream) -> void:
		voice = stream

	func _stop_voice() -> void:
		voice = null

	func _now() -> int:
		return clock

	func _read_input() -> PackedVector2Array:
		var out := pending
		pending = PackedVector2Array()
		return out

	func _open_device() -> Error:
		opens += 1
		device_is_open = true
		return OK

	func _close_device() -> void:
		device_is_open = false

	func _needs_runtime_permission() -> bool:
		return android

	func _has_permission() -> bool:
		return granted

	func _request_permission() -> bool:
		requests += 1
		return granted

	func _start_clip_job(token: int, clip: PackedFloat32Array, rate: int) -> void:
		jobs.append([token, clip, rate])

	## Delivers held clip jobs as if the worker had finished.
	func deliver() -> void:
		for job in jobs:
			_on_clip_ready(job[0], TalkBack.build_clip(job[1], job[2]))
		jobs.clear()


var _rng := RandomNumberGenerator.new()
var _states: Array[StringName] = []
var _saved := {}


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make(android := false, granted := true) -> FakeTalkBack:
	_rng.seed = 11
	_states.clear()
	for key in [&"talkback_on", &"lullaby_on"]:
		_saved[key] = Settings.get_value(key)
	_set_setting(&"talkback_on", true)
	_set_setting(&"lullaby_on", false)
	AudioDirector.busy_until_msec = 0
	AudioDirector.set_ducked(false)
	var tb := FakeTalkBack.new()
	tb.android = android
	tb.granted = granted
	_tree().root.add_child(tb)
	# The runner works inside SceneTree._initialize, before root enters the tree.
	if not tb.is_node_ready():
		tb._ready()
	EventBus.talkback_state_changed.connect(_on_state)
	return tb


func _done(tb: FakeTalkBack) -> void:
	EventBus.talkback_state_changed.disconnect(_on_state)
	EventBus.settings_closed.emit()
	AudioDirector.busy_until_msec = 0
	AudioDirector.set_ducked(false)
	tb.free()
	for key in _saved:
		_set_setting(key, _saved[key])


func _on_state(s: StringName) -> void:
	_states.append(s)


func _set_setting(key: StringName, value: Variant) -> void:
	Settings._config.set_value(Settings.SECTION, key, value)
	EventBus.settings_changed.emit(key, value)


## Advances sec of game time, feeding noise (rms), a 300 Hz tone (amp) or both each frame.
func _run(tb: FakeTalkBack, sec: float, rms := 0.003, tone_amp := 0.0) -> void:
	var rate := tb.detector.sample_rate()
	var per_frame := roundi(rate * FRAME)
	for f in roundi(sec / FRAME):
		var chunk := PackedVector2Array()
		chunk.resize(per_frame)
		for i in per_frame:
			var v := 0.0
			if tone_amp > 0.0:
				v = tone_amp * sin(TAU * 300.0 * float(f * per_frame + i) / rate)
			if rms > 0.0:
				v += _rng.randf_range(-rms, rms) * sqrt(3.0)
			chunk[i] = Vector2(v, v)
		tb.clock += roundi(FRAME * 1000.0)
		tb.pending = chunk
		tb._process(FRAME)


func _ready_to_listen(tb: FakeTalkBack) -> void:
	tb.start()
	_run(tb, 0.8)


func _speak(tb: FakeTalkBack, sec := 1.0) -> void:
	_run(tb, sec, 0.0, 0.3)


## An SFX or haptic buzz is (or isn't) playing.
func _busy(on: bool) -> void:
	AudioDirector.busy_until_msec = Time.get_ticks_msec() + 60000 if on else 0


func test_start_always_emits() -> void:
	var tb := _make()
	tb.start()
	tb.start()
	check_eq(_states.size(), 2, "one emit per start()")
	check_eq(_states[-1], TalkBack.NOT_READY, "state")
	_done(tb)


func test_speech_to_talk_and_back() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "calibrated")
	check(tb.device_is_open, "device open")
	check(not AudioDirector.ducked, "music up while resting")
	_speak(tb)
	check_eq(tb.state, TalkBack.LISTEN, "listening")
	check(AudioDirector.ducked, "ducked from the first syllable")
	_run(tb, 1.0)
	check_eq(tb.jobs.size(), 1, "clip handed to worker")
	check_eq(tb.state, TalkBack.LISTEN, "stays LISTEN while processing")
	check(tb.is_input_gated(), "gated while processing")
	tb.deliver()
	check_eq(tb.state, TalkBack.TALK, "talking")
	check(tb.is_input_gated(), "gated while talking")
	check(AudioDirector.ducked, "ducked while talking")
	_busy(true)
	check(tb.is_input_gated(), "an SFX doesn't lift the TALK gate")
	_busy(false)
	tb._on_playback_finished()
	check_eq(tb.state, TalkBack.CELEBRATE, "celebrate")
	check(AudioDirector.ducked, "ducked while celebrating")
	_speak(tb, 0.3)
	check_eq(tb.state, TalkBack.CELEBRATE, "cooldown ignores sound")
	_run(tb, 0.6)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "back to ready")
	check(not AudioDirector.ducked, "music back up")
	_done(tb)


func test_too_short_and_stop_unduck() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	_speak(tb, 0.2)
	check_eq(tb.state, TalkBack.LISTEN, "started")
	check(AudioDirector.ducked, "ducked")
	_run(tb, 1.0)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "too short: back to rest")
	check_eq(tb.jobs.size(), 0, "no clip")
	check(not AudioDirector.ducked, "unducked after too_short")
	_speak(tb, 0.5)
	check(AudioDirector.ducked, "ducked again")
	tb.stop()
	check(not AudioDirector.ducked, "unducked on stop")
	_done(tb)


func test_pause_during_listen() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	_speak(tb, 0.5)
	check_eq(tb.state, TalkBack.LISTEN, "listening")
	EventBus.app_paused.emit()
	check_eq(tb.state, TalkBack.NOT_READY, "paused")
	check(not tb.device_is_open, "recorder closed in background")
	check(not tb.detector.is_recording(), "partial clip dropped")
	check(not AudioDirector.ducked, "unducked on pause")
	EventBus.app_resumed.emit()
	check(not tb.device_is_open, "reopen waits for the driver")
	_run(tb, 0.3)
	check(tb.device_is_open, "reopened after the resume delay")
	_run(tb, 0.8)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "recalibrated")
	_done(tb)


func test_pause_during_talk() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	var mouth := [-1.0]
	var on_mouth := func(v: float) -> void: mouth[0] = v
	EventBus.mouth_amplitude_changed.connect(on_mouth)
	tb.play_babble()
	check_eq(tb.state, TalkBack.TALK, "talking")
	_run(tb, 0.3)
	EventBus.app_paused.emit()
	EventBus.mouth_amplitude_changed.disconnect(on_mouth)
	check_eq(tb.state, TalkBack.NOT_READY, "paused, not CELEBRATE")
	check_near(mouth[0], 0.0, 0.0001, "mouth closed")
	_done(tb)


func test_pause_drops_processing_clip() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	_speak(tb)
	_run(tb, 1.0)
	check_eq(tb.jobs.size(), 1, "processing")
	EventBus.app_paused.emit()
	tb.deliver()
	check_eq(tb.state, TalkBack.NOT_READY, "stale clip not played after pause")
	check(not AudioDirector.ducked, "unducked when the clip is dropped")
	_done(tb)


func test_permission_dialog_resume_before_result() -> void:
	var tb := _make(true, false)
	tb.start()
	check_eq(tb.requests, 1, "asked once")
	check(not tb.device_is_open, "no mic before permission")
	# The dialog itself backgrounds the app.
	EventBus.app_paused.emit()
	EventBus.app_resumed.emit()
	_run(tb, 0.3)
	check_eq(tb.requests, 1, "resume doesn't ask again")
	tb.granted = true
	_tree().on_request_permissions_result.emit(RECORD_AUDIO, true)
	check_eq(tb.permission, TalkBack.Permission.GRANTED, "granted")
	_run(tb, 1.0)
	check(tb.device_is_open, "mic opened")
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "ready")
	_done(tb)


func test_permission_result_while_paused() -> void:
	var tb := _make(true, false)
	tb.start()
	EventBus.app_paused.emit()
	tb.granted = true
	_tree().on_request_permissions_result.emit(RECORD_AUDIO, true)
	check(not tb.device_is_open, "no mic while backgrounded")
	EventBus.app_resumed.emit()
	_run(tb, 1.0)
	check(tb.device_is_open, "opened on resume")
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "ready")
	_done(tb)


func test_denied_then_granted_in_system_settings() -> void:
	var tb := _make(true, false)
	tb.start()
	_tree().on_request_permissions_result.emit(RECORD_AUDIO, false)
	check_eq(tb.state, TalkBack.DONT_HEAR, "can't hear")
	EventBus.app_paused.emit()
	tb.granted = true
	EventBus.app_resumed.emit()
	check_eq(tb.permission, TalkBack.Permission.GRANTED, "noticed on resume")
	_run(tb, 1.0)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "recovered")
	_done(tb)


func test_babble_plays_in_dont_hear() -> void:
	var tb := _make(true, false)
	tb.start()
	_tree().on_request_permissions_result.emit(RECORD_AUDIO, false)
	EventBus.test_voice_requested.emit()
	check_eq(tb.state, TalkBack.TALK, "babble talks")
	tb._on_playback_finished()
	_run(tb, 0.7)
	check_eq(tb.state, TalkBack.DONT_HEAR, "back to can't hear")
	_done(tb)


func test_talkback_toggle() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	_speak(tb, 0.5)
	check_eq(tb.state, TalkBack.LISTEN, "listening")
	_set_setting(&"talkback_on", false)
	check_eq(tb.state, TalkBack.CANT_TALK, "off")
	check(not tb.device_is_open, "recorder closed")
	check(not AudioDirector.ducked, "unducked when off")
	_speak(tb, 1.0)
	_run(tb, 1.0)
	check_eq(tb.state, TalkBack.CANT_TALK, "ignores speech while off")
	check_eq(tb.jobs.size(), 0, "no clip")
	_set_setting(&"talkback_on", true)
	check(not tb.device_is_open, "reopen waits for the delay")
	_run(tb, 1.0)
	check(tb.device_is_open, "reopened")
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "ready again")
	_done(tb)


func test_busy_mutes_without_dropping_the_clip() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	var floor_before := tb.detector.noise_floor
	_busy(true)
	_speak(tb, 1.5)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "pet SFX not heard")
	check_eq(tb.detector.noise_floor, floor_before, "floor untouched")
	check(tb.device_is_open, "recorder stays open")
	check(not tb.is_input_gated(), "busy mutes the detector, it doesn't gate")
	_busy(false)
	_speak(tb, 0.5)
	check_eq(tb.state, TalkBack.LISTEN, "listens once quiet")
	# A tap mid-sentence: its SFX plays while the child keeps talking.
	_busy(true)
	_speak(tb, 0.4)
	_run(tb, 1.0)
	check_eq(tb.state, TalkBack.LISTEN, "SFX mid-utterance keeps the clip")
	check(tb.detector.is_recording(), "muted time isn't silence")
	check(AudioDirector.ducked, "still ducked")
	_busy(false)
	_speak(tb, 0.5)
	_run(tb, 1.0)
	check_eq(tb.jobs.size(), 1, "one clip")
	if tb.jobs.size() == 1:
		var sec := float(tb.jobs[0][1].size()) / tb.detector.sample_rate()
		check_near(sec, 1.0 + tb.detector.pre_roll_sec + tb.detector.tail_keep_sec, 0.05, "muted part left out")
	tb.deliver()
	check_eq(tb.state, TalkBack.TALK, "replies")
	_done(tb)


func test_lullaby_keeps_mic_open() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	_speak(tb, 0.5)
	check_eq(tb.state, TalkBack.LISTEN, "listening")
	_set_setting(&"lullaby_on", true)
	check(tb.device_is_open, "recorder stays open for the lullaby")
	check(tb.detector.music, "detector in music mode")
	check(not tb.detector.is_recording(), "partial clip dropped")
	check(not AudioDirector.ducked, "unducked at rest")
	_run(tb, 0.25, MUSIC_RMS, SPEECH_AMP)
	check(tb.is_input_gated(), "input skipped while the music starts")
	check_eq(tb.state, TalkBack.NOT_READY, "measuring the room again")
	_run(tb, 4.0, MUSIC_RMS)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "ready with the music on")
	_run(tb, 10.0, MUSIC_RMS)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "the music alone isn't speech")
	_run(tb, 1.0, MUSIC_RMS, SPEECH_AMP)
	check_eq(tb.state, TalkBack.LISTEN, "hears the child over the music")
	check(AudioDirector.ducked, "music ducked while recording")
	_run(tb, 1.0, MUSIC_RMS)
	check_eq(tb.jobs.size(), 1, "clip ends over the music")
	tb.deliver()
	check_eq(tb.state, TalkBack.TALK, "replies over the music")
	check(AudioDirector.ducked, "still ducked")
	tb._on_playback_finished()
	_run(tb, 0.7, MUSIC_RMS)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "back to rest")
	check(not AudioDirector.ducked, "music back up")
	EventBus.app_paused.emit()
	EventBus.app_resumed.emit()
	_run(tb, 0.3, MUSIC_RMS)
	check(tb.device_is_open, "resume reopens it during the lullaby")
	_set_setting(&"lullaby_on", false)
	check(tb.device_is_open, "stays open when the lullaby stops")
	check(not tb.detector.music, "music mode off")
	_run(tb, 0.3)
	_run(tb, 0.6)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "measured the quiet room")
	_speak(tb, 0.5)
	check_eq(tb.state, TalkBack.LISTEN, "listens again")
	_done(tb)


func test_lullaby_at_start_still_asks_permission() -> void:
	var tb := _make(true, false)
	_set_setting(&"lullaby_on", true)
	tb.start()
	check_eq(tb.requests, 1, "permission asked on first interaction")
	tb.granted = true
	_tree().on_request_permissions_result.emit(RECORD_AUDIO, true)
	_run(tb, 0.5, MUSIC_RMS)
	check(tb.device_is_open, "the mic opens during the lullaby")
	_run(tb, 3.5, MUSIC_RMS)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "ready")
	_done(tb)


func test_settings_sheet_gate_is_drain_only() -> void:
	var tb := _make()
	_ready_to_listen(tb)
	EventBus.settings_opened.emit()
	_speak(tb, 1.0)
	check(tb.device_is_open, "recorder stays open")
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "doesn't repeat the parent")
	EventBus.settings_closed.emit()
	_speak(tb, 0.5)
	check_eq(tb.state, TalkBack.LISTEN, "listens again")
	EventBus.settings_opened.emit()
	_run(tb, FRAME)
	check_eq(tb.state, TalkBack.READY_TO_LISTEN, "opening the sheet drops the clip")
	check(not tb.detector.is_recording(), "recording dropped")
	check(not AudioDirector.ducked, "unducked")
	_done(tb)
