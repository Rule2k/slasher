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
