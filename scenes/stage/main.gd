extends Node
## Root of the game: the 3D stage plus the UI layer on top, when it exists.

const UI_SCENE := "res://scenes/ui/ui_layer.tscn"


func _ready() -> void:
	if ResourceLoader.exists(UI_SCENE):
		add_child((load(UI_SCENE) as PackedScene).instantiate())
