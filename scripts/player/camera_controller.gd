extends Node

@export var mouse_sensitivity: float = 0.002

var _player: CharacterBody3D
var _head: Node3D

func _ready() -> void:
	_player = get_parent()
	_head = _player.get_node("Head")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_player.rotate_y(-event.relative.x * mouse_sensitivity)
		_head.rotate_x(-event.relative.y * mouse_sensitivity)
		_head.rotation.x = clamp(_head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
