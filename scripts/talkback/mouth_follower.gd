class_name MouthFollower
extends RefCounted
## Turns a playback envelope value (0..1) into a jaw opening (0..1).
## Two thresholds stop the mouth flickering; smoothing and a response curve
## make it read as talking rather than buzzing.

## Envelope must rise above this to open a closed mouth.
var open_threshold := 0.2
## And fall below this to close an open one.
var close_threshold := 0.1
## Fraction of the gap closed per 1/60 s when opening (snappy) and closing (softer).
var attack := 0.6
var release := 0.3
## < 1 widens small openings so quiet syllables still show.
var response_exponent := 0.6
var max_open := 1.0

var value := 0.0
var is_open := false


func reset() -> void:
	value = 0.0
	is_open = false


func update(envelope: float, delta: float) -> float:
	if is_open and envelope < close_threshold:
		is_open = false
	elif not is_open and envelope > open_threshold:
		is_open = true
	var target := 0.0
	if is_open:
		var t := clampf((envelope - close_threshold) / (1.0 - close_threshold), 0.0, 1.0)
		target = pow(t, response_exponent) * max_open
	var rate := attack if target > value else release
	var alpha := 1.0 - pow(1.0 - rate, delta * 60.0)
	value += (target - value) * alpha
	return value
