extends TestCase


func test_swipe_left_is_next() -> void:
	check_eq(PetGestures.classify_swipe(Vector2(-120, 10), 300), PetGestures.Swipe.NEXT, "left swipe")


func test_swipe_right_is_previous() -> void:
	check_eq(PetGestures.classify_swipe(Vector2(120, -10), 300), PetGestures.Swipe.PREVIOUS, "right swipe")


func test_short_move_is_not_a_swipe() -> void:
	check_eq(PetGestures.classify_swipe(Vector2(45, 0), 100), PetGestures.Swipe.NONE, "exactly 45 px")
	check_eq(PetGestures.classify_swipe(Vector2(46, 0), 100), PetGestures.Swipe.PREVIOUS, "just over 45 px")


func test_mostly_vertical_is_not_a_swipe() -> void:
	check_eq(PetGestures.classify_swipe(Vector2(100, 90), 200), PetGestures.Swipe.NONE, "dx < dy * 1.2")
	check_eq(PetGestures.classify_swipe(Vector2(-100, 80), 200), PetGestures.Swipe.NEXT, "dx > dy * 1.2")


func test_slow_drag_is_not_a_swipe() -> void:
	check_eq(PetGestures.classify_swipe(Vector2(-300, 0), 800), PetGestures.Swipe.NONE, "800 ms")
	check_eq(PetGestures.classify_swipe(Vector2(-300, 0), 799), PetGestures.Swipe.NEXT, "799 ms")


func test_pinch_thresholds() -> void:
	check_eq(PetGestures.classify_pinch(1.23), PetGestures.Pinch.ZOOM_IN, "spread")
	check_eq(PetGestures.classify_pinch(1.22), PetGestures.Pinch.NONE, "at in threshold")
	check_eq(PetGestures.classify_pinch(1.0), PetGestures.Pinch.NONE, "unchanged")
	check_eq(PetGestures.classify_pinch(0.82), PetGestures.Pinch.NONE, "at out threshold")
	check_eq(PetGestures.classify_pinch(0.8), PetGestures.Pinch.ZOOM_OUT, "pinch")


func test_tap_on_release_within_slop() -> void:
	check(PetGestures.is_tap(0.0, 30, true), "quick still tap")
	check(PetGestures.is_tap(24.0, 30, true), "at slop")
	check(not PetGestures.is_tap(25.0, 30, true), "past slop")


func test_held_tap_needs_a_still_finger() -> void:
	check(not PetGestures.is_tap(0.0, 139, false), "too early")
	check(PetGestures.is_tap(10.0, 140, false), "still at 140 ms")
	check(not PetGestures.is_tap(11.0, 140, false), "creeping at 140 ms")
	check(not PetGestures.is_tap(20.0, 249, false), "creeping at 249 ms")
	check(PetGestures.is_tap(20.0, 250, false), "crept, still within slop at 250 ms")


func test_stroke_is_slow_long_and_over_the_pet() -> void:
	check(PetGestures.is_stroke(250, 60.0, 100.0, true), "400 px/s for 250 ms")
	check(not PetGestures.is_stroke(249, 60.0, 100.0, true), "too short")
	check(not PetGestures.is_stroke(400, 60.0, 100.0, false), "off the pet")
	check(not PetGestures.is_stroke(400, 24.0, 100.0, true), "never left the tap slop")
	check(PetGestures.is_stroke(400, 60.0, 180.0, true), "450 px/s")
	check(not PetGestures.is_stroke(400, 60.0, 181.0, true), "faster than 450 px/s")


func test_a_quick_swipe_is_never_a_stroke() -> void:
	# The fastest swipe the swipe rule takes is under 800 ms; any of them over 450 px/s stays a swipe.
	check(not PetGestures.is_stroke(300, 200.0, 200.0, true), "200 px in 300 ms")
	check(PetGestures.classify_swipe(Vector2(-200, 0), 300) == PetGestures.Swipe.NEXT, "and it is a swipe")
