extends Node

enum State { IDLE, WINDUP, ACTIVE, RECOVERY, BLOCKING, BLOCK_RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0
var block_duration: float = 0.325
var block_recovery_duration: float = 2.0
var block_return_duration: float = 0.3
var block_pose_position: Vector3 = Vector3(-0.12, 0.06, 0.12)
var block_pose_rotation_degrees: Vector3 = Vector3(-12.0, 0.0, 72.0)

# Tap/hold tracking
var hold_timer: float = 0.0
var heavy_threshold: float = 1.0
var is_heavy: bool = false
var current_action: String = ""  # l'input action en cours (pour tracker le hold)

# L'attaque en cours
var current_attack: AttackData = null
var blocked_by: Array[Node3D] = []

# Données d'attaque par direction : [light, heavy]
@export var slash_left_light: AttackData
@export var slash_left_heavy: AttackData
@export var slash_right_light: AttackData
@export var slash_right_heavy: AttackData
@export var overhead_light: AttackData
@export var overhead_heavy: AttackData
@export var stab_light: AttackData
@export var stab_heavy: AttackData

# Mapping input → paire [light, heavy]
var _attack_map: Dictionary = {}

var _player: CharacterBody3D
var _idle_weapon_position: Vector3 = Vector3.ZERO
var _idle_weapon_rotation: Vector3 = Vector3.ZERO
var _block_recovery_start_position: Vector3 = Vector3.ZERO
var _block_recovery_start_rotation: Vector3 = Vector3.ZERO

@onready var hit_box: Area3D
@onready var anim_player: AnimationPlayer
@onready var weapon_pivot: Node3D

func _ready() -> void:
	_player = get_parent()
	hit_box = _player.get_node("Head/WeaponPivot/Weapon/HitBox")
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	hit_box.monitoring = false
	anim_player = _player.get_node("Head/WeaponPivot/AnimationPlayer")
	weapon_pivot = _player.get_node("Head/WeaponPivot")
	_idle_weapon_position = weapon_pivot.position
	_idle_weapon_rotation = weapon_pivot.rotation

	# Construire le mapping après que les exports sont chargés
	_attack_map = {
		"attack_left": [slash_left_light, slash_left_heavy],
		"attack_right": [slash_right_light, slash_right_heavy],
		"attack_overhead": [overhead_light, overhead_heavy],
		"attack_stab": [stab_light, stab_heavy],
	}

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("block"):
		if current_state == State.IDLE:
			_enter_blocking()
			return
		if current_state == State.WINDUP:
			_cancel_windup()
			_enter_blocking()
			return

	if current_state != State.IDLE:
		return

	for action in _attack_map.keys():
		if event.is_action_pressed(action):
			current_action = action
			_enter_windup()
			return

func _physics_process(delta: float) -> void:
	match current_state:
		State.WINDUP:
			_process_windup(delta)
		State.ACTIVE:
			_process_active(delta)
		State.RECOVERY:
			_process_recovery(delta)
		State.BLOCKING:
			_process_blocking(delta)
		State.BLOCK_RECOVERY:
			_process_block_recovery(delta)

# --- WINDUP ---
func _enter_windup() -> void:
	current_state = State.WINDUP
	var pair = _attack_map[current_action]
	current_attack = pair[0]  # light par défaut
	is_heavy = false
	hold_timer = 0.0
	print(">> WINDUP %s" % current_action)
	anim_player.play(current_attack.get_windup_animation_name())

func _process_windup(delta: float) -> void:
	hold_timer += delta

	# Le swing part au relâchement du bouton
	if not Input.is_action_pressed(current_action):
		if hold_timer >= heavy_threshold:
			is_heavy = true
			var pair = _attack_map[current_action]
			current_attack = pair[1]  # heavy
			print("   -> HEAVY (maintenu %.3fs)" % hold_timer)
		_enter_active()

func _cancel_windup() -> void:
	current_attack = null
	current_action = ""
	is_heavy = false
	hold_timer = 0.0
	hit_box.monitoring = false
	anim_player.stop()
	print(">> WINDUP annulé par block")

# --- ACTIVE ---
func _enter_active() -> void:
	current_state = State.ACTIVE
	state_timer = current_attack.active_duration
	blocked_by.clear()
	hit_box.monitoring = true
	anim_player.play(current_attack.get_animation_name())
	var type_str = "HEAVY" if is_heavy else "LIGHT"
	print(">> ACTIVE (%s) — dégâts: %s" % [type_str, current_attack.damage])

func _process_active(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_recovery()

func _on_hit_box_body_entered(body: Node3D) -> void:
	if body == _player:
		return
	if body in blocked_by:
		return
	if body.has_method("take_damage"):
		if body.has_node("StateMachine"):
			body.take_damage(current_attack.damage, _player)
		else:
			body.take_damage(current_attack.damage)

# --- RECOVERY ---
func _enter_recovery() -> void:
	current_state = State.RECOVERY
	state_timer = current_attack.recovery_duration
	hit_box.monitoring = false
	print(">> RECOVERY (%.2fs)" % current_attack.recovery_duration)

func _process_recovery(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_idle()

# --- BLOCKING ---
func _enter_blocking() -> void:
	current_state = State.BLOCKING
	state_timer = block_duration
	current_attack = null
	current_action = ""
	is_heavy = false
	hold_timer = 0.0
	hit_box.monitoring = false
	_set_block_pose_instant()
	print(">> BLOCKING (%.3fs)" % block_duration)

func _process_blocking(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_block_recovery()

# --- BLOCK RECOVERY ---
func _enter_block_recovery() -> void:
	current_state = State.BLOCK_RECOVERY
	state_timer = block_recovery_duration
	_block_recovery_start_position = weapon_pivot.position
	_block_recovery_start_rotation = weapon_pivot.rotation
	hit_box.monitoring = false
	print(">> BLOCK_RECOVERY (%.2fs)" % block_recovery_duration)

func _process_block_recovery(delta: float) -> void:
	state_timer -= delta
	var progress: float = 1.0
	var elapsed: float = block_recovery_duration - state_timer
	if block_return_duration > 0.0:
		progress = elapsed / block_return_duration
	progress = clamp(progress, 0.0, 1.0)
	weapon_pivot.position = _block_recovery_start_position.lerp(_idle_weapon_position, progress)
	weapon_pivot.rotation = _block_recovery_start_rotation.lerp(_idle_weapon_rotation, progress)
	if state_timer <= 0.0:
		_enter_idle(true)

# --- IDLE ---
func _enter_idle(reset_weapon_pose: bool = false) -> void:
	current_state = State.IDLE
	current_attack = null
	current_action = ""
	is_heavy = false
	hold_timer = 0.0
	blocked_by.clear()
	hit_box.monitoring = false
	if reset_weapon_pose:
		_restore_idle_weapon_pose()
	print(">> IDLE")

func is_blocking() -> bool:
	return current_state == State.BLOCKING

func on_block_success(blocker: Node3D = null) -> void:
	if blocker != null and blocker not in blocked_by:
		blocked_by.append(blocker)
	var blocker_name: String = "unknown"
	if blocker != null:
		blocker_name = String(blocker.name)
	print(">> BLOCK SUCCESS contre %s" % blocker_name)

func _set_block_pose_instant() -> void:
	anim_player.stop()
	weapon_pivot.position = block_pose_position
	weapon_pivot.rotation_degrees = block_pose_rotation_degrees

func _restore_idle_weapon_pose() -> void:
	weapon_pivot.position = _idle_weapon_position
	weapon_pivot.rotation = _idle_weapon_rotation
