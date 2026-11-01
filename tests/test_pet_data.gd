extends TestCase


func test_phase_for_hour() -> void:
	check_eq(TimeOfDay.phase_for_hour(4), TimeOfDay.NIGHT, "4h")
	check_eq(TimeOfDay.phase_for_hour(5), TimeOfDay.SUNRISE, "5h")
	check_eq(TimeOfDay.phase_for_hour(8), TimeOfDay.SUNRISE, "8h")
	check_eq(TimeOfDay.phase_for_hour(9), TimeOfDay.DAY, "9h")
	check_eq(TimeOfDay.phase_for_hour(16), TimeOfDay.DAY, "16h")
	check_eq(TimeOfDay.phase_for_hour(17), TimeOfDay.SUNSET, "17h")
	check_eq(TimeOfDay.phase_for_hour(19), TimeOfDay.SUNSET, "19h")
	check_eq(TimeOfDay.phase_for_hour(20), TimeOfDay.NIGHT, "20h")
	check_eq(TimeOfDay.phase_for_hour(0), TimeOfDay.NIGHT, "0h")


func test_phase_cycle_wraps() -> void:
	check_eq(TimeOfDay.next_phase(TimeOfDay.SUNRISE), TimeOfDay.DAY, "sunrise→day")
	check_eq(TimeOfDay.next_phase(TimeOfDay.NIGHT), TimeOfDay.SUNRISE, "night→sunrise")


func test_each_phase_has_its_ambience_and_some_a_chime() -> void:
	check_eq(TimeOfDay.ambience_for(TimeOfDay.SUNRISE), &"amb_morning", "sunrise")
	check_eq(TimeOfDay.ambience_for(TimeOfDay.DAY), &"amb_day", "day")
	check_eq(TimeOfDay.ambience_for(TimeOfDay.SUNSET), &"amb_evening", "sunset")
	check_eq(TimeOfDay.ambience_for(TimeOfDay.NIGHT), &"amb_night", "night")
	check_eq(TimeOfDay.ambience_for(&"nope"), &"amb_day", "unknown phase")
	check_eq(TimeOfDay.CHIMES.get(TimeOfDay.SUNRISE), &"sunrise", "morning chime")
	check_eq(TimeOfDay.CHIMES.get(TimeOfDay.NIGHT), &"nightfall", "night chime")
	check(not TimeOfDay.CHIMES.has(TimeOfDay.DAY) and not TimeOfDay.CHIMES.has(TimeOfDay.SUNSET), "day and sunset keep the twinkle")


func test_every_zone_has_two_variants_and_a_reaction() -> void:
	for zone in PetReactions.ZONES:
		check((PetReactions.ZONE_ANIMS[zone] as Array).size() >= 2, "%s variants" % zone)
		for pet in PetReactions.PET_IDS:
			check(not PetReactions.zone_reaction(pet, zone).is_empty(), "%s %s reaction" % [pet, zone])


func test_toys_and_moods_line_up() -> void:
	for toy in [&"milk", &"fish", &"yarn", &"bone", &"ball", &"water", &"carrot", &"clover", &"bell"]:
		check(PetReactions.TOYS.has(toy), "toy %s" % toy)
		check(PetReactions.MOOD_ANIMS.has(PetReactions.TOYS[toy].mood), "toy %s mood" % toy)
	for pet in PetReactions.PET_IDS:
		check(PetReactions.MOOD_ANIMS.has(PetReactions.GREETINGS[pet].mood), "greeting %s" % pet)
