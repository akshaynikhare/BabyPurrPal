class_name TickleCounter
extends RefCounted
## Belly taps close together build up: giggle, giggle, laugh, laugh, tumble,
## then it starts over.

enum Level { GIGGLE, LAUGH, TUMBLE }

const WINDOW_MS := 1500
const LAUGH_AT := 3
const TUMBLE_AT := 5

var count := 0
var _last_msec := 0


func tap(msec: int) -> Level:
	if count > 0 and msec - _last_msec > WINDOW_MS:
		count = 0
	count += 1
	_last_msec = msec
	if count >= TUMBLE_AT:
		count = 0
		return Level.TUMBLE
	return Level.LAUGH if count >= LAUGH_AT else Level.GIGGLE


func reset() -> void:
	count = 0
