extends Node
## Owns the Music / SFX / Voice / Loops buses and plays pre-rendered OGG clips by name.
## Clips live in res://assets/audio/{sfx,voice,music}/<name>.ogg. A name with takes
## <name>_1.ogg ... <name>_N.ogg plays one of them, never the same one twice in a row.
## The mix is anchored on the pets' voice lines (Voice bus, 0 dB, files at -19 LUFS).

const SFX_DIR := "res://assets/audio/sfx/"
const VOICE_DIR := "res://assets/audio/voice/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_POOL_SIZE := 8
## Continuous loops (the purr, the room ambience). Like music, they never mute the mic; they duck.
const LOOPS_BUS := &"Loops"
## One-shots (-22 LUFS files) land about 6 dB under the voice.
const SFX_DB := -3.0
## Music files are -20 LUFS: this puts the lullaby and day music about 9 dB under
## the voice, so a child's voice still stands out over them at the mic.
const MUSIC_DB := -8.0
## Ambience files are -30 LUFS: about 20 dB under the voice, on Loops.
const AMBIENCE_DB := -9.0
const AMBIENCE_FADE_SEC := 2.0
const SILENT_DB := -60.0
## set_ducked: how far Music and Loops drop, how fast they go down and come back.
const DUCK_DB := -24.0
const DUCK_DOWN_SEC := 0.08
const DUCK_UP_SEC := 0.4
## Master never clips. SFX get their own limiter first, so a burst of them is held
## to one sound's level and can't push the Master limiter down on the pet's voice.
const LIMIT_CEILING_DB := -1.0
## quiet_mode setting: Master turned down.
const QUIET_DB := -8.0
## Takes vary a little per play so repeats sound alive.
const VARY_PITCH := 0.03
const VARY_DB := 1.5
## Musical and UI sounds stay in tune and level; so does the purr tail, which
## continues the purr loop sample for sample.
const STEADY_PREFIXES: Array[String] = ["chime_", "ui_"]
const STEADY: Array[StringName] = [&"twinkle", &"sunrise", &"nightfall", &"yum", &"giggle", &"purr_tail"]

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _voice_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
## [0] is the ambience playing (or fading in), [1] the one fading out.
var _ambience: Array[AudioStreamPlayer] = []
var _ambience_tween: Tween
## start_sfx players, one per name, outside the pool.
var _held := {}
var _held_players: Array[AudioStreamPlayer] = []
var _cache := {}
## SFX name → its takes, and a picker for each (filled at preload).
var _takes := {}
var _pickers := {}
## SFX names (files and take sets) that play without variation.
var _steady := {}
var _rng := RandomNumberGenerator.new()
## Ticks (msec) until which the app's own sound may still be audible to the mic.
## Talk-back's detector skips mic input until then (keeping its state), so the pet
## never repeats its own sounds.
var busy_until_msec := 0
## Music and Loops are turned down (see set_ducked).
var ducked := false
var _duck_db := 0.0
var _duck_tween: Tween
var _paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for bus in [&"Music", &"SFX", &"Voice", LOOPS_BUS]:
		_ensure_bus(bus)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), SFX_DB)
	_ensure_limiter(&"SFX")
	_ensure_limiter(&"Master")
	for i in SFX_POOL_SIZE:
		_sfx_players.append(_make_player(&"SFX"))
	_voice_player = _make_player(&"Voice")
	_music_player = _make_player(&"Music")
	_music_player.volume_db = MUSIC_DB
	for i in 2:
		_ambience.append(_make_player(LOOPS_BUS))
	_preload_all()
	_set_quiet(bool(Settings.get_value(&"quiet_mode")))
	EventBus.settings_changed.connect(_on_settings_changed)


func play_sfx(clip: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	# Headless test runs (-s) reach here before the autoloads join the tree.
	if not is_inside_tree():
		return
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	var stream := _play_on(player, clip, volume_db, pitch)
	if stream:
		mark_busy(stream.get_length() / player.pitch_scale)


## Starts a sound its caller ends with stop_sfx: a loop (the run patter) or a hold
## that may be let go early. Each name has its own player, so the SFX pool never
## cuts it short. The mic counts as busy while it plays.
func start_sfx(clip: StringName, volume_db := 0.0) -> void:
	if not is_inside_tree():
		return
	if not _held.has(clip):
		var made := _make_player(&"SFX")
		_held[clip] = made
		_held_players.append(made)
	_play_on(_held[clip], clip, volume_db, 1.0)


func stop_sfx(clip: StringName) -> void:
	var player: AudioStreamPlayer = _held.get(clip)
	if player and player.playing:
		player.stop()
		mark_busy(0.0)


## The file a play of `clip` uses: one of its takes, or the clip itself.
func take(clip: StringName) -> StringName:
	if _takes.has(clip):
		return (_takes[clip] as Array[StringName])[(_pickers[clip] as NoRepeatPicker).pick()]
	return clip


## Whether plays of `clip` get the small random pitch and level change.
func varies(clip: StringName) -> bool:
	return not _steady.has(clip)


## Plays a spoken line, cutting off any line already playing.
func play_voice(clip: StringName) -> void:
	var stream := _load(VOICE_DIR, clip)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.play()
	mark_busy(stream.get_length())


## Extends the "own sound playing" window by `seconds` plus a short room-decay tail.
func mark_busy(seconds: float, tail_msec := 150) -> void:
	busy_until_msec = maxi(busy_until_msec, Time.get_ticks_msec() + int(seconds * 1000.0) + tail_msec)


func is_busy() -> bool:
	if Time.get_ticks_msec() < busy_until_msec:
		return true
	for player in _held_players:
		if player.playing:
			return true
	return false


func stop_voice() -> void:
	_voice_player.stop()


func play_music(clip: StringName) -> void:
	var stream := _load(MUSIC_DIR, clip)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


## Loops a room ambience on Loops (ducked with the music), cross-fading from the one playing.
func play_ambience(clip: StringName) -> void:
	var stream := _load(SFX_DIR, clip)
	if stream == null or (_ambience[0].stream == stream and _ambience[0].playing):
		return
	_ambience.reverse()
	var next := _ambience[0]
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_fade_ambience(AMBIENCE_DB)


func stop_ambience() -> void:
	_ambience.reverse()
	_fade_ambience(SILENT_DB)


func set_bus_muted(bus: StringName, muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), muted)


