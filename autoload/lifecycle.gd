extends Node
## Pauses the game and every sound when the app leaves the foreground,
## and restores both when it comes back.

var is_active := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_set_active(false)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_set_active(true)


func _set_active(active: bool) -> void:
	if active == is_active or not is_inside_tree():
		return
	is_active = active
	get_tree().paused = not active
	if active:
		AudioDirector.resume_all()
		EventBus.app_resumed.emit()
	else:
		AudioDirector.pause_all()
		EventBus.app_paused.emit()
