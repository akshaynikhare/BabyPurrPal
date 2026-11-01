class_name PetIdle
extends RefCounted
## Quiet-time schedule: an idle break every 5–10 s, a "come play" call after 20 s
## without a touch (then every 30 s), and nose twitches every 3–6 s.

enum Event { NONE, BREAK, COME_PLAY }

const BREAK_MIN_SEC := 5.0
const BREAK_MAX_SEC := 10.0
const COME_PLAY_SEC := 20.0
const COME_PLAY_REPEAT_SEC := 30.0
const NOSE_MIN_SEC := 3.0
const NOSE_MAX_SEC := 6.0

var _rng := RandomNumberGenerator.new()
var _break_left := 0.0
var _quiet := 0.0
var _call_at := COME_PLAY_SEC
var _nose_left := 0.0


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	delay_break()
	_nose_left = _rng.randf_range(NOSE_MIN_SEC, NOSE_MAX_SEC)


## A touch, or the child talking, restarts the quiet clock.
func touched() -> void:
	_quiet = 0.0
	_call_at = COME_PLAY_SEC


## Something just played; the next idle break waits a full gap.
func delay_break() -> void:
	_break_left = _rng.randf_range(BREAK_MIN_SEC, BREAK_MAX_SEC)


## free: not reacting, walking, listening or talking. Due events wait for it.
func update(delta: float, free: bool) -> Event:
	_quiet += delta
	if not free:
		return Event.NONE
	if _quiet >= _call_at:
		_call_at = _quiet + COME_PLAY_REPEAT_SEC
		delay_break()
		return Event.COME_PLAY
	_break_left -= delta
	if _break_left <= 0.0:
		delay_break()
		return Event.BREAK
	return Event.NONE


## How many quick twitches to start now (2 or 3), or 0.
func nose(delta: float) -> int:
	_nose_left -= delta
	if _nose_left > 0.0:
		return 0
	_nose_left = _rng.randf_range(NOSE_MIN_SEC, NOSE_MAX_SEC)
	return _rng.randi_range(2, 3)
