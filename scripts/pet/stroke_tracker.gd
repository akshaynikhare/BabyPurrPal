class_name StrokeTracker
extends RefCounted
## Follows one finger from press to release and settles what it was: a tap, a
## drag (a swipe, or a late tap, on release) or a stroke. A stroke never turns
## back into a tap or a swipe. Positions in base-unit pixels, times in msec.

enum Phase { NONE, PENDING, TAP, DRAG, STROKE }

var phase := Phase.NONE
var start := Vector2.ZERO
var start_msec := 0
var started_on_pet := false
## Where the finger is now, and whether that is over the pet.
var position := Vector2.ZERO
var over_pet := false
var _moved := 0.0
var _path := 0.0


## Presses off the pet are taps straight away, so background chimes stay instant.
func begin(pos: Vector2, msec: int, on_pet: bool) -> Phase:
	start = pos
	position = pos
	start_msec = msec
	started_on_pet = on_pet
	over_pet = on_pet
	_moved = 0.0
	_path = 0.0
	phase = Phase.PENDING if on_pet else Phase.TAP
	return phase


func move(pos: Vector2, msec: int, on_pet: bool) -> Phase:
	_path += position.distance_to(pos)
	position = pos
	over_pet = on_pet
	_moved = maxf(_moved, start.distance_to(pos))
	if phase == Phase.PENDING and _moved > PetGestures.TAP_SLOP:
		phase = Phase.DRAG
	return update(msec)


## Call every frame while the finger is down: a still finger becomes a tap, and
## a drag that is slow enough over the pet becomes a stroke.
func update(msec: int) -> Phase:
	var held := msec - start_msec
	if phase == Phase.PENDING and PetGestures.is_tap(_moved, held, false):
		phase = Phase.TAP
	elif phase == Phase.DRAG and PetGestures.is_stroke(held, _moved, _path, over_pet):
		phase = Phase.STROKE
	return phase


## The phase the finger ended in. PENDING means a quick tap that has not fired yet.
func end() -> Phase:
	var last := phase
	phase = Phase.NONE
	return last


## Whether a finger that ended in `last` may still be a swipe: a drag, or a
## background tap (those fire on press). Never a stroke or a held tap on the pet.
func may_swipe(last: Phase) -> bool:
	return last == Phase.DRAG or (last == Phase.TAP and not started_on_pet)


## Drops the finger without a result (second finger, app paused).
func cancel() -> void:
	phase = Phase.NONE
