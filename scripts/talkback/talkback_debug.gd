extends Control
## On-device tuning screen for talk-back: state, live input meter with the
## detector's thresholds, clip/latency readout, pitch control and a stand-in face.

const DB_MIN := -70.0
const STATE_COLORS := {
	&"NOT_READY": Color("#8a8a8a"),
	&"READY_TO_LISTEN": Color("#3f9a52"),
	&"LISTEN": Color("#e09a1a"),
	&"TALK": Color("#2f7fd8"),
	&"CELEBRATE": Color("#d84f9a"),
	&"DONT_HEAR": Color("#c8432f"),
	&"CANT_TALK": Color("#6b6b6b"),
}
const INK := Color("#7a5233")
const FUR := Color("#f6c58f")

var _talkback: TalkBack
var _state_label: Label
var _info_label: Label
var _lifecycle_label: Label
var _app_paused := 0
var _app_resumed := 0
var _focus_out := 0
var _os_paused := 0
var _clip_label: Label
var _pitch_label: Label
var _slider: HSlider
var _toggle: Button
var _meter: Control
var _face: Control
var _jaw := 0.0
var _info_timer := 0.0


func _ready() -> void:
	var theme_ := Theme.new()
	theme_.default_font_size = 34
	theme = theme_

	var bg := ColorRect.new()
	bg.color = Color("#fff6e8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	_state_label = _label(72)
	box.add_child(_state_label)

	_face = Control.new()
	_face.custom_minimum_size = Vector2(0, 460)
	_face.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_face.draw.connect(_draw_face)
	box.add_child(_face)

	_meter = Control.new()
	_meter.custom_minimum_size = Vector2(0, 110)
	_meter.draw.connect(_draw_meter)
	box.add_child(_meter)

	_lifecycle_label = _label(36)
	box.add_child(_lifecycle_label)
	_info_label = _label(26)
	box.add_child(_info_label)
	_clip_label = _label(32)
	box.add_child(_clip_label)

	var pitch_row := HBoxContainer.new()
	pitch_row.add_theme_constant_override("separation", 16)
	pitch_row.add_child(_button("−", 140, func() -> void: _slider.value -= _slider.step))
	_pitch_label = _label(40)
	_pitch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch_row.add_child(_pitch_label)
	pitch_row.add_child(_button("+", 140, func() -> void: _slider.value += _slider.step))
	box.add_child(pitch_row)

	_slider = HSlider.new()
	_slider.min_value = TalkBack.PITCH_MIN
	_slider.max_value = TalkBack.PITCH_MAX
	_slider.step = 0.05
	_slider.custom_minimum_size = Vector2(0, 90)
	_slider.value = float(Settings.get_value(&"voice_pitch"))
	_slider.value_changed.connect(func(v: float) -> void: Settings.set_value(&"voice_pitch", v))
	box.add_child(_slider)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var test := _button("Test Voice", 150, func() -> void: EventBus.test_voice_requested.emit())
	test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(test)
	_toggle = _button("", 150, func() -> void: Settings.set_value(&"talkback_on", not Settings.get_value(&"talkback_on")))
	_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_toggle)
	box.add_child(buttons)
	box.add_child(_button("Restart mic", 120, func() -> void: _talkback.start()))

	EventBus.app_paused.connect(func() -> void:
		_app_paused += 1
		_refresh_lifecycle())
	EventBus.app_resumed.connect(func() -> void:
		_app_resumed += 1
		_refresh_lifecycle())
	EventBus.talkback_state_changed.connect(_on_state)
	EventBus.mouth_amplitude_changed.connect(func(v: float) -> void:
		_jaw = v
		_face.queue_redraw())
	EventBus.settings_changed.connect(func(_k: StringName, _v: Variant) -> void: _refresh_settings())

	_talkback = TalkBack.new()
	add_child(_talkback)
	_on_state(_talkback.state)
	_refresh_settings()
	_refresh_lifecycle()
	_talkback.start()


# Raw OS notifications, so a missing EventBus count points at Lifecycle.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focus_out += 1
		NOTIFICATION_APPLICATION_PAUSED:
			_os_paused += 1
		_:
			return
	if _lifecycle_label:
		_refresh_lifecycle()


func _refresh_lifecycle() -> void:
	_lifecycle_label.text = "app_paused %d · app_resumed %d\nOS focus_out %d · OS paused %d" % [
		_app_paused, _app_resumed, _focus_out, _os_paused]


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, height: int, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(height, height)
	button.add_theme_font_size_override("font_size", 44)
	button.pressed.connect(action)
	return button


