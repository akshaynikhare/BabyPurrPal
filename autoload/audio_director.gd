extends Node
## Owns the Music / SFX / Voice / Loops buses and plays pre-rendered OGG clips by name.
## Clips live in res://assets/audio/{sfx,voice,music}/<name>.ogg.

const SFX_DIR := "res://assets/audio/sfx/"
const VOICE_DIR := "res://assets/audio/voice/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_POOL_SIZE := 8
## Continuous loops (the purr). Like music, they never mute the mic; they duck.
const LOOPS_BUS := &"Loops"
## The spec's lullaby gain (0.25): music sits well under the pet's sounds, so a
## child's voice still stands out over it at the mic.
const MUSIC_DB := -12.0
## set_ducked: how far Music and Loops drop, how fast they go down and come back.
const DUCK_DB := -14.0
const DUCK_DOWN_SEC := 0.08
const DUCK_UP_SEC := 0.4

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _voice_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _cache := {}
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
	for bus in [&"Music", &"SFX", &"Voice", LOOPS_BUS]:
		_ensure_bus(bus)
	for i in SFX_POOL_SIZE:
		_sfx_players.append(_make_player(&"SFX"))
	_voice_player = _make_player(&"Voice")
	_music_player = _make_player(&"Music")
	_music_player.volume_db = MUSIC_DB
	_preload_all()


func play_sfx(clip: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := _load(SFX_DIR, clip)
	if stream == null:
		return
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	mark_busy(stream.get_length() / maxf(pitch, 0.01))


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
	return Time.get_ticks_msec() < busy_until_msec


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


## Loads every clip up front so the first use of a sound never stalls a frame.
func _preload_all() -> void:
	for dir in [SFX_DIR, VOICE_DIR, MUSIC_DIR]:
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".ogg"):
				_load(dir, StringName(file.get_basename()))


func _all_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = _sfx_players.duplicate()
	players.append(_voice_player)
	players.append(_music_player)
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
