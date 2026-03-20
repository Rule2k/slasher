extends Node

enum State { IDLE, STARTUP, ACTIVE, RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0

# Tap/hold tracking
var attack_held: bool = false
var hold_timer: float = 0.0
var heavy_threshold: float = 0.15  # seuil en secondes pour heavy
var heavy_locked: bool = false
var light_locked: bool = false

# L'attaque en cours
var current_attack: AttackData = null

# Les données d'attaque chargées
@export var slash_right_light: AttackData
@export var slash_right_heavy: AttackData

# Référence au joueur
var _player: CharacterBody3D

func _ready() -> void:
	_player = get_parent()

func _unhandled_input(event: InputEvent) -> void:
	# On ne peut lancer une attaque que depuis IDLE
	if current_state != State.IDLE:
		return
	
	if event.is_action_pressed("attack_right"):
		# Début du startup — on ne sait pas encore si c'est light ou heavy
		attack_held = true
		hold_timer = 0.0
		heavy_locked = false
		light_locked = false
		_enter_startup()

func _physics_process(delta: float) -> void:
	match current_state:
		State.STARTUP:
			_process_startup(delta)
		State.ACTIVE:
			_process_active(delta)
		State.RECOVERY:
			_process_recovery(delta)

# --- STARTUP ---
func _enter_startup() -> void:
	current_state = State.STARTUP
	# On commence avec les timings light par défaut
	# mais on ne verrouille pas encore
	current_attack = slash_right_light
	state_timer = current_attack.startup_duration
	print(">> STARTUP (en attente light/heavy)")

func _process_startup(delta: float) -> void:
	state_timer -= delta
	
	# Track du hold
	if attack_held:
		hold_timer += delta
		# Vérifier si la touche est toujours tenue
		if not Input.is_action_pressed("attack_right"):
			attack_held = false
			light_locked = true
			current_attack = slash_right_light
			print("   -> LIGHT verrouillé (relâché à %.3fs)" % hold_timer)
		elif hold_timer >= heavy_threshold and not heavy_locked:
			heavy_locked = true
			current_attack = slash_right_heavy
			print("   -> HEAVY verrouillé (maintenu %.3fs)" % hold_timer)
	
	# Fin du startup → passer en active
	if state_timer <= 0.0:
		# Si ni light ni heavy n'est verrouillé à la fin du startup,
		# on verrouille light par défaut
		if not light_locked and not heavy_locked:
			light_locked = true
			current_attack = slash_right_light
			print("   -> LIGHT par défaut (fin startup)")
		_enter_active()

# --- ACTIVE ---
func _enter_active() -> void:
	current_state = State.ACTIVE
	state_timer = current_attack.active_duration
	var type_str = "HEAVY" if current_attack.is_heavy else "LIGHT"
	print(">> ACTIVE (%s) — dégâts: %s, durée: %ss" % [type_str, current_attack.damage, current_attack.active_duration])
	# TODO: activer la hitbox ici

# --- HIT DETECTION (sera implémentée ensuite) ---
func _process_active(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_recovery()

# --- RECOVERY ---
func _enter_recovery() -> void:
	current_state = State.RECOVERY
	state_timer = current_attack.recovery_duration
	print(">> RECOVERY (%.2fs)" % current_attack.recovery_duration)
	# TODO: désactiver la hitbox ici

func _process_recovery(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_enter_idle()

# --- IDLE ---
func _enter_idle() -> void:
	current_state = State.IDLE
	current_attack = null
	attack_held = false
	hold_timer = 0.0
	heavy_locked = false
	light_locked = false
	print(">> IDLE")
