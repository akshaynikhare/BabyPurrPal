class_name RoundButton
extends Control
## Round button with a squishy press. Its face is blitted from UiAtlas; it redraws only when icon or colour change.

signal pressed

const DISABLED_ALPHA := 0.55

@export var icon_id: StringName = &""
@export var fill: Color = UiStyle.CREAM
## Toys fire on touch-down so a toddler's quick, sloppy tap still counts.
@export var trigger_on_press := false

var disabled := false
var _tween: Tween
var _tap := TapFilter.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	material = UiAtlas.material()
	add_to_group(UiAtlas.USERS)
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = custom_minimum_size.max(Vector2.ONE * UiStyle.TOUCH_MIN)
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	EventBus.app_paused.connect(cancel_press)
	EventBus.app_resumed.connect(cancel_press)


func set_icon(id: StringName) -> void:
	if id == icon_id:
		return
	icon_id = id
	queue_redraw()


func set_fill(color: Color) -> void:
	fill = color
	queue_redraw()


## Dims the button and ignores presses; a press in progress springs back without firing.
func set_disabled(on: bool) -> void:
	disabled = on
	modulate.a = DISABLED_ALPHA if on else 1.0
	if on and _tap.is_down():
		_tap.reset()
		squish()
		_tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	var kind := _tap.feed(event)
	if kind == TapFilter.Kind.NONE:
		return
	accept_event()
	if kind == TapFilter.Kind.PRESS:
		_on_down()
	else:
		_on_up(Rect2(Vector2.ZERO, size).has_point(TapFilter.position_of(event)))


## Drops a press in progress without firing anything (the release may never arrive).
func cancel_press() -> void:
	if _tap.is_down():
		_tap.reset()
		release_squish()


func _on_down() -> void:
	squish()
	if trigger_on_press:
		pressed.emit()


func _on_up(inside: bool) -> void:
	release_squish()
	if inside and not trigger_on_press:
		pressed.emit()


func squish() -> void:
	_restart_tween().tween_property(self, "scale", Vector2(1.1, 0.88), 0.07).set_ease(Tween.EASE_OUT)


func release_squish() -> void:
	_restart_tween().tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func wobble() -> void:
	var t := _restart_tween()
	for angle in [-12.0, 10.0, -6.0, 3.0, 0.0]:
		t.tween_property(self, "rotation_degrees", angle, 0.07)
	t.parallel().tween_property(self, "scale", Vector2.ONE, 0.1)


func _restart_tween() -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	return _tween


func _draw() -> void:
	UiAtlas.draw_region(self, UiAtlas.face_key(icon_id, fill), Rect2(Vector2.ZERO, size))
