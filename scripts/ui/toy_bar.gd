class_name ToyBar
extends HBoxContainer
## Three toy buttons for the current pet. Buttons are reused; only icon, colour and label change.
## Locked (dimmed, presses answered with a soft "not now") while a toy session runs,
## across pet changes too.

const BUTTON_SIZE := 156.0

var _buttons: Array[RoundButton] = []
var _labels: Array[Label] = []
var _toys: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	for i in 3:
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.custom_minimum_size.x = 222
		cell.add_theme_constant_override("separation", 6)
		add_child(cell)
		var button := RoundButton.new()
		button.trigger_on_press = true
		button.custom_minimum_size = Vector2.ONE * BUTTON_SIZE
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_pressed.bind(i))
		button.refused.connect(AudioDirector.play_sfx.bind(&"ui_nope"))
		cell.add_child(button)
		var label := Label.new()
		label.theme_type_variation = &"ToyLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(label)
		_buttons.append(button)
		_labels.append(label)
	set_pet(0)
	EventBus.toy_started.connect(func(_id: StringName) -> void: set_locked(true))
	EventBus.toy_finished.connect(func(_id: StringName) -> void: set_locked(false))


func set_pet(pet_index: int) -> void:
	_toys = ToyCatalog.toys_for(pet_index)
	for i in 3:
		var toy: Dictionary = _toys[i]
		_buttons[i].set_icon(toy.id)
		_buttons[i].set_fill(toy.fill)
		_labels[i].text = toy.label


func set_locked(on: bool) -> void:
	for i in 3:
		_buttons[i].set_disabled(on)
		_labels[i].modulate.a = RoundButton.DISABLED_ALPHA if on else 1.0


func _on_pressed(i: int) -> void:
	AudioDirector.play_sfx(&"ui_toy")
	EventBus.toy_used.emit(_toys[i].id)
