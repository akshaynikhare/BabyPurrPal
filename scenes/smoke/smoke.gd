extends Control
## Toolchain check: portrait lock, OGG playback, vibration, mic level, pause on background.

var _label: Label
var _meter: ProgressBar
var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _pauses := 0


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 32)
	add_child(box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_font_size_override("font_size", 34)
	box.add_child(_label)

	box.add_child(_button("Play tone", func() -> void: AudioDirector.play_sfx(&"smoke_tone")))
	box.add_child(_button("Vibrate", func() -> void: Input.vibrate_handheld(120)))

	_meter = ProgressBar.new()
	_meter.max_value = 1.0
	_meter.custom_minimum_size = Vector2(0, 60)
	box.add_child(_meter)

	AudioDirector.play_music(&"smoke_loop")
	EventBus.app_paused.connect(func() -> void: _pauses += 1)
	if ProjectSettings.get_setting("audio/driver/enable_input", false):
		_start_mic()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 160)
	button.add_theme_font_size_override("font_size", 44)
	button.pressed.connect(action)
	return button


func _start_mic() -> void:
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, "MicSmoke")
	AudioServer.set_bus_mute(index, true)
	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(index, _capture)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = &"MicSmoke"
	add_child(_mic_player)
	get_tree().on_request_permissions_result.connect(_on_permission_result)
	_mic_player.play()


func _on_permission_result(permission: String, granted: bool) -> void:
	if granted and permission.ends_with("RECORD_AUDIO"):
		_mic_player.stop()
		_mic_player.play()


func _process(_delta: float) -> void:
	var rms := 0.0
	if _capture and _capture.get_frames_available() > 0:
		var buffer := _capture.get_buffer(_capture.get_frames_available())
		var sum := 0.0
		for frame in buffer:
			sum += frame.x * frame.x
		rms = sqrt(sum / buffer.size())
	_meter.value = clampf(rms * 8.0, 0.0, 1.0)
	_label.text = "Smoke test · Godot %s\nmic rms %.3f · pauses %d\n%s" % [
		Engine.get_version_info().string, rms, _pauses, ", ".join(OS.get_granted_permissions())]
