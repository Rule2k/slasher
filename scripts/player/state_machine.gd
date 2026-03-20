extends Node

enum State { IDLE, WINDUP, ACTIVE, RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0

# Tap/hold tracking
var hold_timer: float = 0.0
var heavy_threshold: float = 1.0
var is_heavy: bool = false
var current_action: String = ""  # l'input action en cours (pour tracker le hold)

# L'attaque en cours
var current_attack: AttackData = null
var has_hit: bool = false

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
@onready var hit_box: Area3D
@onready var anim_player: AnimationPlayer

func _ready() -> void:
	_player = get_parent()
	hit_box = _player.get_node("Head/WeaponPivot/Weapon/HitBox")
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	hit_box.monitoring = false
	anim_player = _player.get_node("Head/WeaponPivot/AnimationPlayer")

	# Construire le mapping après que les exports sont chargés
	_attack_map = {
		"attack_left": [slash_left_light, slash_left_heavy],
		"attack_right": [slash_right_light, slash_right_heavy],
		"attack_overhead": [overhead_light, overhead_heavy],
		"attack_stab": [stab_light, stab_heavy],
	}

func _unhandled_input(event: InputEvent) -> void:
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

# --- WINDUP ---
func _enter_windup() -> void:
	current_state = State.WINDUP
	var pair = _attack_map[current_action]
	current_attack = pair[0]  # light par défaut
	is_heavy = false
	hold_timer = 0.0
	state_timer = current_attack.windup_duration
	print(">> WINDUP %s (light par défaut)" % current_action)
	anim_player.play(current_attack.get_animation_name())

func _process_windup(delta: float) -> void:
	state_timer -= delta
	hold_timer += delta

	if not is_heavy and Input.is_action_pressed(current_action) and hold_timer >= heavy_threshold:
		is_heavy = true
		var pair = _attack_map[current_action]
		current_attack = pair[1]  # heavy
		state_timer = 0.0
		print("   -> bascule HEAVY (maintenu %.3fs)" % hold_timer)

	if state_timer <= 0.0:
		if is_heavy or not Input.is_action_pressed(current_action):
			_enter_active()

# --- ACTIVE ---
func _enter_active() -> void:
	current_state = State.ACTIVE
	state_timer = current_attack.active_duration
	has_hit = false
	hit_box.monitoring = true
	var type_str = "HEAVY" if is_heavy else "LIGHT"
	print(">> ACTIVE (%s) — dégâts: %s" % [type_str, current_attack.damage])

func _process_active(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_recovery()

func _on_hit_box_body_entered(body: Node3D) -> void:
	if has_hit:
		return
	if body == _player:
		return
	if body.has_method("take_damage"):
		body.take_damage(current_attack.damage)
		has_hit = true

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

# --- IDLE ---
func _enter_idle() -> void:
	current_state = State.IDLE
	current_attack = null
	current_action = ""
	is_heavy = false
	hold_timer = 0.0
	print(">> IDLE")
