extends TestCase


func _beats_of(id: StringName, beat: StringName) -> int:
	var count := 0
	for step: Dictionary in ToyScript.TOYS[id].steps:
		if step.get("beat", &"") == beat:
			count += (step.beats as Array).size()
	return count


func test_every_catalog_toy_has_a_session() -> void:
	for pet in 3:
		for toy: Dictionary in ToyCatalog.toys_for(pet):
			check(ToyScript.TOYS.has(toy.id), "session for %s" % toy.id)
			check(PetReactions.TOYS.has(toy.id), "mood for %s" % toy.id)


func test_steps_are_well_formed() -> void:
	for id: StringName in ToyScript.TOYS:
		var data: Dictionary = ToyScript.TOYS[id]
		var steps: Array = data.steps
		check_eq((steps.back() as Dictionary).get("cue", &""), &"finale", "%s ends with the finale" % id)
		check(not (data.end_sfx as Array).is_empty(), "%s end sound" % id)
		for step: Dictionary in steps:
			check(step.has("clip") or step.get("sec", 0.0) > 0.0, "%s step has a clip or a length" % id)
			var beats: Array = step.get("beats", [])
			check(beats.is_empty() or step.has("beat"), "%s beats have a handler" % id)
			var last := 0.0
			for b: float in beats:
				check(b > last and b < 1.0, "%s beats ascend inside the span" % id)
				last = b


func test_new_clips_have_a_stand_in_or_a_length() -> void:
	for id: StringName in ToyScript.TOYS:
		for step: Dictionary in ToyScript.TOYS[id].steps:
			if step.has("clip") and not ToyScript.BASE_CLIPS.has(step.clip):
				check(ToyScript.BASE_CLIPS.has(step.get("stand_in", &"")) or step.get("sec", 0.0) > 0.0, "%s %s fallback" % [id, step.clip])


func test_pet_gets_up_before_the_finale() -> void:
	for id: StringName in ToyScript.TOYS:
		var rest: StringName = &""
		var settled := false
		for step: Dictionary in ToyScript.TOYS[id].steps:
			rest = step.get("rest", rest)
			settled = settled or rest != &""
			if step.get("cue", &"") == &"finale":
				check_eq(rest, &"", "%s is up for its mood" % id)
		check(settled or ToyScript.TOYS[id].get("chase", false), "%s sits or lies down" % id)
		var opening: Array = (ToyScript.TOYS[id].steps as Array).slice(0, 3)
		check(opening.any(func(step: Dictionary) -> bool: return step.get("clip", &"") == &"excited"), "%s gets excited first" % id)


func test_span_and_replay() -> void:
	var drink := {clip = &"drink", stand_in = &"listen_nod", sec = 2.0}
	check_near(ToyScript.span(drink, 2.4), 2.4, 0.0001, "real clip sets the span")
	check(not ToyScript.replays(drink, 2.4), "real clip plays once")
	check_near(ToyScript.span(drink, 0.8), 2.0, 0.0001, "short stand-in stretches to sec")
	check(ToyScript.replays(drink, 0.8), "short stand-in replays on beats")
	check(not ToyScript.replays(drink, 0.0), "nothing to replay without a clip")
	var bat := {clip = &"bat_paw_L", sec = 0.5, hold = 0.55}
	check_near(ToyScript.duration(bat, 0.6), 1.15, 0.0001, "hold waits after the clip")
	check_near(ToyScript.duration({sec = 0.35}, 0.0), 0.35, 0.0001, "prop-only step")
	check_near(ToyScript.span({sec = 0.3}, 0.0, 0.9), 0.9, 0.0001, "a run sets the span")


func test_meals_reach_the_last_stage() -> void:
	for id in [&"fish", &"carrot"]:
		# The last loop's first beat bites, its second pops the rest out.
		check_eq(_beats_of(id, &"bite") + _beats_of(id, &"bite_out") / 2, ToyScript.LAST_STAGE, "%s bites" % id)
	check_eq(_beats_of(&"clover", &"nibble"), 4, "clover bobs")
	var stage := 0
	for i in 4:
		stage = ToyScript.stage_after(stage)
	check_eq(stage, ToyScript.LAST_STAGE, "stage stops at the last")
	check_eq(ToyScript.stage_after(0), 1, "first bite")


func test_liquids_drain() -> void:
	# Three gulps, then the cup pops out as it lowers.
	check_eq(_beats_of(&"milk", &"gulp"), 4, "gulps and the pop")
	var gulps := 3
	check_near(ToyScript.level_after(0, gulps, 0.0), 2.0 / 3.0, 0.0001, "a third per gulp")
	check_near(ToyScript.level_after(gulps - 1, gulps, ToyScript.TOYS[&"milk"].drain_to), ToyScript.TOYS[&"milk"].drain_to, 0.0001, "milk ends at a film")
	var laps := _beats_of(&"water", &"lap")
	check_eq(laps, 4, "four laps")
	check_near(ToyScript.level_after(laps - 1, laps, ToyScript.TOYS[&"water"].drain_to), 0.3, 0.0001, "water ends at 30%")


func test_chases_run_twice_and_come_home() -> void:
	for id in [&"yarn", &"ball"]:
		var cues: Array = []
		for step: Dictionary in ToyScript.TOYS[id].steps:
			cues.append(step.get("cue", &""))
		check_eq(cues.count(&"chase"), 2, "%s chases" % id)
		check_eq(cues.count(&"leap"), 2, "%s pounces" % id)
		check(cues.find(&"roll_off") < cues.find(&"home"), "%s ball leaves before the pet goes home" % id)
		check_eq(cues[cues.size() - 2], &"home", "%s home before the finale" % id)


func test_bats_alternate_paws() -> void:
	for id in [&"bell"]:
		var last := 0.0
		var bats := 0
		for step: Dictionary in ToyScript.TOYS[id].steps:
			if step.has("side"):
				check(step.side != last, "%s bats alternate" % id)
				check_eq(String(step.clip).ends_with("_L"), step.side < 0.0, "%s left paw sends it right" % id)
				last = step.side
				bats += 1
		check(bats >= 2, "%s has bats" % id)
