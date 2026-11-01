extends Node
## Persists parent settings in user://settings.cfg.

const PATH := "user://settings.cfg"
const SECTION := "settings"
## Talk-back treats lullaby_on or music_on as "music playing" for its detector.
const DEFAULTS := {
	&"lullaby_on": false,
	&"voice_pitch": 1.45,
	&"talkback_on": true,
	&"music_on": false,
	&"ambience_on": true,
	&"quiet_mode": false,
}

var _config := ConfigFile.new()


func _ready() -> void:
	_config.load(PATH)


func get_value(key: StringName) -> Variant:
	return _config.get_value(SECTION, key, DEFAULTS.get(key))


func set_value(key: StringName, value: Variant) -> void:
	_config.set_value(SECTION, key, value)
	_config.save(PATH)
	EventBus.settings_changed.emit(key, value)
