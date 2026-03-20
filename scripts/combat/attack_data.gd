class_name AttackData
extends Resource

enum Direction { LEFT, RIGHT, OVERHEAD, STAB }

@export var direction: Direction = Direction.RIGHT
@export var is_heavy: bool = false

@export_group("Timings (seconds)")
@export var windup_duration: float = 0.2
@export var active_duration: float = 0.15
@export var recovery_duration: float = 0.3

@export_group("Properties")
@export var damage: float = 20.0
@export var range_distance: float = 2.0

func get_animation_name() -> String:
	var dir = Direction.keys()[direction].to_lower()
	var weight = "heavy" if is_heavy else "light"
	return "%s_%s" % [dir, weight]
