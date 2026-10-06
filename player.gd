extends CharacterBody2D

enum State {
	IDLE, MOVE, AIRBORNE, DASH,
	LIGHT_ATTACK, HEAVY_ATTACK,
	PARRY, PARRY_STUNNED, HITSTUN, DEAD,
}

signal died

@export var input_prefix: String = ""

const SPEED := 420.0
const JUMP_VELOCITY := -720.0
const GRAVITY := 2200.0

const DASH_SPEED := 1100.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.55

const LIGHT_DURATION := 0.28
const LIGHT_ACTIVE_START := 0.06
const LIGHT_ACTIVE_END := 0.12
const LIGHT_DAMAGE := 8.0

const HEAVY_DURATION := 0.55
const HEAVY_ACTIVE_START := 0.22
const HEAVY_ACTIVE_END := 0.30
const HEAVY_DAMAGE := 20.0

const PARRY_DURATION := 0.34
const PARRY_STUN_DURATION := 0.6
const HITSTUN_DURATION := 0.3
const MAX_HEALTH := 100.0

var state: int = State.IDLE
var facing := 1
var dash_dir := Vector2.ZERO
var state_timer := 0.0
var dash_cd_timer := 0.0
var health := MAX_HEALTH
var is_frozen := false

@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var health_label: Label = $HealthLabel
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _physics_process(delta: float) -> void:
	if dash_cd_timer > 0.0:
		dash_cd_timer -= delta
	state_timer += delta

	if not is_on_floor() and state != State.DASH:
		velocity.y += GRAVITY * delta

	match state:
		State.DASH:
			velocity = dash_dir * DASH_SPEED
			if state_timer >= DASH_DURATION:
				_change_state(State.IDLE)
		State.LIGHT_ATTACK:
			if state_timer >= LIGHT_DURATION:
				_change_state(State.IDLE)
		State.HEAVY_ATTACK:
			if state_timer >= HEAVY_DURATION:
				_change_state(State.IDLE)
		State.PARRY:
			if state_timer >= PARRY_DURATION:
				_change_state(State.IDLE)
		State.PARRY_STUNNED:
			if state_timer >= PARRY_STUN_DURATION:
				_change_state(State.IDLE)
		State.HITSTUN:
			if state_timer >= HITSTUN_DURATION:
				_change_state(State.IDLE)
		State.DEAD:
			pass
		_:
			_handle_input()

	_update_hitbox()
	_update_visual()
	move_and_slide()


func _handle_input() -> void:
	if is_frozen:
		velocity.x = 0.0
		return

	var direction := Input.get_axis(input_prefix + "move_left", input_prefix + "move_right")
	if direction != 0.0:
		facing = 1 if direction > 0 else -1

	if Input.is_action_just_pressed(input_prefix + "jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed(input_prefix + "dash") and dash_cd_timer <= 0.0:
		dash_dir = Vector2(direction, 0).normalized() if direction != 0.0 else Vector2(facing, 0)
		dash_cd_timer = DASH_COOLDOWN
		_change_state(State.DASH)
		return

	if Input.is_action_just_pressed(input_prefix + "light_attack"):
		velocity.x = 0.0
		_change_state(State.LIGHT_ATTACK)
		return

	if Input.is_action_just_pressed(input_prefix + "heavy_attack"):
		velocity.x = 0.0
		_change_state(State.HEAVY_ATTACK)
		return

	if Input.is_action_just_pressed(input_prefix + "parry"):
		velocity.x = 0.0
		_change_state(State.PARRY)
		return

	velocity.x = direction * SPEED
	state = State.MOVE if (direction != 0.0 and is_on_floor()) else (State.IDLE if is_on_floor() else State.AIRBORNE)


func _change_state(new_state: int) -> void:
	state = new_state
	state_timer = 0.0


func _update_hitbox() -> void:
	hitbox.position.x = 45.0 * facing
	var active := false
	if state == State.LIGHT_ATTACK:
		active = state_timer >= LIGHT_ACTIVE_START and state_timer <= LIGHT_ACTIVE_END
	elif state == State.HEAVY_ATTACK:
		active = state_timer >= HEAVY_ACTIVE_START and state_timer <= HEAVY_ACTIVE_END
	hitbox_shape.disabled = not active


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if state == State.DEAD:
		return

	var attacker = area.get_parent()
	if attacker == self:
		return

	var incoming_light: bool = attacker.state == State.LIGHT_ATTACK
	var incoming_heavy: bool = attacker.state == State.HEAVY_ATTACK
	if not (incoming_light or incoming_heavy):
		return

	if state == State.PARRY:
		attacker._change_state(State.PARRY_STUNNED)
		return

	health = max(health - (LIGHT_DAMAGE if incoming_light else HEAVY_DAMAGE), 0.0)
	if health <= 0.0:
		_change_state(State.DEAD)
		died.emit()
	else:
		_change_state(State.HITSTUN)


func freeze() -> void:
	is_frozen = true


func unfreeze() -> void:
	is_frozen = false


func reset_for_round(spawn_position: Vector2, new_facing: int) -> void:
	is_frozen = false
	position = spawn_position
	velocity = Vector2.ZERO
	facing = new_facing
	health = MAX_HEALTH
	_change_state(State.IDLE)


func _update_visual() -> void:
	visual.scale.x = abs(visual.scale.x) * (1 if facing >= 0 else -1)
	health_label.text = str(int(health))
	match state:
		State.LIGHT_ATTACK, State.HEAVY_ATTACK:
			visual.modulate = Color.ORANGE
		State.PARRY:
			visual.modulate = Color.CYAN
		State.DASH:
			visual.modulate = Color.YELLOW
		State.PARRY_STUNNED, State.HITSTUN:
			visual.modulate = Color.GRAY
		State.DEAD:
			visual.modulate = Color.BLACK
		_:
			visual.modulate = Color.WHITE
