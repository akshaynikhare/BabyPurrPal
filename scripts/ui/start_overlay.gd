class_name StartOverlay
extends Control
## Small bouncy "tap to play" pill above the toys bar. Never blocks touches: the stage still gets the first tap.

## Clear of the pet's face and the toys bar (20 px margin + ~210 px bar + gap).
const BOTTOM_OFFSET := 262.0

var _tween: Tween
var _card: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.anchor_right = 1.0
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_bottom = -BOTTOM_OFFSET
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(holder)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _card_box())
	holder.add_child(_card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_card.add_child(row)
	var paw := Control.new()
	paw.custom_minimum_size = Vector2(64, 64)
	paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paw.material = UiAtlas.material()
	paw.add_to_group(UiAtlas.USERS)
	paw.draw.connect(func() -> void: UiAtlas.draw_region(paw, &"glyph_paw", Rect2(Vector2.ZERO, paw.size)))
	row.add_child(paw)
	var label := Label.new()
	label.text = "Tap to play with your pet!"
	label.theme_type_variation = &"CardTitle"
	label.add_theme_font_size_override("font_size", 34)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size * 0.5)
	_bounce.call_deferred()


func dismiss() -> void:
	if not visible:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(hide)


func _bounce() -> void:
	_card.pivot_offset = _card.size * 0.5
	_tween = create_tween().set_loops()
	_tween.tween_property(_card, "scale", Vector2(1.05, 0.95), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_card, "scale", Vector2(0.97, 1.05), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.25)


func _card_box() -> StyleBoxFlat:
	var sb := UiStyle.box(UiStyle.CREAM, 36, 5, false)
	sb.content_margin_left = 22
	sb.content_margin_right = 30
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	return sb
