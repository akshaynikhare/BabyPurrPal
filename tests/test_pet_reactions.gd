extends TestCase
## Shape of the zone, tickle and greeting data: voices instead of particle bursts.

const L := TickleCounter.Level
## Clips the pet GLBs have today.
const GLB_CLIPS: Array[StringName] = [&"idle_breathe", &"happy_bounce", &"happy_wiggle", &"giggle", &"laugh_tumble",
		&"paw_highfive_L", &"paw_highfive_R", &"listen_nod", &"look_around", &"stretch", &"ear_perk", &"walk_in", &"wave"]


func _zone_reactions() -> Dictionary:
	var out := {}
	for pet in PetReactions.PET_IDS:
		for zone in PetReactions.ZONES:
			out["%s %s" % [pet, zone]] = PetReactions.zone_reaction(pet, zone)
	return out


func test_every_zone_has_a_voice_or_mimics() -> void:
	var reactions := _zone_reactions()
	for key: String in reactions:
		var r: Dictionary = reactions[key]
		check(r.has("voice") != r.get("mimic", false), "%s: voice xor mimic" % key)
		if key.ends_with("mouth"):
			check(r.get("mimic", false), "%s mimics" % key)


func test_zone_reactions_have_no_particle_bursts() -> void:
	var reactions := _zone_reactions()
	for key: String in reactions:
		for field: String in reactions[key]:
			check(not field.begins_with("fx") and field != "count", "%s has %s" % [key, field])
		check(not (reactions[key].get("sfx", []) as Array).has(&"giggle"), "%s uses the giggle SFX" % key)
	for level in PetReactions.TICKLES:
		check(not PetReactions.TICKLES[level].has("fx") and not PetReactions.TICKLES[level].has("count"), "tickle %d burst" % level)


func test_every_voice_line_exists() -> void:
	var tb := TalkBack.new()
	var voice := PetVoice.new(tb)
	var lines := {}
	var reactions := _zone_reactions()
	for key: String in reactions:
		if reactions[key].has("voice"):
			lines[reactions[key].voice] = key
	for level in PetReactions.TICKLES:
		lines[PetReactions.TICKLES[level].voice] = "tickle %d" % level
	for pet in PetReactions.PET_IDS:
		lines[PetReactions.GREETINGS[pet].voice] = "greeting %s" % pet
	for line: StringName in lines:
		check(voice.has(line), "%s: %s" % [lines[line], line])
	voice.free()
	tb.free()


func test_every_pet_has_its_greeting_play_idle_and_toy_lines() -> void:
	var tb := TalkBack.new()
	var voice := PetVoice.new(tb, PetReactions.PET_IDS)
	for index in PetReactions.PET_IDS.size():
		var pet := PetReactions.PET_IDS[index]
		voice.use_pet(pet)
		var lines: Array[StringName] = [PetReactions.COME_PLAY[pet].voice, PetReactions.YAWN, PetReactions.HUM]
		for phase in TimeOfDay.ORDER:
			lines.append(PetReactions.greeting_line(pet, phase))
		for toy: Dictionary in ToyCatalog.toys_for(index):
			lines.append(PetReactions.toy_line(toy.id))
		for line in lines:
			check(voice.has(line), "%s: %s" % [pet, line])
	voice.free()
	tb.free()


func test_greeting_follows_the_time_of_day() -> void:
	check_eq(PetReactions.greeting_line(&"dog", TimeOfDay.SUNRISE), &"morning", "sunrise")
	check_eq(PetReactions.greeting_line(&"dog", TimeOfDay.NIGHT), &"night", "night")
	check_eq(PetReactions.greeting_line(&"dog", TimeOfDay.DAY), &"hello*", "day")
	check_eq(PetReactions.greeting_line(&"cat", TimeOfDay.SUNSET), &"hello*", "sunset")
	check_eq(PetReactions.toy_line(&"milk"), &"toy_milk", "toy line")


func test_each_pet_sounds_like_itself() -> void:
	var calls := {&"cat": [&"meow", &"chirp", &"trill"], &"dog": [&"woof", &"yip", &"pant", &"whine"], &"bunny": [&"squeak", &"snuffle"]}
	for pet in PetReactions.PET_IDS:
		var reactions: Array = [PetReactions.GREETINGS[pet], PetReactions.COME_PLAY[pet]]
		for zone in [&"ears", &"cheeks"]:
			reactions.append(PetReactions.zone_reaction(pet, zone))
		for r: Dictionary in reactions:
			var sfx: Array = r.get("sfx", [])
			check(not sfx.is_empty() and (calls[pet] as Array).has(sfx[0]), "%s calls with its own voice, got %s" % [pet, sfx])
		check_eq((PetReactions.zone_reaction(pet, &"belly").sfx as Array)[0], &"boing", "%s belly boing" % pet)
	check_eq(PetReactions.COME_PLAY[&"dog"].sfx, [&"whine"], "the dog whines to play")
	check(not PetReactions.COME_PLAY[&"cat"].has("haptic"), "no buzz with the wave")


func test_tickles_escalate() -> void:
	var t := PetReactions.TICKLES
	check_eq(t[L.GIGGLE].voice, &"giggle*", "giggle level")
	check_eq(t[L.LAUGH].voice, &"laugh*", "laugh level")
	check_eq(t[L.TUMBLE].voice, &"laugh*+hooray", "tumble level")
	for field in ["ms", "squash", "wobble"]:
		check(t[L.TUMBLE][field] > t[L.LAUGH][field], "tumble %s > laugh %s" % [field, field])
	check_eq(t[L.LAUGH].anims[0], &"laugh", "laugh clip")
	check_eq(t[L.TUMBLE].anims[0], &"laugh_tumble", "tumble clip")


func test_belly_ears_cheeks_and_paw_animations() -> void:
	var anims := PetReactions.ZONE_ANIMS
	var laughs := 0
	for variant: Array in anims[&"belly"]:
		laughs += 1 if variant[0] == &"laugh" else 0
	check(laughs >= 2, "belly mostly laughs")
	for variant: Array in anims[&"ears"]:
		check_eq(variant[0], &"ear_perk", "ears perk first")
	check((anims[&"ears"][0] as Array).has(&"head_shake"), "ears shake the head")
	for variant: Array in anims[&"cheeks"]:
		check_eq(variant[0], &"giggle", "cheeks giggle")
	for side in [&"paw_L", &"paw_R"]:
		for variant: Array in anims[side]:
			check_eq(variant[0], StringName("paw_highfive_" + String(side).right(1)), "%s high five" % side)
	for pet in PetReactions.PET_IDS:
		check(PetReactions.zone_reaction(pet, &"belly").get("wobble", 0.0) > 0.0, "%s belly wobble" % pet)
		check(PetReactions.zone_reaction(pet, &"cheeks").get("twitch", 0) > 0, "%s cheek nose twitch" % pet)


func test_every_clip_exists_or_has_a_stand_in() -> void:
	var sequences: Array = []
	for zone in PetReactions.ZONE_ANIMS:
		sequences.append_array(PetReactions.ZONE_ANIMS[zone])
	for mood in PetReactions.MOOD_ANIMS:
		sequences.append_array(PetReactions.MOOD_ANIMS[mood])
	for level in [L.LAUGH, L.TUMBLE]:
		sequences.append(PetReactions.TICKLES[level].anims)
	for clips: Array in sequences:
		for clip: StringName in clips:
			var known := GLB_CLIPS.has(clip) or GLB_CLIPS.has(PetReactions.ANIM_FALLBACKS.get(clip, &""))
			check(known, "clip %s" % clip)
