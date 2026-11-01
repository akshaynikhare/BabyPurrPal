class_name Pill
extends PanelContainer
## Rounded status/notice pill with an optional drawn icon.

signal tapped

var _icon := Control.new()
var _label := Label.new()
var _icon_id: StringName = &""
var _fill := UiStyle.CREAM
var _boxes: Dictionary = {}
var _tap := TapFilter.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	_icon.material = UiAtlas.material()
	_icon.add_to_group(UiAtlas.USERS)
	row.add_child(_icon)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)


func configure(wrap_width := 0.0, font_size := 0) -> void:
	if wrap_width > 0.0:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = wrap_width
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_size > 0:
		_label.add_theme_font_size_override("font_size", font_size)


func set_content(text: String, fill: Color, icon_id: StringName = &"") -> void:
	if _label.text != text:
		_label.text = text
		_pop()
	_icon_id = icon_id
	_icon.visible = icon_id != &""
	_icon.queue_redraw()
	if fill != _fill or not has_theme_stylebox_override("panel"):
		_fill = fill
		if not _boxes.has(fill):
			var sb := UiStyle.box(fill, 36, UiStyle.BORDER, false)
			sb.content_margin_left = 24
			sb.content_margin_right = 28
			sb.content_margin_top = 14
			sb.content_margin_bottom = 14
			_boxes[fill] = sb
		add_theme_stylebox_override("panel", _boxes[fill])


func _draw_icon() -> void:
	if _icon_id != &"":
		UiAtlas.draw_region(_icon, UiAtlas.glyph_key(_icon_id), Rect2(Vector2.ZERO, _icon.size))


func _pop() -> void:
	if not is_inside_tree() or not visible:
		return
	pivot_offset = size * 0.5
	scale = Vector2(0.9, 0.9)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Makes the pill a touch target (it passes touches through otherwise).
func make_tappable(min_height := UiStyle.TOUCH_MIN) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = min_height
	gui_input.connect(_on_gui_input)
	EventBus.app_paused.connect(_tap.reset)


func _on_gui_input(event: InputEvent) -> void:
	var kind := _tap.feed(event)
	if kind == TapFilter.Kind.NONE:
		return
	accept_event()
	if kind == TapFilter.Kind.PRESS:
		tapped.emit()
