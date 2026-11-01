extends TestCase
## AudioDirector busy tails and ducking. Ducking runs on a fresh instance outside
## the tree, where tweens don't advance, so targets are read after pause_all
## settles them.


func test_busy_tails() -> void:
	AudioDirector.busy_until_msec = 0
	var t0 := Time.get_ticks_msec()
	AudioDirector.mark_busy(0.5)
	check(AudioDirector.is_busy(), "busy")
	check_near(AudioDirector.busy_until_msec - t0, 650.0, 2.0, "SFX: clip + 150 ms")
	AudioDirector.busy_until_msec = 0
	t0 = Time.get_ticks_msec()
	Haptics.play(&"tap")
	check_near(AudioDirector.busy_until_msec - t0, 108.0, 2.0, "haptic: 8 ms buzz + 100 ms")
	AudioDirector.busy_until_msec = 0
	check(not AudioDirector.is_busy(), "quiet")


func test_duck_moves_music_and_loops_only() -> void:
	var ad: Node = load("res://autoload/audio_director.gd").new()
	ad._ready()
	var music := AudioServer.get_bus_index(&"Music")
	var loops := AudioServer.get_bus_index(AudioDirector.LOOPS_BUS)
	var sfx := AudioServer.get_bus_index(&"SFX")
	check(loops != -1, "Loops bus created")
	check_eq(AudioServer.get_bus_send(loops), AudioServer.get_bus_send(sfx), "Loops routed like SFX")
	check_near(ad._music_player.volume_db, AudioDirector.MUSIC_DB, 0.001, "music under the pet's sounds")
	ad.set_bus_muted(&"Music", true)
	ad.set_ducked(true)
	check(ad.ducked, "ducked")
	var down: Tween = ad._duck_tween
	check(down != null and down.is_running(), "ramps down")
	ad.set_ducked(true)
	check(ad._duck_tween == down, "same request, same ramp")
	ad.pause_all()
	check(not down.is_valid(), "nothing ramps in the background")
	check_near(AudioServer.get_bus_volume_db(music), AudioDirector.DUCK_DB, 0.001, "music down")
	check_near(AudioServer.get_bus_volume_db(loops), AudioDirector.DUCK_DB, 0.001, "loops down")
	check_near(AudioServer.get_bus_volume_db(sfx), 0.0, 0.001, "SFX untouched")
	check(AudioServer.is_bus_mute(music), "mute flag untouched")
	ad.set_ducked(false)
	check_near(AudioServer.get_bus_volume_db(music), 0.0, 0.001, "settles at once while paused")
	ad.resume_all()
	ad.set_ducked(true)
	down = ad._duck_tween
	ad.set_ducked(false)
	check(not down.is_valid(), "a new request replaces the ramp")
	check(ad._duck_tween.is_running(), "ramps back up")
	ad.pause_all()
	check_near(AudioServer.get_bus_volume_db(loops), 0.0, 0.001, "loops back up")
	ad.resume_all()
	ad.set_bus_muted(&"Music", false)
	ad.free()
