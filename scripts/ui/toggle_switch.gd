class_name ToggleSwitch
extends Control
## Big pill switch (the whole 96 px-tall control is the touch target).

signal toggled(on: bool)

const TRACK := Vector2(112, 60)

var on := false
var _knob := 0.0
var _tween: Tween
var _track := UiStyle.box(Color("F0DEC4"), 30, 5, false)


func _ready() -> void:
	custom_minimum_size = Vector2(136, UiStyle.TOUCH_MIN)
	mouse_filter = Control.MOUSE_FILTER_STOP
	material = UiAtlas.material()
	add_to_group(UiAtlas.USERS)
	focus_mode = Control.FOCUS_NONE


func set_on(value: bool, animate := true) -> void:
	if value == on and _knob == (1.0 if on else 0.0):
		return
	on = value
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_knob, _knob, 1.0 if on else 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_set_knob(1.0 if on else 0.0)


func _set_knob(value: float) -> void:
	_knob = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		accept_event()
		set_on(not on)
		Haptics.play(&"tap")
		toggled.emit(on)


func _draw() -> void:
	var rect := Rect2((size - TRACK) * 0.5, TRACK)
	_track.bg_color = Color("F0DEC4").lerp(Color("8FD9A8"), clampf(_knob, 0.0, 1.0))
	draw_style_box(_track, rect)
	var x := lerpf(rect.position.x + TRACK.y * 0.5, rect.end.x - TRACK.y * 0.5, _knob)
	var knob := Vector2.ONE * UiAtlas.KNOB
	UiAtlas.draw_region(self, &"knob", Rect2(Vector2(x, rect.get_center().y) - knob * 0.5, knob))
