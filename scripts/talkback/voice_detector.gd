class_name VoiceDetector
extends RefCounted
## Voice-activity detector for talk-back. Pure logic: feed it mono (or stereo)
## sample chunks of any size; it slices them into fixed analysis windows so the
## result doesn't depend on how the audio driver happens to chunk input.
##
## Levels are RMS of one window, linear (1.0 = full scale).

signal speech_started
signal speech_finished(clip: PackedFloat32Array)
signal too_short(duration_sec: float)

enum Phase { CALIBRATING, IDLE, RECORDING }

## Windows quieter than this (−120 dBFS) are digital silence: a closed recorder.
## Not exact zero, because the Mic bus filters ring on in tiny values after input
## stops; a real mic's own noise is far louder (16-bit LSB ≈ −90 dBFS).
const DIGITAL_SILENCE := 0.000001

# Tunables. Defaults target a toddler's coos/babble at arm's length from a phone mic.
## Analysis window; 20 ms is short enough to catch syllable onsets.
var window_sec := 0.02
## Room-noise measurement before listening starts.
var calibration_sec := 0.5
## Start when level > floor × this (≈ +9.5 dB over the room).
var start_factor := 3.0
## Keep recording while level > floor × this (≈ +4 dB); lower than start = hysteresis.
var stop_factor := 1.6
## Never start below this, whatever the floor (≈ −40 dBFS); stops a dead-quiet room
## from triggering on tiny clicks.
var min_start_level := 0.01
## Never treat anything above this as quiet (≈ −46 dBFS).
var min_stop_level := 0.005
## Floor never goes below this (≈ −60 dBFS) so factors stay meaningful.
var min_floor := 0.001
## Level must stay above the start threshold this long before recording starts.
var start_sustain_sec := 0.1
## A start also needs a voice-like sound. At the end of the sustain span the level
## must be within this of the span's loudest window; a clock tick or a knock has
## rung out by then.
var onset_max_drop_db := 6.0
## And it must be centred below this frequency; birdsong and crickets sit higher.
var voice_max_hz := 3000.0
## Audio kept from before the start so soft onsets ("b", "m") aren't clipped.
var pre_roll_sec := 0.3
## Quiet this long ends the utterance.
var stop_silence_sec := 0.7
## Quiet audio kept after the last loud window; ClipProcessor trims it precisely.
var tail_keep_sec := 0.15
## Voiced time shorter than this is a bump or click, not babble.
var min_speech_sec := 0.4
## Hard cap on clip length (pre-roll included); recording is force-stopped here.
var max_clip_sec := 6.0
## Floor follows quiet windows: falls fast (room got quieter), rises slowly.
var floor_fall_sec := 0.5
var floor_rise_sec := 3.0
## Music (the lullaby) is playing. Its notes swell and die away every few seconds,
## so calibration spans a whole chord and takes a loud level, and the floor then
## sinks only slowly between notes; otherwise every new chord would look like
## speech. Set before recalibrate().
var music := false
var music_calibration_sec := 3.5
## Share of calibration windows the floor sits above (without music: the median).
var music_floor_percentile := 0.9
var music_floor_fall_sec := 30.0

## While true, incoming audio is skipped and nothing else changes: phase, partial
## clip, timers and floor stay as they are. For the app's own short sounds (SFX,
## haptic buzz), so a clip straddling one keeps going, minus the muted part.
var muted := false
var phase := Phase.CALIBRATING
var noise_floor := 0.0
## RMS of the most recent window.
var level := 0.0
## Quiet time between the last loud window and the moment speech_finished fired.
var trailing_quiet_sec := 0.0
## True when the last clip hit max_clip_sec.
var was_forced := false

var _rate := 44100
var _window := 882
var _win_sum := 0.0
var _win_count := 0
var _calib_levels: PackedFloat32Array = []
var _calib_target := 25

var _ring: PackedFloat32Array = []
var _ring_pos := 0
var _ring_filled := 0
var _candidate_windows := 0
var _sustain_windows := 5
## Candidate levels over the last sustain span, and the start rules in ratio form.
var _onset_levels: PackedFloat32Array = []
var _onset_hold := 0.5
var _max_brightness := 0.18

var _record: PackedFloat32Array = []
var _record_count := 0
var _pre_roll_in_record := 0
var _voiced_samples := 0
var _quiet_samples := 0
var _last_loud_end := 0
var _record_min_level := INF


func _init(sample_rate := 44100) -> void:
	configure(sample_rate)


## Applies the tunables and sample rate, and starts a fresh calibration.
func configure(sample_rate: int) -> void:
	_rate = sample_rate
	_window = maxi(1, roundi(window_sec * _rate))
	_sustain_windows = maxi(1, ceili(start_sustain_sec / window_sec))
	_onset_levels.resize(_sustain_windows)
	_onset_hold = db_to_linear(-onset_max_drop_db)
	# First-difference energy over energy is 4·sin²(π·f/rate) for a tone at f.
	_max_brightness = 4.0 * pow(sin(PI * minf(voice_max_hz / _rate, 0.5)), 2.0)
	_ring.resize(roundi(pre_roll_sec * _rate) + _sustain_windows * _window)
	_record.resize(roundi(max_clip_sec * _rate))
	recalibrate()


## Forgets the room and measures it again (mic restarted, app resumed, music
## started or stopped).
func recalibrate() -> void:
	noise_floor = 0.0
	_calib_levels.clear()
	_calib_target = maxi(1, roundi((music_calibration_sec if music else calibration_sec) / window_sec))
	phase = Phase.CALIBRATING
	reset_listening()


