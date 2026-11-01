class_name UiLayer
extends CanvasLayer
## Whole in-game UI. Talks to the stage only through EventBus and Settings.

const THEME := preload("res://scenes/ui/ui_theme.tres")
const MARGIN := 16.0
const BUTTON := 96.0
const MIC_HINT := "Tap pet's mouth or toys below to hear speech!"
const ZOOM_HINT := "Face Close-Up (Pinch or Tap to Reset)"

var _safe: Control
var _status: Pill
var _hint: Pill
var _zoom_pill: Pill
var _phase_button: RoundButton
var _zoom_button: RoundButton
var _toys: ToyBar
var _sheet: SettingsSheet
var _overlay: StartOverlay
var _pet_index := 0
var _pet_name := ToyCatalog.DEFAULT_NAMES[0]
var _talk_state: StringName = &""
var _mic_denied := false
var _zoomed := false


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "Root"
	root.theme = THEME
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_safe = Control.new()
	_safe.name = "Safe"
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_safe)
	_build_header()
	_build_notices()
	_toys = ToyBar.new()
	_toys.name = "Toys"
	_toys.anchor_right = 1.0
	_toys.anchor_top = 1.0
	_toys.anchor_bottom = 1.0
	_toys.offset_bottom = -20
	_toys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_safe.add_child(_toys)
	_overlay = StartOverlay.new()
	_overlay.name = "StartOverlay"
	_safe.add_child(_overlay)
	_sheet = SettingsSheet.new()
	_sheet.name = "SettingsSheet"
	root.add_child(_sheet)

	EventBus.pet_changed.connect(_on_pet_changed)
	EventBus.talkback_state_changed.connect(_on_talk_state)
	EventBus.mic_permission_changed.connect(_on_mic_permission)
	EventBus.time_phase_changed.connect(_on_phase)
	EventBus.zoom_changed.connect(_on_zoom)
	get_tree().root.size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	UiAtlas.bake(self)
	_on_phase(&"day")
	_refresh_status()
	_refresh_notices()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_overlay.dismiss()
		set_process_input(false)


func _build_header() -> void:
	var header := Control.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.anchor_right = 1.0
	header.offset_top = MARGIN
	header.offset_bottom = MARGIN + BUTTON
	_safe.add_child(header)

	_status = Pill.new()
	_status.name = "StatusPill"
	_status.position = Vector2(MARGIN, 10)
	_status.configure(0.0, 34)
	header.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 10)
	buttons.anchor_left = 1.0
	buttons.anchor_right = 1.0
	buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons.offset_right = -MARGIN
	header.add_child(buttons)

	_phase_button = _header_button(buttons, &"sun", UiStyle.SKY)
	_phase_button.name = "PhaseButton"
	_phase_button.pressed.connect(EventBus.time_phase_cycle_requested.emit)
	_zoom_button = _header_button(buttons, &"zoom_in", UiStyle.MINT)
	_zoom_button.name = "ZoomButton"
	_zoom_button.pressed.connect(EventBus.zoom_toggle_requested.emit)
	var gear := GearButton.new()
	gear.name = "GearButton"
	gear.custom_minimum_size = Vector2.ONE * BUTTON
	gear.gate_opened.connect(func() -> void: _sheet.open())
	buttons.add_child(gear)


func _header_button(parent: Control, icon: StringName, fill: Color) -> RoundButton:
	var b := RoundButton.new()
	b.icon_id = icon
	b.fill = fill
	b.custom_minimum_size = Vector2.ONE * BUTTON
	parent.add_child(b)
	return b


func _build_notices() -> void:
	var notices := VBoxContainer.new()
	notices.name = "Notices"
	notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notices.alignment = BoxContainer.ALIGNMENT_BEGIN
	notices.anchor_right = 1.0
	notices.offset_top = MARGIN + BUTTON + 18
	notices.offset_left = MARGIN
	notices.offset_right = -MARGIN
	notices.add_theme_constant_override("separation", 10)
	_safe.add_child(notices)
	_hint = Pill.new()
	_hint.name = "MicHint"
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint.configure(620.0, 26)
	_hint.set_content(MIC_HINT, UiStyle.PEACH)
	notices.add_child(_hint)
	_zoom_pill = Pill.new()
	_zoom_pill.name = "ZoomPill"
	_zoom_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_zoom_pill.configure(0.0, 28)
	_zoom_pill.set_content(ZOOM_HINT, UiStyle.MINT)
	_zoom_pill.make_tappable()
	_zoom_pill.tapped.connect(EventBus.zoom_toggle_requested.emit)
	notices.add_child(_zoom_pill)


## Display cut-outs and gesture bars only exist on phones; desktop "safe area" is the whole screen.
func _apply_safe_area() -> void:
	var insets := Vector4.ZERO
	if OS.has_feature("mobile"):
		insets = UiLayout.safe_insets(DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size(), get_viewport().get_visible_rect().size)
	_safe.offset_left = insets.x
	_safe.offset_top = insets.y
	_safe.offset_right = -insets.z
	_safe.offset_bottom = -insets.w
	_sheet.bottom_inset = insets.w


func _on_pet_changed(index: int, pet_name: String) -> void:
	_pet_index = index
	var cleaned := ToyCatalog.clean_name(pet_name)
	_pet_name = cleaned if cleaned != "" else ToyCatalog.DEFAULT_NAMES[posmod(index, 3)]
	_toys.set_pet(index)
	_refresh_status()


func _on_talk_state(state: StringName) -> void:
	_talk_state = state
	match state:
		&"DONT_HEAR":
			_mic_denied = true
		&"READY_TO_LISTEN", &"LISTEN", &"TALK", &"CELEBRATE":
			_mic_denied = false
	_refresh_status()
	_refresh_notices()


func _on_mic_permission(granted: bool) -> void:
	_mic_denied = not granted
	_refresh_notices()


func _on_phase(phase: StringName) -> void:
	for entry: Array in UiAtlas.PHASES:
		if entry[0] == phase:
			_phase_button.set_icon(entry[1])
			_phase_button.set_fill(entry[2])


func _on_zoom(zoomed: bool) -> void:
	_zoomed = zoomed
	_zoom_button.set_icon(&"zoom_out" if zoomed else &"zoom_in")
	_refresh_notices()


func _refresh_status() -> void:
	match _talk_state:
		&"LISTEN":
			_status.set_content("Listening!", UiStyle.AMBER, &"waves")
		&"TALK":
			_status.set_content("Repeating!", UiStyle.BLUE, &"speech")
		_:
			_status.set_content(_pet_name, UiStyle.CREAM, ToyCatalog.face_for(_pet_index))


func _refresh_notices() -> void:
	_hint.visible = _mic_denied
	_zoom_pill.visible = _zoomed