func _process(delta: float) -> void:
	_meter.queue_redraw()
	_info_timer -= delta
	if _info_timer > 0.0:
		return
	_info_timer = 0.1
	var det := _talkback.detector
	var mic := "off"
	if _talkback.is_mic_running():
		mic = "LIVE" if _talkback.is_mic_live() else ("opening" if _talkback.is_mic_opening() else "NO SIGNAL")
	_info_label.text = "mic %s · %d fr/s · restarts %d · perm %s · %d Hz\nlevel %.0f dB · floor %.0f · start %.0f · stop %.0f%s" % [
		mic,
		_talkback.capture_fps,
		_talkback.mic_restarts,
		TalkBack.Permission.keys()[_talkback.permission],
		det.sample_rate(),
		_db(det.level), _db(det.noise_floor), _db(det.start_threshold()), _db(det.stop_threshold()),
		"\npitch %.2f" % _talkback.current_pitch if _talkback.state == TalkBack.TALK else "",
	]
	_clip_label.text = "Last clip %.2f s · speech end → play %.0f ms (processing %.1f ms)" % [
		_talkback.last_clip_sec, _talkback.last_latency_ms, _talkback.last_processing_ms]


func _on_state(state: StringName) -> void:
	_state_label.text = String(state)
	_state_label.add_theme_color_override("font_color", STATE_COLORS.get(state, Color.BLACK))
	_face.queue_redraw()


func _refresh_settings() -> void:
	var pitch := float(Settings.get_value(&"voice_pitch"))
	_pitch_label.text = "Pitch %.2f×" % pitch
	_slider.set_value_no_signal(pitch)
	_toggle.text = "Talk-back ON" if Settings.get_value(&"talkback_on") else "Talk-back OFF"


func _db(linear: float) -> float:
	return maxf(linear_to_db(maxf(linear, 0.00001)), DB_MIN)


func _meter_x(linear: float) -> float:
	return (_db(linear) - DB_MIN) / -DB_MIN * _meter.size.x


func _draw_meter() -> void:
	var s := _meter.size
	var det := _talkback.detector
	_meter.draw_rect(Rect2(Vector2.ZERO, s), Color("#efe2cf"))
	var bar := Color("#e09a1a") if det.is_recording() else Color("#3f9a52")
	_meter.draw_rect(Rect2(0, 20, _meter_x(det.level), s.y - 40), bar)
	_marker(_meter_x(det.noise_floor), Color("#555555"))
	_marker(_meter_x(det.stop_threshold()), Color("#e07a1a"))
	_marker(_meter_x(det.start_threshold()), Color("#c8432f"))
	_meter.draw_rect(Rect2(Vector2.ZERO, s), INK, false, 3.0)


func _marker(x: float, color: Color) -> void:
	_meter.draw_line(Vector2(x, 0), Vector2(x, _meter.size.y), color, 6.0)


func _draw_face() -> void:
	var c := _face.size * 0.5
	var r := minf(_face.size.x, _face.size.y) * 0.36
	var state := _talkback.state if _talkback else TalkBack.NOT_READY
	var ear_lift := 1.25 if state == TalkBack.LISTEN else (0.6 if state == TalkBack.DONT_HEAR else 1.0)
	for side in [-1.0, 1.0]:
		var base := c + Vector2(side * r * 0.62, -r * 0.62)
		var ear := PackedVector2Array([
			base + Vector2(-side * r * 0.32, r * 0.1),
			base + Vector2(side * r * 0.35, r * 0.15),
			base + Vector2(side * r * 0.12, -r * 0.7 * ear_lift),
		])
		_face.draw_colored_polygon(ear, FUR)
		_face.draw_polyline(ear + PackedVector2Array([ear[0]]), INK, 5.0)
	_face.draw_circle(c, r, FUR)
	_face.draw_circle(c, r, INK, false, 6.0)
	for side in [-1.0, 1.0]:
		_face.draw_circle(c + Vector2(side * r * 0.38, -r * 0.15), r * 0.11, INK)
	var mouth_w := r * 0.32
	var mouth_h := lerpf(0.08, 0.9, _jaw) * mouth_w
	var mouth_c := c + Vector2(0, r * 0.42)
	_face.draw_set_transform(mouth_c, 0.0, Vector2(1.0, mouth_h / mouth_w))
	_face.draw_circle(Vector2.ZERO, mouth_w, Color("#8a3b3b"))
	_face.draw_set_transform(Vector2.ZERO)
