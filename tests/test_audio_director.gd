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
	check_near(AudioServer.get_bus_volume_db(sfx), AudioDirector.SFX_DB, 0.001, "SFX untouched")
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


func test_takes_play_one_at_a_time_without_repeats() -> void:
	var ad: Node = load("res://autoload/audio_director.gd").new()
	ad._ready()
	var seen := {}
	var last := &""
	for i in 30:
		var take: StringName = ad.take(&"woof")
		check(String(take).begins_with("woof_"), "woof take %s" % take)
		check(take != last, "repeat at %d" % i)
		seen[take] = true
		last = take
	check_eq(seen.size(), 3, "every woof take")
	check_eq(ad.take(&"ui_hold"), &"ui_hold", "a single file plays itself")
	check_eq(ad.take(&"chime_3"), &"chime_3", "a numbered file is still itself")
	ad.free()


func test_only_animal_and_body_sounds_vary() -> void:
	var ad: Node = load("res://autoload/audio_director.gd").new()
	ad._ready()
	for clip in [&"woof", &"woof_2", &"pad", &"run", &"boing"]:
		check(ad.varies(clip), "%s varies" % clip)
	for clip in [&"chime_4", &"ui_tap", &"ui_tap_1", &"ui_hold", &"twinkle", &"sunrise", &"nightfall", &"yum", &"giggle", &"purr_tail"]:
		check(not ad.varies(clip), "%s stays steady" % clip)
	ad.free()


func test_mix_has_limiters_and_a_quiet_mode() -> void:
	var ad: Node = load("res://autoload/audio_director.gd").new()
	ad._ready()
	ad._ensure_limiter(&"Master")
	for bus in [&"Master", &"SFX"]:
		var index := AudioServer.get_bus_index(bus)
		var limiters := 0
		for i in AudioServer.get_bus_effect_count(index):
			var effect := AudioServer.get_bus_effect(index, i)
			if effect is AudioEffectHardLimiter:
				limiters += 1
				check_near(effect.ceiling_db, AudioDirector.LIMIT_CEILING_DB, 0.001, "%s ceiling" % bus)
		check_eq(limiters, 1, "one limiter on %s" % bus)
	check(AudioDirector.MUSIC_DB < AudioDirector.SFX_DB and AudioDirector.AMBIENCE_DB < AudioDirector.SFX_DB, "music and ambience under SFX")
	check(AudioDirector.DUCK_DB <= -20.0, "deep duck while listening")
	var master := AudioServer.get_bus_index(&"Master")
	ad._on_settings_changed(&"quiet_mode", true)
	check_near(AudioServer.get_bus_volume_db(master), AudioDirector.QUIET_DB, 0.001, "quiet")
	ad._on_settings_changed(&"quiet_mode", false)
	check_near(AudioServer.get_bus_volume_db(master), 0.0, 0.001, "full volume")
	ad.free()


func test_ambience_loops_are_ducked_with_the_music() -> void:
	var ad: Node = load("res://autoload/audio_director.gd").new()
	ad._ready()
	check_eq(ad._ambience.size(), 2, "two players to cross-fade")
	for player: AudioStreamPlayer in ad._ambience:
		check(player.bus == AudioDirector.LOOPS_BUS, "ambience on Loops")
	ad.free()
