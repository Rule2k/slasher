extends Node

enum State { IDLE, MOVING }

var current_state: State = State.IDLE

func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	# Sera rempli quand on ajoutera le combat
	pass
