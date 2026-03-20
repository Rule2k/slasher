extends CharacterBody3D

var health: float = 100.0
var move_speed: float = 2.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: Node3D = null

func _ready() -> void:
	# Trouver le joueur dans la scène
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	# Gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Se déplacer vers le joueur
	if player:
		var direction = (player.global_position - global_position)
		direction.y = 0
		var distance = direction.length()
		
		# Toujours regarder le joueur
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z))
		
		if distance > 2.0:
			direction = direction.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	
	move_and_slide()

func take_damage(amount: float) -> void:
	health -= amount
	print("Ennemi touché ! Dégâts: %s — Vie: %s" % [amount, health])
