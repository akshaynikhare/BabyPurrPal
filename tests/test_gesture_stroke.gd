extends TestCase

const P := StrokeTracker.Phase


## Drags along x at `speed` px/s from msec 0, one sample every 16 ms, then returns the tracker.
func _drag(on_pet: bool, speed: float, until_ms: int, over_pet := true) -> StrokeTracker:
	var tracker := StrokeTracker.new()
	tracker.begin(Vector2(300, 800), 0, on_pet)
	for t in range(16, until_ms + 1, 16):
		tracker.move(Vector2(300 + speed * t / 1000.0, 800), t, over_pet)
	return tracker


func test_background_press_is_a_tap_at_once() -> void:
	var tracker := StrokeTracker.new()
	check_eq(tracker.begin(Vector2(100, 200), 0, false), P.TAP, "background")
	check(tracker.may_swipe(tracker.end()), "a background tap can still swipe")


func test_quick_tap_on_the_pet_waits_for_release() -> void:
	var tracker := StrokeTracker.new()
	check_eq(tracker.begin(Vector2(300, 800), 0, true), P.PENDING, "on press")
	check_eq(tracker.update(100), P.PENDING, "still pending at 100 ms")
	tracker.move(Vector2(305, 803), 110, true)
	check_eq(tracker.end(), P.PENDING, "released pending: the stage fires the tap")
	check_eq(tracker.phase, P.NONE, "reset after end")


func test_held_still_press_taps_and_never_swipes() -> void:
	var tracker := StrokeTracker.new()
	tracker.begin(Vector2(300, 800), 0, true)
	check_eq(tracker.update(140), P.TAP, "held 140 ms")
	tracker.move(Vector2(150, 800), 300, true)
	check_eq(tracker.phase, P.TAP, "a tap stays a tap")
	check(not tracker.may_swipe(tracker.end()), "a held tap on the pet is not a swipe")


func test_slow_drag_over_the_pet_becomes_a_stroke() -> void:
	var tracker := _drag(true, 150.0, 240)
	check_eq(tracker.phase, P.DRAG, "dragging before 250 ms")
	check_eq(tracker.update(256), P.STROKE, "stroke at 250 ms")
	tracker.move(Vector2(330, 800), 400, true)
	check_eq(tracker.phase, P.STROKE, "stays a stroke")
	var last := tracker.end()
	check_eq(last, P.STROKE, "ends a stroke")
	check(not tracker.may_swipe(last), "a stroke is never a swipe")


func test_slow_start_is_not_taken_for_a_tap() -> void:
	# 100 px/s: past TAP_STILL at 140 ms, past the slop before 250 ms.
	var tracker := _drag(true, 100.0, 400)
	check_eq(tracker.phase, P.STROKE, "slow creep ends up petting")


func test_fast_drag_is_a_swipe_not_a_stroke() -> void:
	var tracker := _drag(true, 1200.0, 400)
	check_eq(tracker.phase, P.DRAG, "too fast to pet")
	var last := tracker.end()
	check(tracker.may_swipe(last), "swipe check on release")
	check_eq(PetGestures.classify_swipe(Vector2(1200.0 * 0.4, 0), 400), PetGestures.Swipe.PREVIOUS, "and it swipes")


func test_drag_that_stops_on_the_pet_becomes_a_stroke() -> void:
	var tracker := _drag(true, 1200.0, 160)
	check_eq(tracker.update(300), P.DRAG, "average still too fast")
	check_eq(tracker.update(500), P.STROKE, "slowed below 450 px/s on average")


func test_drag_off_the_pet_is_never_a_stroke() -> void:
	var tracker := _drag(true, 150.0, 600, false)
	check_eq(tracker.phase, P.DRAG, "off the pet")


func test_press_off_the_pet_never_strokes() -> void:
	var tracker := _drag(false, 150.0, 600)
	check_eq(tracker.phase, P.TAP, "started on the background")


func test_cancel_drops_the_finger() -> void:
	var tracker := _drag(true, 150.0, 300)
	tracker.cancel()
	check_eq(tracker.phase, P.NONE, "cancelled")
	check_eq(tracker.update(400), P.NONE, "no late tap or stroke")
