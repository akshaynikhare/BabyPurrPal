class_name TalkBack
extends Node
## Listens for the child's voice, then repeats it pitched up with the pet's mouth
## following along. Owns two runtime buses:
##   Mic        muted; AudioStreamMicrophone → AudioEffectCapture (read in _process)
##   TalkBackFX AudioEffectPitchShift, sends to Voice
## Emits EventBus.talkback_state_changed / mouth_amplitude_changed / mic_permission_changed.

const NOT_READY := &"NOT_READY"
const READY_TO_LISTEN := &"READY_TO_LISTEN"
const LISTEN := &"LISTEN"
const TALK := &"TALK"
const CELEBRATE := &"CELEBRATE"
const DONT_HEAR := &"DONT_HEAR"
const CANT_TALK := &"CANT_TALK"

const MIC_BUS := &"Mic"
const FX_BUS := &"TalkBackFX"
const OUTPUT_BUS := &"Voice"
## Capture ring; the default 0.1 s overflows when a frame hitches.
const CAPTURE_BUFFER_SEC := 1.0
## 2048-point FFT at 4× overlap: Godot's default, clean on a baby's high voice,
## ~35 ms latency, a few % of one core and only while TALK plays.
const PITCH_FFT := AudioEffectPitchShift.FFT_SIZE_2048
const PITCH_FFT_SAMPLES := 2048
const PITCH_OVERSAMPLING := 4
const PITCH_MIN := 1.2
const PITCH_MAX := 1.8
const PITCH_JITTER := 0.05
## Slow ±1.5 % pitch drift so repeats sound alive, not robotic.
const WOBBLE_DEPTH := 0.015
const WOBBLE_HZ := 1.3
## Mic input is dropped during TALK and this long after, so the pet never hears itself.
## It is also dropped while a clip is processing and while the settings sheet is
## open. While AudioDirector is busy (pet SFX, haptic buzz) the detector is only
## muted: it skips those frames but keeps its state, so a clip survives a tap.
## Music and loops never gate the mic; AudioDirector ducks them from LISTEN
## through CELEBRATE. The recorder stays open during the lullaby.
const COOLDOWN_SEC := 0.4
## After the lullaby starts or stops, input is dropped this long, then the room is
## measured again so the floor includes (or no longer includes) the music.
const LULLABY_SETTLE_MSEC := 300
const CELEBRATE_SEC := 0.6
## Silence after each clip so the pitch shifter's FIFO drains before the bus idles.
const TAIL_PAD_SEC := 0.1
## Reopen the recorder this long after resume, once Android has unpaused the audio driver.
const MIC_RESUME_DELAY_MSEC := 250
## Restart the mic when it delivers no real signal (no frames, or exact digital
## zeros) for this long while listening; doubles after each failed try.
const MIC_DEAD_MSEC := 1500
const MIC_DEAD_MAX_MSEC := 30000
const BABBLE_PATH := "res://assets/audio/sfx/babble.ogg"
const BABBLE_SEC := 1.4
const BABBLE_STEPS := [[0.0, 520.0], [0.3, 650.0], [0.6, 440.0], [0.9, 720.0]]

enum Permission { UNKNOWN, GRANTED, DENIED }

## Calls start() in _ready. The game leaves this off and starts on first touch.
@export var autostart := false

var state: StringName = NOT_READY
var detector: VoiceDetector
var mouth := MouthFollower.new()
var permission := Permission.UNKNOWN
## Last clip, for the debug screen.
var last_clip_sec := 0.0
## Speech end → playback start, and the part of it spent processing.
var last_latency_ms := 0.0
var last_processing_ms := 0.0
var current_pitch := 1.0
## Capture frames per second over the last second, and watchdog restarts.
var capture_fps := 0
var mic_restarts := 0

