extends Node

@export var move_speed: float = 5.0
@export var jump_velocity: float = 4.5

var _player: CharacterBody3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# La state machine pourra couper le mouvement via cette variable
var can_move: bool = true

func _ready() -> void:
	_player = get_parent()

func _physics_process(delta: float) -> void:
	# Gravité (toujours active)
	if not _player.is_on_floor():
		_player.velocity.y -= gravity * delta
	
	# Jump
	if _player.is_on_floor() and Input.is_action_just_pressed("jump"):
		_player.velocity.y = jump_velocity
	
	# Déplacement
	if can_move:
		var input_dir := Vector2.ZERO
		input_dir.x = Input.get_axis("move_left", "move_right")
		input_dir.y = Input.get_axis("move_forward", "move_backward")
		
		var direction := (_player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			_player.velocity.x = direction.x * move_speed
			_player.velocity.z = direction.z * move_speed
		else:
			_player.velocity.x = 0.0
			_player.velocity.z = 0.0
	else:
		_player.velocity.x = 0.0
		_player.velocity.z = 0.0
	
	_player.move_and_slide()
