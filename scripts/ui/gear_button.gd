class_name GearButton
extends RoundButton
## Parent gate: hold to fill the ring while a tone rises. Too-short taps wobble and
## chime; a full hold unlocks and opens settings.

signal gate_opened

const RING_COLOR := Color("FF8FA3")
## Rises over HoldGate.HOLD_SEC.
const HOLD_SFX := &"ui_hold"

var _gate := HoldGate.new()


func _ready() -> void:
	icon_id = &"gear"
	fill = UiStyle.PINK
	super()
	set_process(false)


func _on_down() -> void:
	_gate.begin()
	_restart_tween().tween_property(self, "scale", Vector2(0.94, 0.94), 0.1)
	set_process(true)
	AudioDirector.start_sfx(HOLD_SFX)


func _on_up(_inside: bool) -> void:
	_finish_hold()


func _process(delta: float) -> void:
	if _gate.advance(delta):
		set_process(false)
		queue_redraw()
		release_squish()
		AudioDirector.stop_sfx(HOLD_SFX)
		AudioDirector.play_sfx(&"ui_unlock")
		Haptics.play(&"twinkle")
		_gate.release()
		gate_opened.emit()
		return
	queue_redraw()


func _finish_hold() -> void:
	set_process(false)
	AudioDirector.stop_sfx(HOLD_SFX)
	if _gate.release():
		AudioDirector.play_sfx(&"chime_4")
		Haptics.play(&"tap")
		wobble()
	else:
		release_squish()
	queue_redraw()


## A hold interrupted by a pause or a hidden button must never complete later on its own.
func cancel_press() -> void:
	_tap.reset()
	if _gate.holding:
		_gate.release()
		AudioDirector.stop_sfx(HOLD_SFX)
		set_process(false)
		release_squish()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		cancel_press()


func _draw() -> void:
	super()
	if not _gate.holding:
		return
	var r := minf(size.x, size.y) * 0.5 - UiStyle.SHADOW_OFFSET - 2.0
	var sweep := TAU * _gate.progress()
	draw_arc(size * 0.5, r - 1.0, -PI * 0.5, -PI * 0.5 + sweep, 48, RING_COLOR, 9.0, true)