var _capture: AudioEffectCapture
var _pitch_fx: AudioEffectPitchShift
var _mic_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _envelope := PackedFloat32Array()
var _started := false
var _paused := false
var _mic_running := false
## Mic wanted; the recorder opens at _mic_open_at_msec.
var _mic_pending := false
var _mic_open_at_msec := 0
var _live_msec := 0
var _dead_limit_msec := MIC_DEAD_MSEC
var _fps_frames := 0
var _fps_since_msec := 0
var _permission_requested := false
var _gate_until_msec := 0
var _talk_time := 0.0
var _base_pitch := 1.45
var _celebrate_left := 0.0
var _babble_stream: AudioStream
var _babble_envelope: PackedFloat32Array
var _mix_rate := 44100
var _device_open := false
var _was_gated := false
var _sheet_open := false
## A finished clip is being cleaned up; _clip_token invalidates stale results.
var _processing := false
var _clip_token := 0
var _tasks: Array[int] = []
var _finish_usec := 0
var _trailing_ms := 0.0


func _ready() -> void:
	_mix_rate = int(AudioServer.get_mix_rate())
	detector = VoiceDetector.new(_mix_rate)
	detector.speech_started.connect(_on_speech_started)
	detector.speech_finished.connect(_on_speech_finished)
	detector.too_short.connect(_on_too_short)
	_setup_buses()
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = MIC_BUS
	add_child(_mic_player)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = FX_BUS
	_voice_player.finished.connect(_on_playback_finished)
	add_child(_voice_player)
	(Engine.get_main_loop() as SceneTree).on_request_permissions_result.connect(_on_permission_result)
	EventBus.app_paused.connect(_on_app_paused)
	EventBus.app_resumed.connect(_on_app_resumed)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.test_voice_requested.connect(play_babble)
	EventBus.settings_opened.connect(func() -> void: _sheet_open = true)
	EventBus.settings_closed.connect(func() -> void: _sheet_open = false)
	detector.music = bool(Settings.get_value(&"lullaby_on"))
	if autostart:
		start()


func _exit_tree() -> void:
	_stop_mic()
	_drop_pending_clip()
	AudioDirector.set_ducked(false)
	for task in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()


## Begin listening. Asks for the mic permission on Android if needed.
## Always emits talkback_state_changed once, so listeners learn the state.
func start() -> void:
	_started = true
	_permission_requested = false
	_open_mic()
	var before := state
	_set_state(_resting_state())
	if state == before:
		EventBus.talkback_state_changed.emit(state)


func stop() -> void:
	_started = false
	_drop_pending_clip()
	_stop_mic()
	_stop_playback()
	_set_state(_resting_state())


## Plays a clip through the pitch path with mouth sync. Interrupts any clip playing.
func play_clip(stream: AudioStream, envelope: PackedFloat32Array) -> void:
	_drop_pending_clip()
	_read_input()
	detector.reset_listening()
	_envelope = envelope
	_base_pitch = clampf(float(Settings.get_value(&"voice_pitch")), PITCH_MIN, PITCH_MAX) + randf_range(-PITCH_JITTER, PITCH_JITTER)
	_talk_time = 0.0
	_apply_pitch()
	mouth.reset()
	_play_voice(stream)
	_set_state(TALK)


func is_mic_running() -> bool:
	return _mic_running


func play_babble() -> void:
	if _babble_stream == null:
		var samples := _make_babble()
		_babble_envelope = ClipProcessor.compute_envelope(samples, _mix_rate)
		if ResourceLoader.exists(BABBLE_PATH):
			_babble_stream = load(BABBLE_PATH)
		else:
			_babble_stream = ClipProcessor.make_stream(samples, _mix_rate, TAIL_PAD_SEC)
	play_clip(_babble_stream, _babble_envelope)


func _process(delta: float) -> void:
	if _mic_pending and _now() >= _mic_open_at_msec:
		_activate_mic()
	_pump_mic()
	if state == TALK:
		_talk_time += delta
		_apply_pitch()
		var pos := _voice_player.get_playback_position() + AudioServer.get_time_since_last_mix() \
				- AudioServer.get_output_latency() - float(PITCH_FFT_SAMPLES - PITCH_FFT_SAMPLES / PITCH_OVERSAMPLING) / _mix_rate
		var index := int(pos * ClipProcessor.ENVELOPE_RATE)
		var env: float = _envelope[index] if index >= 0 and index < _envelope.size() else 0.0
		EventBus.mouth_amplitude_changed.emit(mouth.update(env, delta))
	elif state == CELEBRATE:
		_celebrate_left -= delta
		if _celebrate_left <= 0.0:
			_set_state(_resting_state())