## Turns the Music and Loops buses down (quickly) while talk-back listens and
## talks, and back up (gently) after. Only bus volume moves; mute flags stay.
func set_ducked(on: bool) -> void:
	if on == ducked:
		return
	ducked = on
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = null
	if _paused:
		_set_duck_db(DUCK_DB if on else 0.0)
		return
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck_db, _duck_db, DUCK_DB if on else 0.0, DUCK_DOWN_SEC if on else DUCK_UP_SEC)


func pause_all() -> void:
	_paused = true
	# Settle a duck in progress now, so nothing ramps in the background.
	if _duck_tween:
		_duck_tween.kill()
		_duck_tween = null
		_set_duck_db(DUCK_DB if ducked else 0.0)
	for player in _all_players():
		player.stream_paused = true


func resume_all() -> void:
	_paused = false
	for player in _all_players():
		player.stream_paused = false


## Picks the take, varies it and plays it on `player`; returns the stream, null if missing.
func _play_on(player: AudioStreamPlayer, clip: StringName, volume_db: float, pitch: float) -> AudioStream:
	var stream := _load(SFX_DIR, take(clip))
	if stream == null:
		return null
	if varies(clip):
		pitch *= 1.0 + _rng.randf_range(-VARY_PITCH, VARY_PITCH)
		volume_db += _rng.randf_range(-VARY_DB, VARY_DB)
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch, 0.01)
	player.play()
	return stream


## [0] fades to `db` (the ambience level, or out), [1] fades out and stops.
func _fade_ambience(db: float) -> void:
	if _ambience_tween:
		_ambience_tween.kill()
	var outgoing := _ambience[1]
	_ambience_tween = create_tween().set_parallel()
	_ambience_tween.tween_property(_ambience[0], "volume_db", db, AMBIENCE_FADE_SEC)
	_ambience_tween.tween_property(outgoing, "volume_db", SILENT_DB, AMBIENCE_FADE_SEC)
	_ambience_tween.chain().tween_callback(outgoing.stop)
	if db <= SILENT_DB:
		_ambience_tween.tween_callback(_ambience[0].stop)


## Loads every clip up front so the first use of a sound never stalls a frame, and
## gathers the SFX takes (name_1, name_2, ...) under their name.
func _preload_all() -> void:
	for dir in [SFX_DIR, VOICE_DIR, MUSIC_DIR]:
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".ogg"):
				var clip := StringName(file.get_basename())
				_load(dir, clip)
				if dir == SFX_DIR:
					_index(clip)
	for clip: StringName in _takes:
		_pickers[clip] = NoRepeatPicker.new((_takes[clip] as Array).size())


func _index(clip: StringName) -> void:
	var name := String(clip)
	var cut := name.rfind("_")
	var names: Array[StringName] = [clip]
	if cut > 0 and name.substr(cut + 1).is_valid_int():
		var base := StringName(name.left(cut))
		if not _takes.has(base):
			var takes: Array[StringName] = []
			_takes[base] = takes
		(_takes[base] as Array[StringName]).append(clip)
		names.append(base)
	for each in names:
		if STEADY.has(each) or STEADY_PREFIXES.any(func(prefix: String) -> bool: return String(each).begins_with(prefix)):
			_steady[each] = true


func _all_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = _sfx_players.duplicate()
	players.append(_voice_player)
	players.append(_music_player)
	players.append_array(_ambience)
	players.append_array(_held_players)
	return players


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


func _ensure_limiter(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	for i in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMIT_CEILING_DB
	AudioServer.add_bus_effect(index, limiter)


func _set_quiet(on: bool) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), QUIET_DB if on else 0.0)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"quiet_mode":
		_set_quiet(bool(value))


func _set_duck_db(db: float) -> void:
	_duck_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(LOOPS_BUS), db)


func _load(dir: String, clip: StringName) -> AudioStream:
	var path := dir + String(clip) + ".ogg"
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("AudioDirector: missing clip " + path)
		_cache[path] = null
		return null
	var stream: AudioStream = load(path)
	_cache[path] = stream
	return stream
