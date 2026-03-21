extends Node

enum State { IDLE, WINDUP, ACTIVE, RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0
var current_attack: AttackData = null
var has_hit: bool = false

@export var slash_left_light: AttackData
@export var slash_right_light: AttackData
@export var overhead_light: AttackData
@export var stab_light: AttackData

var _attack_list: Array[AttackData] = []
var _enemy: CharacterBody3D

@onready var hit_box: Area3D
@onready var anim_player: AnimationPlayer

func _ready() -> void:
	_enemy = get_parent()
	hit_box = _enemy.get_node("Head/WeaponPivot/Weapon/HitBox")
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	hit_box.monitoring = false
	anim_player = _enemy.get_node("Head/WeaponPivot/AnimationPlayer")
	
	_attack_list = [slash_left_light, slash_right_light, overhead_light, stab_light]

func _physics_process(delta: float) -> void:
	match current_state:
		State.WINDUP:
			_process_windup(delta)
		State.ACTIVE:
			_process_active(delta)
		State.RECOVERY:
			_process_recovery(delta)

# --- Fonctions publiques (appelées par l'IA) ---
func is_idle() -> bool:
	return current_state == State.IDLE

func start_attack() -> void:
	if current_state != State.IDLE:
		return
	# Choisir une attaque aléatoire
	current_attack = _attack_list.pick_random()
	_enter_windup()

# --- WINDUP ---
func _enter_windup() -> void:
	current_state = State.WINDUP
	state_timer = current_attack.windup_duration
	anim_player.play(current_attack.get_windup_animation_name())
	print("[IA] >> WINDUP %s" % current_attack.direction)

func _process_windup(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_active()

# --- ACTIVE ---
func _enter_active() -> void:
	current_state = State.ACTIVE
	state_timer = current_attack.active_duration
	has_hit = false
	hit_box.monitoring = true
	anim_player.play(current_attack.get_animation_name())
	print("[IA] >> ACTIVE — dégâts: %s" % current_attack.damage)

func _process_active(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_recovery()

func _on_hit_box_body_entered(body: Node3D) -> void:
	if body == _enemy:
		return
	if has_hit:
		return
	if body.has_method("take_damage"):
		body.take_damage(current_attack.damage, _enemy)
		has_hit = true

# --- RECOVERY ---
func _enter_recovery() -> void:
	current_state = State.RECOVERY
	state_timer = current_attack.recovery_duration
	hit_box.monitoring = false
	print("[IA] >> RECOVERY (%.2fs)" % current_attack.recovery_duration)

func _process_recovery(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_idle()

# --- IDLE ---
func _enter_idle() -> void:
	current_state = State.IDLE
	current_attack = null
	has_hit = false
	print("[IA] >> IDLE")