func _pump_mic() -> void:
	var now := _now()
	var buffer := _read_input()
	var frames := buffer.size()
	_fps_frames += frames
	if now - _fps_since_msec >= 1000:
		capture_fps = roundi(_fps_frames * 1000.0 / (now - _fps_since_msec))
		_fps_frames = 0
		_fps_since_msec = now
	if not _mic_running or _mic_pending:
		_live_msec = now
		return
	if is_input_gated():
		# Drain and forget: nothing heard now may start or extend a clip, and
		# the noise floor isn't fed our own sounds.
		if not _was_gated:
			_was_gated = true
			if detector.is_recording():
				detector.reset_listening()
				_set_state(_resting_state())
			else:
				detector.reset_listening()
		_live_msec = now
		return
	_was_gated = false
	# The app's own one-shot sounds only mute the detector, so a child who talks
	# while tapping the pet still gets a reply.
	detector.muted = AudioDirector.is_busy()
	if detector.muted:
		_live_msec = now
	if frames > 0:
		var was_calibrated := detector.is_calibrated()
		detector.feed_stereo(buffer)
		# A real mic never gives exact zeros; a closed recorder does.
		if detector.level > 0.0:
			_live_msec = now
			_dead_limit_msec = MIC_DEAD_MSEC
		if not was_calibrated and detector.is_calibrated() and state == NOT_READY:
			_set_state(_resting_state())
	if now - _live_msec > _dead_limit_msec:
		mic_restarts += 1
		_dead_limit_msec = mini(_dead_limit_msec * 2, MIC_DEAD_MAX_MSEC)
		print("TalkBack: no mic signal for %d ms, reopening (restart %d)" % [now - _live_msec, mic_restarts])
		_stop_mic()
		_open_mic()
		_set_state(_resting_state())


## Mic input is being discarded right now (see COOLDOWN_SEC).
func is_input_gated() -> bool:
	return state == TALK or _processing or _now() < _gate_until_msec or _sheet_open


## Waiting to open the recorder (resume delay or a failed input_start).
func is_mic_opening() -> bool:
	return _mic_pending or (_mic_running and not _device_open)


## The recorder is delivering real signal (not just digital silence).
func is_mic_live() -> bool:
	return _mic_running and _device_open and _now() - _live_msec < 300 and detector.level > 0.0


func _on_speech_started() -> void:
	_set_state(LISTEN)


# Clean-up of a 6 s clip takes 200–300 ms of GDScript on a phone, so it runs
# off the main thread; the pet stays in LISTEN until the result comes back.
func _on_speech_finished(clip: PackedFloat32Array) -> void:
	_finish_usec = Time.get_ticks_usec()
	_trailing_ms = detector.trailing_quiet_sec * 1000.0
	_clip_token += 1
	_processing = true
	_start_clip_job(_clip_token, clip, _mix_rate)


