extends Node
## Plays vibration patterns as timed pulses: [on_ms, off_ms, on_ms, ...].
## Needs the VIBRATE permission in the Android export preset.

const PATTERNS := {
	&"tap": [8],
	&"tickle": [14, 30, 14, 30, 18],
	&"purr": [24, 40, 24, 40, 24],
	&"paw": [22],
	&"twinkle": [10, 25, 10],
	&"bounce": [16, 32, 16],
	&"feed": [20, 40, 28],
	&"step": [10],
}

var enabled := true
var _sequence := 0


## mute_mic: false for a buzz that repeats while the child plays (petting), so
## talk-back can still hear them.
func play(pattern: StringName, mute_mic := true) -> void:
	if not enabled or not PATTERNS.has(pattern):
		return
	_sequence += 1
	var sequence := _sequence
	var steps: Array = PATTERNS[pattern]
	# Vibration buzz travels through the phone body into the mic.
	if mute_mic:
		var total_ms := 0
		for step in steps:
			total_ms += int(step)
		AudioDirector.mark_busy(total_ms / 1000.0, 100)
	for i in steps.size():
		if sequence != _sequence:
			return
		if i % 2 == 0:
			Input.vibrate_handheld(int(steps[i]))
		# Nothing follows the last pulse, so there is nothing to wait for.
		if i + 1 < steps.size():
			await get_tree().create_timer(steps[i] / 1000.0, true, false, true).timeout
