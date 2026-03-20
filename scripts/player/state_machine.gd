extends Node

enum State { IDLE, WINDUP, ACTIVE, RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0
var has_hit: bool = false

@onready var attack_raycast: RayCast3D

# Tap/hold tracking
var hold_timer: float = 0.0
var heavy_threshold: float = 1
var is_heavy: bool = false

# L'attaque en cours
var current_attack: AttackData = null

# Les données d'attaque chargées
@export var slash_right_light: AttackData
@export var slash_right_heavy: AttackData

var _player: CharacterBody3D

func _ready() -> void:
	_player = get_parent()
	attack_raycast = _player.get_node("Head/AttackRaycast")

func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.IDLE:
		return
	
	if event.is_action_pressed("attack_right"):
		_enter_windup()

func _physics_process(delta: float) -> void:
	match current_state:
		State.WINDUP:
			_process_windup(delta)
		State.ACTIVE:
			_process_active(delta)
		State.RECOVERY:
			_process_recovery(delta)

# --- WINDUP ---
func _enter_windup() -> void:
	current_state = State.WINDUP
	# Light par défaut, immédiatement
	current_attack = slash_right_light
	is_heavy = false
	hold_timer = 0.0
	state_timer = current_attack.windup_duration
	print(">> WINDUP (light par défaut)")

func _process_windup(delta: float) -> void:
	state_timer -= delta
	hold_timer += delta
	
	# Si maintenu au-delà du seuil → bascule en heavy
	if not is_heavy and Input.is_action_pressed("attack_right") and hold_timer >= heavy_threshold:
		is_heavy = true
		current_attack = slash_right_heavy
		state_timer = 0.0  # heavy prêt, passer en active immédiatement
		print("   -> bascule HEAVY (maintenu %.3fs)" % hold_timer)
	
	# Ne quitter le windup que si :
	# - le timer est fini ET la touche est relâchée (light confirmé)
	# - le timer est fini ET heavy est verrouillé
	# - la touche est relâchée (light confirmé, même si timer pas fini on attend le timer)
	if state_timer <= 0.0:
		if is_heavy or not Input.is_action_pressed("attack_right"):
			_enter_active()


# --- ACTIVE ---
func _enter_active() -> void:
	current_state = State.ACTIVE
	state_timer = current_attack.active_duration
	has_hit = false
	attack_raycast.target_position.z = -current_attack.range_distance
	attack_raycast.enabled = true
	attack_raycast.force_raycast_update()
	var type_str = "HEAVY" if is_heavy else "LIGHT"
	print(">> ACTIVE (%s) — dégâts: %s" % [type_str, current_attack.damage])

func _process_active(delta: float) -> void:
	if not has_hit and attack_raycast.is_colliding():
		var target = attack_raycast.get_collider()
		if target.has_method("take_damage"):
			target.take_damage(current_attack.damage)
			has_hit = true
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_recovery()


# --- RECOVERY ---
func _enter_recovery() -> void:
	current_state = State.RECOVERY
	state_timer = current_attack.recovery_duration
	attack_raycast.enabled = false
	print(">> RECOVERY (%.2fs)" % current_attack.recovery_duration)


func _process_recovery(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_idle()

# --- IDLE ---
func _enter_idle() -> void:
	current_state = State.IDLE
	current_attack = null
	is_heavy = false
	hold_timer = 0.0
	print(">> IDLE")