## Pure and thread-safe: cleaned stream + envelope, or {} if nothing is left.
static func build_clip(clip: PackedFloat32Array, rate: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var cleaned := ClipProcessor.process(clip, rate)
	if cleaned.is_empty():
		return {}
	return {
		&"stream": ClipProcessor.make_stream(cleaned, rate, TAIL_PAD_SEC),
		&"envelope": ClipProcessor.compute_envelope(cleaned, rate),
		&"sec": float(cleaned.size()) / rate,
		&"ms": (Time.get_ticks_usec() - t0) / 1000.0,
	}


func _on_clip_ready(token: int, result: Dictionary) -> void:
	_reap_tasks()
	if token != _clip_token or not _processing:
		return
	_processing = false
	if result.is_empty() or _paused or state != LISTEN:
		_set_state(_resting_state())
		return
	last_clip_sec = result[&"sec"]
	last_processing_ms = result[&"ms"]
	last_latency_ms = _trailing_ms + (Time.get_ticks_usec() - _finish_usec) / 1000.0
	play_clip(result[&"stream"], result[&"envelope"])


func _drop_pending_clip() -> void:
	if _processing:
		_processing = false
		_clip_token += 1


# Every WorkerThreadPool task must be waited on once to free it; these are done.
func _reap_tasks() -> void:
	for i in range(_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_tasks[i])
			_tasks.remove_at(i)


func _on_too_short(_duration_sec: float) -> void:
	_set_state(_resting_state())


func _on_playback_finished() -> void:
	_end_talk()
	_celebrate_left = CELEBRATE_SEC
	_set_state(CELEBRATE)


func _end_talk() -> void:
	_gate_until_msec = _now() + roundi(COOLDOWN_SEC * 1000.0)
	_read_input()
	detector.reset_listening()
	mouth.reset()
	EventBus.mouth_amplitude_changed.emit(0.0)


func _stop_playback() -> void:
	if _voice_player.playing or state == TALK:
		_stop_voice()
		_end_talk()


func _apply_pitch() -> void:
	current_pitch = _base_pitch * (1.0 + WOBBLE_DEPTH * sin(TAU * WOBBLE_HZ * _talk_time))
	_pitch_fx.pitch_scale = current_pitch


func _resting_state() -> StringName:
	if not Settings.get_value(&"talkback_on"):
		return CANT_TALK
	if permission == Permission.DENIED:
		return DONT_HEAR
	if _mic_running and detector.is_calibrated():
		return READY_TO_LISTEN
	return NOT_READY


func _set_state(next: StringName) -> void:
	if next == state:
		return
	state = next
	# Music and the purr turn down from the first syllable until the reply is over.
	AudioDirector.set_ducked(state == LISTEN or state == TALK or state == CELEBRATE)
	EventBus.talkback_state_changed.emit(state)


# Mic ------------------------------------------------------------------------

func _open_mic() -> void:
	if not _started or _paused or _mic_running or not Settings.get_value(&"talkback_on"):
		return
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		push_warning("TalkBack: audio/driver/enable_input is off; mic unavailable")
		return
	if _needs_runtime_permission() and not _has_permission():
		# Ask once per start() so a resume after the permission dialog (which
		# itself pauses the app) doesn't ask again. The answer arrives in
		# _on_permission_result.
		if _permission_requested:
			return
		_permission_requested = true
		if not _request_permission():
			return
	_set_permission(Permission.GRANTED)
	_mic_running = true
	_mic_pending = true
	_mic_open_at_msec = maxi(_mic_open_at_msec, _now())
	detector.recalibrate()


# Godot 4.7.2 opens/closes the OS recorder only through
# AudioServer.set_input_device_active(), a single flag with no refcount, which a
# mic playback sets on start and clears in its destructor. Stopping the player
# defers that destructor to the audio thread (paused by Android in the
# background), and a late destructor closes the recorder under a newer playback.
# So one playback lives as long as this node, and the recorder is switched
# directly: off on pause, on on resume.
func _activate_mic() -> void:
	_mic_pending = false
	_read_input()
	_live_msec = _now()
	var err := _open_device()
	_device_open = err == OK
	if err != OK and mic_restarts == 0:
		push_warning("TalkBack: mic input_start failed (%s); retrying with back-off" % error_string(err))


func _stop_mic() -> void:
	_close_device()
	_device_open = false
	_mic_running = false
	_mic_pending = false
	if detector:
		detector.recalibrate()


# Device, input, clock and permission seams; tests override these. -------------

## Runs build_clip off the main thread and hands the result to _on_clip_ready.
func _start_clip_job(token: int, clip: PackedFloat32Array, rate: int) -> void:
	_tasks.append(WorkerThreadPool.add_task(func() -> void:
		_on_clip_ready.call_deferred(token, build_clip(clip, rate)), false, "TalkBack clip"))


func _open_device() -> Error:
	# Off first: resets the flag if an earlier start failed (it is set before
	# the driver is asked), so the call below really reaches input_start().
	# Opened before play() so its error is the driver's, not the flag's.
	AudioServer.set_input_device_active(false)
	var err := AudioServer.set_input_device_active(true)
	if err != OK:
		AudioServer.set_input_device_active(false)
		return err
	if not _mic_player.playing:
		_mic_player.play()
	return OK


func _close_device() -> void:
	AudioServer.set_input_device_active(false)


func _play_voice(stream: AudioStream) -> void:
	_voice_player.stream = stream
	_voice_player.play()


func _stop_voice() -> void:
	_voice_player.stop()


## Drains the capture; returns whatever arrived since the last call.
func _read_input() -> PackedVector2Array:
	var frames := _capture.get_frames_available()
	return _capture.get_buffer(frames) if frames > 0 else PackedVector2Array()


func _now() -> int:
	return Time.get_ticks_msec()


func _request_permission() -> bool:
	return OS.request_permission("RECORD_AUDIO")


func _needs_runtime_permission() -> bool:
	return OS.get_name() == "Android"


func _has_permission() -> bool:
	for p in OS.get_granted_permissions():
		if p.ends_with("RECORD_AUDIO"):
			return true
	return false


func _set_permission(next: Permission) -> void:
	if next == permission:
		return
	permission = next
	EventBus.mic_permission_changed.emit(next == Permission.GRANTED)


func _on_permission_result(permission: String, granted: bool) -> void:
	if not permission.ends_with("RECORD_AUDIO"):
		return
	_set_permission(Permission.GRANTED if granted else Permission.DENIED)
	if granted:
		_open_mic()
	if state != TALK:
		_set_state(_resting_state())


# Lifecycle and settings -------------------------------------------------------

func _on_app_paused() -> void:
	_paused = true
	_drop_pending_clip()
	_stop_mic()
	_stop_playback()
	_set_state(_resting_state())


func _on_app_resumed() -> void:
	_paused = false
	_mic_open_at_msec = _now() + MIC_RESUME_DELAY_MSEC
	# _open_mic re-checks the permission: it may have been granted in system
	# settings while we were away.
	_open_mic()
	_set_state(_resting_state())


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"lullaby_on":
		# The mic stays open over the music. Skip input while it starts or stops,
		# then measure the room again with (or without) it.
		detector.music = bool(value)
		_drop_pending_clip()
		_gate_until_msec = maxi(_gate_until_msec, _now() + LULLABY_SETTLE_MSEC)
		detector.recalibrate()
		if state != TALK and state != CELEBRATE:
			_set_state(_resting_state())
		return
	if key != &"talkback_on":
		return
	if value:
		_mic_open_at_msec = _now() + MIC_RESUME_DELAY_MSEC
		_open_mic()
	else:
		_drop_pending_clip()
		_stop_mic()
		_stop_playback()
	_set_state(_resting_state())


func _setup_buses() -> void:
	var mic := _ensure_bus(MIC_BUS, &"Master")
	AudioServer.set_bus_mute(mic, true)
	if AudioServer.get_bus_effect_count(mic) == 0:
		var capture := AudioEffectCapture.new()
		capture.buffer_length = CAPTURE_BUFFER_SEC
		AudioServer.add_bus_effect(mic, capture)
	_capture = AudioServer.get_bus_effect(mic, 0) as AudioEffectCapture
	var fx := _ensure_bus(FX_BUS, OUTPUT_BUS)
	if AudioServer.get_bus_effect_count(fx) == 0:
		var shift := AudioEffectPitchShift.new()
		shift.fft_size = PITCH_FFT
		shift.oversampling = PITCH_OVERSAMPLING
		AudioServer.add_bus_effect(fx, shift)
	_pitch_fx = AudioServer.get_bus_effect(fx, 0) as AudioEffectPitchShift


func _ensure_bus(bus: StringName, send: StringName) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, send)
	return index


func _make_babble() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(BABBLE_SEC * _mix_rate))
	var step := 0
	for i in samples.size():
		var t := float(i) / _mix_rate
		while step + 1 < BABBLE_STEPS.size() and t >= BABBLE_STEPS[step + 1][0]:
			step += 1
		var f: float = BABBLE_STEPS[step][1]
		samples[i] = (sin(TAU * f * t) + 0.3 * sin(2.0 * TAU * f * t)) * (0.5 * sin(24.0 * t) + 0.5) * 0.45
	ClipProcessor.apply_fades(samples, _mix_rate)
	return samples
