extends TestCase
## Settings keys and their first-run values. Talk-back reads lullaby_on and
## music_on by these exact names.


func test_defaults() -> void:
	var d := Settings.DEFAULTS
	check_eq(d[&"lullaby_on"], false, "lullaby off")
	check_eq(d[&"music_on"], false, "day music off")
	check_eq(d[&"ambience_on"], true, "room sounds on")
	check_eq(d[&"quiet_mode"], false, "full volume")
	check_eq(d[&"talkback_on"], true, "talking pet on")
	check_near(d[&"voice_pitch"], 1.45, 0.0001, "voice pitch")


func test_unsaved_keys_read_their_default() -> void:
	var settings: Node = load("res://autoload/settings.gd").new()
	for key: StringName in Settings.DEFAULTS:
		check_eq(settings.get_value(key), Settings.DEFAULTS[key], String(key))
	settings.free()
