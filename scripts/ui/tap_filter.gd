class_name TapFilter
extends RefCounted
## Turns raw pointer events into one press/release pair per finger. Touch (any index) and the
## emulated mouse event that mirrors touch 0 describe the same press, so the duplicate is dropped.

enum Kind { NONE, PRESS, RELEASE }

const NO_POINTER := -1

var _pointer := NO_POINTER


func feed(event: InputEvent) -> Kind:
	var pointer := NO_POINTER
	var down := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return Kind.NONE
		pointer = 0
		down = mb.pressed
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		pointer = st.index
		down = st.pressed
	else:
		return Kind.NONE
	if down:
		if _pointer != NO_POINTER:
			return Kind.NONE
		_pointer = pointer
		return Kind.PRESS
	if pointer != _pointer:
		return Kind.NONE
	_pointer = NO_POINTER
	return Kind.RELEASE


func is_down() -> bool:
	return _pointer != NO_POINTER


## Forget a press whose release will never arrive (app paused, node hidden).
func reset() -> void:
	_pointer = NO_POINTER


static func position_of(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2.ZERO
