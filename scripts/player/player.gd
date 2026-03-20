extends CharacterBody3D

var health: float = 100.0

# Références aux modules (disponibles pour communication inter-modules)
@onready var camera_controller: Node = $CameraController
@onready var movement_controller: Node = $MovementController
@onready var state_machine: Node = $StateMachine

func take_damage(amount: float, attacker: Node3D) -> void:
	if _is_front_block_success(attacker):
		var attacker_state_machine: Node = attacker.get_node_or_null("StateMachine")
		if attacker_state_machine != null and attacker_state_machine.has_method("on_block_success"):
			attacker_state_machine.on_block_success(self)
		print("Block réussi contre %s" % attacker.name)
		return

	health -= amount
	print("Player touché ! Dégâts: %s — Vie restante: %s" % [amount, health])

func _is_front_block_success(attacker: Node3D) -> bool:
	if attacker == null:
		return false
	if not state_machine.has_method("is_blocking"):
		return false
	if not state_machine.is_blocking():
		return false

	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0

	var to_attacker: Vector3 = attacker.global_position - global_position
	to_attacker.y = 0.0

	if forward.length_squared() == 0.0 or to_attacker.length_squared() == 0.0:
		return false

	return forward.normalized().dot(to_attacker.normalized()) > 0.0
