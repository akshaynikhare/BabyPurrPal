extends TestCase
## Every sound the pets, toys, room and UI name exists as a file or a set of takes,
## and each pet's body sounds are its own.

const UI: Array[StringName] = [&"ui_toy", &"ui_nope", &"ui_open", &"ui_close", &"ui_hold", &"ui_unlock",
		&"ui_tick", &"ui_tap", &"ui_zoom_in", &"ui_zoom_out", &"ui_swipe"]
const PROPS: Array[StringName] = [&"gulp", &"slurp", &"bounce", &"jingle", &"pop_in", &"pop_out", &"paw_tap", &"roll"]


func _exists(sound: StringName) -> bool:
	var base := AudioDirector.SFX_DIR + String(sound)
	return ResourceLoader.exists(base + ".ogg") or ResourceLoader.exists(base + "_1.ogg")


func _per_pet(sound: Variant) -> Array:
	var out := []
	for pet in PetReactions.PET_IDS:
		var name := PetSounds.pick(sound, pet)
		if name != &"":
			out.append(name)
	return out


func test_every_named_sound_exists() -> void:
	var sounds := {}
	for name in UI + PROPS + PetSounds.SURPRISES + [PetSounds.RUN]:
		sounds[name] = "fixed"
	for clip: StringName in PetSounds.CLIPS:
		for cue: Array in PetSounds.CLIPS[clip]:
			for name in _per_pet(cue[1]):
				sounds[name] = "clip %s" % clip
	for table in [PetSounds.STEPS, PetSounds.EAT, PetSounds.DRINK, PetSounds.ECHO_CALL, PetSounds.PURR, PetSounds.PURR_TAIL]:
		for name in _per_pet(table):
			sounds[name] = "pet table"
	for pet in PetReactions.PET_IDS:
		for zone in PetReactions.ZONES:
			for name: StringName in PetReactions.zone_reaction(pet, zone).get("sfx", []):
				sounds[name] = "%s %s" % [pet, zone]
		for name: StringName in PetReactions.GREETINGS[pet].sfx + PetReactions.COME_PLAY[pet].sfx:
			sounds[name] = "%s greeting" % pet
	for id: StringName in ToyScript.TOYS:
		var data: Dictionary = ToyScript.TOYS[id]
		var names: Array = data.end_sfx + data.get("appear_sfx", [])
		for key in ["lift_sfx", "roll_sfx", "eat_sfx"]:
			if data.has(key):
				names.append(data[key])
		for name: StringName in names:
			sounds[name] = "toy %s" % id
	for phase in TimeOfDay.ORDER:
		sounds[TimeOfDay.ambience_for(phase)] = "ambience %s" % phase
	for phase: StringName in TimeOfDay.CHIMES:
		sounds[TimeOfDay.CHIMES[phase]] = "chime %s" % phase
	for name: StringName in sounds:
		check(_exists(name), "%s (%s)" % [name, sounds[name]])


func test_each_pet_has_its_own_steps_bites_and_calls() -> void:
	for table in [PetSounds.STEPS, PetSounds.EAT, PetSounds.ECHO_CALL, PetSounds.EXCITED]:
		var names := _per_pet(table)
		check_eq(names.size(), PetReactions.PET_IDS.size(), "every pet")
		var unique := {}
		for name: StringName in names:
			unique[name] = true
		check_eq(unique.size(), names.size(), "no two pets share %s" % [names])
	check_eq(PetSounds.pick(PetSounds.DRINK, &"bunny"), &"sip", "the bunny sips")
	check(not PetSounds.PURR.has(&"dog"), "the dog doesn't purr")


func test_clip_cues_fall_inside_real_clips() -> void:
	for pet in PetReactions.PET_IDS:
		var model: Node = (load("res://assets/characters/%s.glb" % pet) as PackedScene).instantiate()
		var player: AnimationPlayer = model.get_node("AnimationPlayer")
		for clip: StringName in PetSounds.CLIPS:
			if not player.has_animation(clip):
				check(false, "%s has %s" % [pet, clip])
				continue
			var last := -1.0
			for cue: Array in PetSounds.CLIPS[clip]:
				check(cue[0] > last and cue[0] < player.get_animation(clip).length, "%s %s cue at %s" % [pet, clip, cue[0]])
				last = cue[0]
		model.free()


func test_a_locked_toy_answers_a_press_once() -> void:
	var bar := ToyBar.new()
	bar._ready()
	var refused := [0]
	bar._buttons[0].refused.connect(func() -> void: refused[0] += 1)
	bar.set_locked(true)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	bar._buttons[0]._gui_input(touch)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	bar._buttons[0]._gui_input(mouse)
	check_eq(refused[0], 1, "one 'not now' per touch")
	bar.free()
