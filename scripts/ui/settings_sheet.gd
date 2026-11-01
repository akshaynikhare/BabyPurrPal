class_name SettingsSheet
extends Control
## "Sound Settings" bottom sheet. The backdrop swallows touches so the stage behind never reacts.

const SLIDE_SEC := 0.35

var bottom_inset := 0.0

var _backdrop: ColorRect
var _sheet: PanelContainer
var _lullaby: ToggleSwitch
var _talk: ToggleSwitch
var _pitch: HSlider
var _pitch_value: Label
var _syncing := false
var _tween: Tween
var _open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.37, 0.23, 0.12, 0.45)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	_build_sheet()
	EventBus.settings_changed.connect(func(_k: StringName, _v: Variant) -> void: _sync())


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	_sync()
	visible = true
	_backdrop.modulate.a = 0.0
	_sheet.offset_bottom = -bottom_inset - 12.0
	var height := _sheet.get_combined_minimum_size().y
	_sheet.offset_top = -height - bottom_inset - 12.0
	var hidden_shift := height + bottom_inset + 40.0
	_sheet.position.y += hidden_shift
	var target := _sheet.position.y - hidden_shift
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_backdrop, "modulate:a", 1.0, SLIDE_SEC)
	_tween.tween_property(_sheet, "position:y", target, SLIDE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	EventBus.settings_opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_backdrop, "modulate:a", 0.0, 0.25)
	_tween.tween_property(_sheet, "position:y", _sheet.position.y + _sheet.size.y + 60.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)
	EventBus.settings_closed.emit()


func _kill_tween() -> void:
	if _tween:
		_tween.kill()


func _on_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if mb.pressed:
			close()


func _sync() -> void:
	if _lullaby == null:
		return
	_syncing = true
	_lullaby.set_on(Settings.get_value(&"lullaby_on"), false)
	_talk.set_on(Settings.get_value(&"talkback_on"), false)
	_pitch.value = Settings.get_value(&"voice_pitch")
	_pitch_value.text = "%.2f" % _pitch.value
	_syncing = false


func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.theme_type_variation = &"SheetPanel"
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 12
	_sheet.offset_right = -12
	_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_sheet.add_child(col)

	var title_row := HBoxContainer.new()
	col.add_child(title_row)
	var title := Label.new()
	title.text = "Sound Settings"
	title.theme_type_variation = &"CardTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	var x := RoundButton.new()
	x.icon_id = &"close"
	x.fill = UiStyle.PEACH
	x.custom_minimum_size = Vector2.ONE * UiStyle.TOUCH_MIN
	x.pressed.connect(close)
	title_row.add_child(x)

	_lullaby = ToggleSwitch.new()
	col.add_child(_row("Soothing Lullaby", "Gentle calming chords", UiStyle.PINK, _lullaby))
	_lullaby.toggled.connect(func(v: bool) -> void:
		if not _syncing:
			Settings.set_value(&"lullaby_on", v))

	col.add_child(_pitch_block())

	_talk = ToggleSwitch.new()
	col.add_child(_row("Talking Pet", "Repeats what it hears", UiStyle.MINT, _talk))
	_talk.toggled.connect(func(v: bool) -> void:
		if not _syncing:
			Settings.set_value(&"talkback_on", v))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	col.add_child(buttons)
	var test := _text_button("Test Voice", &"SkyButton")
	test.pressed.connect(func() -> void: EventBus.test_voice_requested.emit())
	buttons.add_child(test)
	var done := _text_button("Done", &"MintButton")
	done.pressed.connect(close)
	buttons.add_child(done)


func _row(title: String, subtitle: String, tint: Color, toggle: ToggleSwitch) -> Control:
	var panel := PanelContainer.new()
	var box := UiStyle.box(tint, 24, 4, false)
	box.content_margin_left = 24
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = &"RowTitle"
	texts.add_child(t)
	var s := Label.new()
	s.text = subtitle
	s.theme_type_variation = &"RowHint"
	texts.add_child(s)
	row.add_child(toggle)
	return panel


func _pitch_block() -> Control:
	var panel := PanelContainer.new()
	var box := UiStyle.box(UiStyle.SKY, 24, 4, false)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 12
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := Label.new()
	t.text = "Voice Pitch"
	t.theme_type_variation = &"RowTitle"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_pitch_value = Label.new()
	_pitch_value.theme_type_variation = &"ValuePill"
	head.add_child(_pitch_value)
	_pitch = HSlider.new()
	_pitch.min_value = 1.2
	_pitch.max_value = 1.8
	_pitch.step = 0.05
	_pitch.custom_minimum_size.y = UiStyle.TOUCH_MIN
	_pitch.focus_mode = Control.FOCUS_NONE
	_pitch.value_changed.connect(_on_pitch_changed)
	col.add_child(_pitch)
	var ends := HBoxContainer.new()
	col.add_child(ends)
	var lo := Label.new()
	lo.text = "Natural (1.2x)"
	lo.theme_type_variation = &"RowHint"
	lo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ends.add_child(lo)
	var hi := Label.new()
	hi.text = "Cute High (1.8x)"
	hi.theme_type_variation = &"RowHint"
	ends.add_child(hi)
	return panel


func _on_pitch_changed(v: float) -> void:
	_pitch_value.text = "%.2f" % v
	if not _syncing:
		Settings.set_value(&"voice_pitch", snappedf(v, 0.05))


func _text_button(text: String, variation: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = UiStyle.TOUCH_MIN
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pivot_offset_ratio = Vector2(0.5, 0.5)
	b.button_down.connect(func() -> void:
		create_tween().tween_property(b, "scale", Vector2(0.95, 0.92), 0.06))
	b.button_up.connect(func() -> void:
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	return b
