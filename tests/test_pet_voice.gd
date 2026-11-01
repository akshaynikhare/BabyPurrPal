extends TestCase
## PetVoice: every pet's voice lines load with their envelopes, pick without repeats,
## chain, play at their own pitch and keep quiet while the child talks or their echo plays.

## Every pet's lines (tools/audio/eleven_lines.csv), plus one naming each of its toys.
const LINES := ["laugh_1", "laugh_2", "laugh_3", "laugh_4", "laugh_5", "laugh_6", "giggle_1", "giggle_2", "giggle_3",
		"giggle_4", "giggle_5", "squeal_1", "squeal_2", "yum_1", "yum_2", "ahh", "ooh", "hooray", "wow", "hello_1",
		"hello_2", "hello_3", "come_play_1", "come_play_2", "morning", "night", "yawn", "hum"]
const TOY_LINES := {
	&"cat": ["toy_milk", "toy_fish", "toy_yarn"],
	&"dog": ["toy_bone", "toy_water", "toy_ball"],
	&"bunny": ["toy_carrot", "toy_clover", "toy_bell"],
}


class FakeTalkBack extends TalkBack:
	var played: Array[String] = []
	var paths: Array[String] = []
	var envelopes: Array[PackedFloat32Array] = []
	var pitched: Array[bool] = []

	func play_clip(stream: AudioStream, envelope: PackedFloat32Array, is_pitched := true) -> void:
		played.append(stream.resource_path.get_file().get_basename())
		paths.append(stream.resource_path)
		envelopes.append(envelope)
		pitched.append(is_pitched)


var _tb: FakeTalkBack
var _voice: PetVoice


func _make() -> void:
	_tb = FakeTalkBack.new()
	_voice = PetVoice.new(_tb, PetReactions.PET_IDS)


func _done() -> void:
	_voice.free()
	_tb.free()


func test_every_pet_has_every_line_with_a_matching_envelope() -> void:
	_make()
	for pet_id in PetReactions.PET_IDS:
		_voice.use_pet(pet_id)
		for id in LINES + TOY_LINES[pet_id]:
			var where := "%s/%s" % [pet_id, id]
			check(_voice.has(StringName(id)), "has " + where)
			var stream: AudioStream = _voice._streams.get(StringName(id))
			var env: PackedFloat32Array = _voice._envelopes.get(StringName(id), PackedFloat32Array())
			if stream == null or env.is_empty():
				check(false, where + " loaded")
				continue
			check(stream.resource_path.contains("/%s/" % pet_id), where + " is the pet's own clip")
			var voiced := stream.get_length() - TalkBack.TAIL_PAD_SEC
			check_near(env.size() / ClipProcessor.ENVELOPE_RATE, voiced, 1.0 / ClipProcessor.ENVELOPE_RATE, where + " envelope length")
			var top := 0.0
			for v in env:
				top = maxf(top, v)
			check_near(top, 1.0, 0.0001, where + " envelope peak")
	_done()


func test_each_pet_speaks_in_its_own_voice_unpitched() -> void:
	_make()
	for pet_id in PetReactions.PET_IDS:
		_voice.use_pet(pet_id)
		_voice.say(&"hooray")
		check(_tb.paths[-1].contains("/%s/" % pet_id), "%s says its own hooray" % pet_id)
	check_eq(_tb.pitched, [false, false, false] as Array[bool], "pet lines skip the pitch path")
	_done()


func test_has_checks_every_part() -> void:
	_make()
	check(_voice.has(&"laugh*"), "laugh*")
	check(_voice.has(&"ooh|giggle*"), "ooh|giggle*")
	check(_voice.has(&"laugh*+hooray"), "laugh*+hooray")
	check(not _voice.has(&"nope"), "nope")
	check(not _voice.has(&"nope*"), "nope*")
	check(not _voice.has(&"laugh*+nope"), "laugh*+nope")
	check(not _voice.has(&"ooh|nope"), "ooh|nope")
	_done()


func test_say_plays_the_clip_with_its_envelope() -> void:
	_make()
	_voice.say(&"hooray")
	check_eq(_tb.played, ["hooray"] as Array[String], "played")
	check_eq(_tb.envelopes[0], _voice._envelopes[&"hooray"], "envelope")
	_done()


func test_random_lines_never_repeat_back_to_back() -> void:
	_make()
	for i in 24:
		_voice.say_random(&"laugh")
	for i in 24:
		_voice.say(&"ooh|giggle*")
	var seen := {}
	for i in _tb.played.size():
		seen[_tb.played[i]] = true
		if i != 0 and i != 24:
			check(_tb.played[i] != _tb.played[i - 1], "repeat at %d" % i)
	for id in ["laugh_1", "laugh_2", "laugh_3", "laugh_4", "laugh_5", "laugh_6", "ooh", "giggle_1", "giggle_2",
			"giggle_3", "giggle_4", "giggle_5"]:
		check(seen.has(id), "picked %s" % id)
	check_eq(seen.size(), 12, "only laughs, ooh and giggles")
	_done()


func test_quiet_while_the_child_talks_or_is_echoed() -> void:
	_make()
	_tb.state = TalkBack.LISTEN
	_voice.say(&"giggle_1")
	_tb.state = TalkBack.TALK
	_voice.say(&"giggle_1")
	_tb.state = TalkBack.CELEBRATE
	_voice.say(&"giggle_1")
	check(_tb.played.is_empty(), "no line over the child")
	_tb.state = TalkBack.CANT_TALK
	_voice.say(&"giggle_1")
	_tb.state = TalkBack.TALK
	_voice.say(&"giggle_2")
	check_eq(_tb.played, ["giggle_1", "giggle_2"] as Array[String], "own line cut by the next touch")
	_voice._on_talk_state(TalkBack.LISTEN)
	_voice.say(&"giggle_3")
	check_eq(_tb.played.size(), 2, "child spoke: the pet waits again")
	_done()


func test_lines_chain_after_each_other() -> void:
	_make()
	_tb.state = TalkBack.READY_TO_LISTEN
	_voice.say(&"laugh*+hooray")
	check_eq(_tb.played.size(), 1, "first line only")
	check(_tb.played[0].begins_with("laugh_"), "a laugh first")
	_tb.state = TalkBack.CELEBRATE
	_voice._play_next()
	check_eq(_tb.played.size(), 2, "then the next")
	check_eq(_tb.played[-1], "hooray", "hooray")
	_voice.say(&"laugh*+hooray")
	_voice._on_talk_state(TalkBack.LISTEN)
	_voice._play_next()
	check_eq(_tb.played.size(), 3, "the child talking drops the rest")
	_done()
