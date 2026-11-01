extends TestCase

const PRESS := TapFilter.Kind.PRESS
const RELEASE := TapFilter.Kind.RELEASE
const NONE := TapFilter.Kind.NONE


func _touch(index: int, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	return e


func _mouse(pressed: bool, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func test_touch_then_emulated_mouse_is_one_press() -> void:
	var f := TapFilter.new()
	check_eq(f.feed(_touch(0, true)), PRESS, "touch press")
	check_eq(f.feed(_mouse(true)), NONE, "emulated mouse press dropped")
	check_eq(f.feed(_touch(0, false)), RELEASE, "touch release")
	check_eq(f.feed(_mouse(false)), NONE, "emulated mouse release dropped")
	check(not f.is_down(), "idle afterwards")


func test_mouse_then_emulated_touch_is_one_press() -> void:
	var f := TapFilter.new()
	check_eq(f.feed(_mouse(true)), PRESS, "mouse press")
	check_eq(f.feed(_touch(0, true)), NONE, "emulated touch press dropped")
	check_eq(f.feed(_mouse(false)), RELEASE, "mouse release")
	check_eq(f.feed(_touch(0, false)), NONE, "emulated touch release dropped")


func test_any_touch_index_presses() -> void:
	var f := TapFilter.new()
	check_eq(f.feed(_touch(3, true)), PRESS, "palm on the stage, finger 3 on a toy")
	check_eq(f.feed(_touch(1, true)), NONE, "second finger ignored while pressed")
	check_eq(f.feed(_touch(1, false)), NONE, "other finger's release ignored")
	check_eq(f.feed(_touch(3, false)), RELEASE, "tracked finger releases")


func test_other_buttons_and_events_ignored() -> void:
	var f := TapFilter.new()
	check_eq(f.feed(_mouse(true, MOUSE_BUTTON_RIGHT)), NONE, "right button")
	check_eq(f.feed(InputEventKey.new()), NONE, "key")
	check_eq(f.feed(_touch(0, false)), NONE, "stray release")


func test_reset_forgets_lost_release() -> void:
	var f := TapFilter.new()
	f.feed(_touch(0, true))
	f.reset()
	check_eq(f.feed(_touch(0, true)), PRESS, "new press works after a pause")