## Drops any partial utterance and pre-roll but keeps the floor. Call after
## talk-back playback so nothing heard during TALK leaks into the next clip.
func reset_listening() -> void:
	if phase == Phase.RECORDING:
		phase = Phase.IDLE
	_win_sum = 0.0
	_win_count = 0
	_ring_pos = 0
	_ring_filled = 0
	_candidate_windows = 0
	_record_count = 0
	level = 0.0


func is_calibrated() -> bool:
	return phase != Phase.CALIBRATING


func is_recording() -> bool:
	return phase == Phase.RECORDING


func start_threshold() -> float:
	return maxf(noise_floor * start_factor, min_start_level)


func stop_threshold() -> float:
	return maxf(noise_floor * stop_factor, min_stop_level)


func sample_rate() -> int:
	return _rate


func feed(samples: PackedFloat32Array) -> void:
	if muted:
		return
	for s in samples:
		_push(s)


## Takes AudioEffectCapture frames directly, downmixing to mono.
func feed_stereo(frames: PackedVector2Array) -> void:
	if muted:
		return
	for f in frames:
		_push((f.x + f.y) * 0.5)


func _push(s: float) -> void:
	if phase == Phase.RECORDING:
		_record[_record_count] = s
		_record_count += 1
	else:
		_ring[_ring_pos] = s
		_ring_pos = (_ring_pos + 1) % _ring.size()
		_ring_filled = mini(_ring_filled + 1, _ring.size())
	_win_sum += s * s
	_win_count += 1
	if _win_count == _window:
		level = sqrt(_win_sum / _window)
		_win_sum = 0.0
		_win_count = 0
		_on_window(level)
	elif phase == Phase.RECORDING and _record_count >= _record.size():
		_finish(true)


func _on_window(rms: float) -> void:
	match phase:
		Phase.CALIBRATING:
			# Digital silence means the recorder isn't delivering yet, not a silent room.
			if rms < DIGITAL_SILENCE:
				return
			_calib_levels.append(rms)
			if _calib_levels.size() >= _calib_target:
				# Median, so a coo during calibration doesn't inflate the floor;
				# with music, near the notes' peaks.
				_calib_levels.sort()
				var pct := music_floor_percentile if music else 0.5
				noise_floor = maxf(_calib_levels[mini(int(_calib_levels.size() * pct), _calib_levels.size() - 1)], min_floor)
				phase = Phase.IDLE
		Phase.IDLE:
			if rms > start_threshold() and _sounds_low(rms):
				_onset_levels[_candidate_windows % _sustain_windows] = rms
				_candidate_windows += 1
				if _candidate_windows >= _sustain_windows and _onset_holds(rms):
					_begin_recording()
			else:
				_candidate_windows = 0
				_track_floor(rms)
		Phase.RECORDING:
			_record_min_level = minf(_record_min_level, rms)
			if rms > stop_threshold():
				_quiet_samples = 0
				_voiced_samples = _record_count - _pre_roll_in_record
				_last_loud_end = _record_count
			else:
				_quiet_samples += _window
			if _quiet_samples >= roundi(stop_silence_sec * _rate):
				_finish(false)
			elif _record_count >= _record.size():
				_finish(true)


## Still near the loudest window of the sustain span: a voice holds there, a tick
## or knock has already rung out.
func _onset_holds(rms: float) -> bool:
	var top := 0.0
	for v in _onset_levels:
		top = maxf(top, v)
	return rms >= top * _onset_hold


## The window just finished (still in the ring) is centred below voice_max_hz.
## Only run for loud windows, so a quiet room costs nothing.
func _sounds_low(rms: float) -> bool:
	var size := _ring.size()
	var i := (_ring_pos - _window + size) % size
	var prev := _ring[(i - 1 + size) % size]
	var diff := 0.0
	for k in _window:
		var s := _ring[i]
		diff += (s - prev) * (s - prev)
		prev = s
		i = (i + 1) % size
	return diff <= rms * rms * _window * _max_brightness


func _track_floor(rms: float) -> void:
	var tc := (music_floor_fall_sec if music else floor_fall_sec) if rms < noise_floor else floor_rise_sec
	var alpha := clampf(window_sec / tc, 0.0, 1.0)
	noise_floor = maxf(lerpf(noise_floor, rms, alpha), min_floor)


func _begin_recording() -> void:
	# Copy the ring (pre-roll + the sustained candidate windows) in time order.
	var start := (_ring_pos - _ring_filled + _ring.size()) % _ring.size()
	for i in _ring_filled:
		_record[i] = _ring[(start + i) % _ring.size()]
	_record_count = _ring_filled
	_pre_roll_in_record = maxi(0, _ring_filled - _sustain_windows * _window)
	_voiced_samples = _record_count - _pre_roll_in_record
	_last_loud_end = _record_count
	_quiet_samples = 0
	_record_min_level = INF
	_candidate_windows = 0
	_ring_filled = 0
	phase = Phase.RECORDING
	speech_started.emit()


func _finish(forced: bool) -> void:
	phase = Phase.IDLE
	was_forced = forced
	if forced and _record_min_level < INF:
		# Six seconds with no quiet window is most likely a new steady noise
		# (fan, TV); lift the floor so it doesn't trigger again straight away.
		noise_floor = maxf(noise_floor, _record_min_level)
	var end := _record_count if forced else mini(_record_count, _last_loud_end + roundi(tail_keep_sec * _rate))
	trailing_quiet_sec = float(_record_count - _last_loud_end) / _rate
	var voiced := float(_voiced_samples) / _rate
	_record_count = 0
	_win_sum = 0.0
	_win_count = 0
	if voiced < min_speech_sec:
		too_short.emit(voiced)
		return
	speech_finished.emit(_record.slice(0, end))
