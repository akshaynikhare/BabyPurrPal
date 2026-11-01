class_name TimeOfDay
extends RefCounted
## Clock hour → room phase, the manual cycle order, and each phase's sounds.

const SUNRISE := &"sunrise"
const DAY := &"day"
const SUNSET := &"sunset"
const NIGHT := &"night"
const ORDER: Array[StringName] = [SUNRISE, DAY, SUNSET, NIGHT]
## The room's ambience loop per phase.
const AMBIENCE := {SUNRISE: &"amb_morning", DAY: &"amb_day", SUNSET: &"amb_evening", NIGHT: &"amb_night"}
## The chime when the room turns to a phase (clock or sun button); the others have none.
const CHIMES := {SUNRISE: &"sunrise", NIGHT: &"nightfall"}


static func ambience_for(phase: StringName) -> StringName:
	return AMBIENCE.get(phase, AMBIENCE[DAY])


static func phase_for_hour(hour: int) -> StringName:
	if hour >= 5 and hour < 9:
		return SUNRISE
	if hour >= 9 and hour < 17:
		return DAY
	if hour >= 17 and hour < 20:
		return SUNSET
	return NIGHT


static func next_phase(phase: StringName) -> StringName:
	var i := ORDER.find(phase)
	return ORDER[(i + 1) % ORDER.size()]


static func current_phase() -> StringName:
	return phase_for_hour(int(Time.get_datetime_dict_from_system().hour))
