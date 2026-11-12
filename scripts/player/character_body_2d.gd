extends CharacterBody2D

signal health_changed(current_hp, max_hp)
signal player_died

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const CHARACTER_NAME = "Nabab AKA N'"

# Combat stats
const MAX_HEALTH: float = 8.0
const ATTACK_DAMAGE: float = 35.0
const ATTACK_RANGE: float = 110.0
const MECH_ARM_DAMAGE: float = 55.0
const MECH_ARM_RADIUS: float = 150.0

# Movement & Physics tuning (Dead Cells style feel)
const WALK_SPEED: float = 140.0
const RUN_SPEED: float = 240.0
const ACCELERATION: float = 1500.0
const FRICTION: float = 2200.0
const GRAVITY: float = 980.0
const JUMP_VELOCITY: float = -380.0
const JUMP_CUT_MULTIPLIER: float = 0.5
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.10

# Dodge / Slide tuning
const DODGE_SPEED: float = 310.0
const DODGE_DURATION: float = 0.35
const DODGE_COOLDOWN: float = 0.55

# States enum
enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	DODGE,
	ATTACK,
	MECH_ARM,
	PARRY,
	HURT,
	DEAD
}

var current_state: State = State.IDLE
var current_health: float = MAX_HEALTH
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0
var controls_locked: bool = false

# Buffers & timers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_dir: float = 1.0
var attack_timer: float = 0.0
var mech_arm_cooldown: float = 0.0

# Combat targets
var current_attack_damaged: Array = []
var shockwave_active: bool = false
var shockwave_radius: float = 16.0
var shockwave_alpha: float = 1.0
var shockwave_center: Vector2 = Vector2.ZERO
var shockwave_fissures: Array = []

var slam_particles: CPUParticles2D = null

func _ready():
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	current_health = MAX_HEALTH

	_setup_particles()

	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)

	change_state(State.IDLE)
	emit_signal("health_changed", current_health, MAX_HEALTH)

func _setup_particles():
	slam_particles = CPUParticles2D.new()
	slam_particles.name = "SlamParticles"
	slam_particles.emitting = false
	slam_particles.one_shot = true
	slam_particles.explosiveness = 1.0
	slam_particles.amount = 36
	slam_particles.lifetime = 0.5
	slam_particles.direction = Vector2(0, -1)
	slam_particles.spread = 80.0
	slam_particles.initial_velocity_min = 100.0
	slam_particles.initial_velocity_max = 240.0
	slam_particles.gravity = Vector2(0, 360.0)
	slam_particles.scale_amount_min = 2.5
	slam_particles.scale_amount_max = 5.0
	var slam_ramp = Gradient.new()
	slam_ramp.set_color(0, Color(0.3, 1.0, 1.0, 1.0))
	slam_ramp.add_point(0.5, Color(1.0, 0.85, 0.3, 0.9))
	slam_ramp.set_color(slam_ramp.get_point_count() - 1, Color(0.2, 0.4, 1.0, 0.0))
	slam_particles.color_ramp = slam_ramp
	add_child(slam_particles)

func _physics_process(delta: float):
	_update_timers(delta)

	if shockwave_active:
		queue_redraw()

	if current_state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return

	if controls_locked:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return

	# State-specific physics
	match current_state:
		State.IDLE, State.RUN:
			_handle_ground_movement(delta)
			if not is_on_floor():
				change_state(State.FALL)
			elif jump_buffer_timer > 0.0:
				jump()

		State.JUMP:
			_apply_gravity(delta)
			_handle_air_movement(delta)
			if velocity.y >= 0.0:
				change_state(State.FALL)

		State.FALL:
			_apply_gravity(delta)
			_handle_air_movement(delta)
			if is_on_floor():
				if jump_buffer_timer > 0.0:
					jump()
				elif abs(velocity.x) > 10.0:
					change_state(State.RUN)
				else:
					change_state(State.IDLE)

		State.DODGE:
			velocity.x = dodge_dir * DODGE_SPEED
			dodge_timer -= delta
			if dodge_timer <= 0.0:
				is_invulnerable = false
				if is_on_floor():
					change_state(State.IDLE)
				else:
					change_state(State.FALL)

		State.ATTACK, State.MECH_ARM, State.PARRY:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			attack_timer -= delta
			if attack_timer <= 0.0:
				if is_on_floor():
					change_state(State.IDLE)
				else:
					change_state(State.FALL)

		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	move_and_slide()

func _update_timers(delta: float):
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0 and current_state != State.DODGE:
			is_invulnerable = false

	if mech_arm_cooldown > 0.0:
		mech_arm_cooldown -= delta

	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta

	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

func _handle_ground_movement(delta: float):
	var move_input = _get_horizontal_input()

	if move_input != 0.0:
		velocity.x = move_toward(velocity.x, move_input * RUN_SPEED, ACCELERATION * delta)
		if animated_sprite:
			animated_sprite.flip_h = (move_input < 0.0)
		if current_state != State.RUN:
			change_state(State.RUN)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if current_state != State.IDLE and abs(velocity.x) < 5.0:
			change_state(State.IDLE)

func _handle_air_movement(delta: float):
	var move_input = _get_horizontal_input()
	if move_input != 0.0:
		velocity.x = move_toward(velocity.x, move_input * RUN_SPEED, ACCELERATION * 0.7 * delta)
		if animated_sprite:
			animated_sprite.flip_h = (move_input < 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * 0.3 * delta)

func _apply_gravity(delta: float):
	velocity.y += GRAVITY * delta

func _get_horizontal_input() -> float:
	var move = 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("walk") or Input.is_action_pressed("ui_right"):
		move += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		move -= 1.0
	return move

func _unhandled_input(event: InputEvent):
	if controls_locked or current_state == State.DEAD:
		return

	# Jump inputs
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_W or event.keycode == KEY_SPACE)):
		jump_buffer_timer = JUMP_BUFFER_TIME
		if coyote_timer > 0.0 and can_act():
			jump()
			return

	# Variable jump height cut
	if event.is_action_released("ui_up") or (event is InputEventKey and not event.is_pressed() and (event.keycode == KEY_W or event.keycode == KEY_SPACE)):
		if velocity.y < 0.0:
			velocity.y *= JUMP_CUT_MULTIPLIER

	# Attack inputs
	if event.is_action_pressed("sword") or (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.is_pressed() and event.keycode == KEY_J):
		if can_act():
			attack()
			return

	# Mech Arm / Grapple
	if event.is_action_pressed("mech arm_1") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_T or event.keycode == KEY_K)):
		if can_act() and mech_arm_cooldown <= 0.0:
			use_mech_arm()
			return

	# Dodge / Slide
	if event.is_action_pressed("dodge") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_M or event.keycode == KEY_C or event.keycode == KEY_SHIFT)):
		if can_act() and dodge_cooldown_timer <= 0.0:
			dodge()
			return

	# Parry / Aegis Shield (Right Click / E)
	if (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.is_pressed() and event.keycode == KEY_E):
		if can_act():
			parry()
			return

func can_act() -> bool:
	return current_state in [State.IDLE, State.RUN, State.JUMP, State.FALL] and not controls_locked

func jump():
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	velocity.y = JUMP_VELOCITY
	change_state(State.JUMP)

func attack():
	change_state(State.ATTACK)
	attack_timer = 0.65
	current_attack_damaged.clear()
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("sword")

func parry():
	change_state(State.PARRY)
	attack_timer = 0.5
	is_invulnerable = true
	invulnerable_timer = 0.35
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("parry")

func dodge():
	var move_input = _get_horizontal_input()
	if move_input != 0.0:
		dodge_dir = move_input
	elif animated_sprite and animated_sprite.flip_h:
		dodge_dir = -1.0
	else:
		dodge_dir = 1.0

	change_state(State.DODGE)
	dodge_timer = DODGE_DURATION
	dodge_cooldown_timer = DODGE_COOLDOWN
	is_invulnerable = true
	invulnerable_timer = DODGE_DURATION

	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("dodge")

func use_mech_arm():
	change_state(State.MECH_ARM)
	attack_timer = 0.7
	mech_arm_cooldown = 1.5
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("mech arm_1")

func change_state(new_state: State):
	current_state = new_state
	if not animated_sprite:
		return

	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.RUN:
			animated_sprite.play("sprint")
		State.JUMP, State.FALL:
			animated_sprite.play("jump")
		State.DODGE:
			animated_sprite.play("dodge")
		State.ATTACK:
			animated_sprite.play("sword")
		State.MECH_ARM:
			animated_sprite.play("mech arm_1")
		State.PARRY:
			animated_sprite.play("parry")
		State.HURT:
			animated_sprite.play("hurt")

func _on_frame_changed():
	if current_state == State.ATTACK and animated_sprite.animation == "sword":
		if animated_sprite.frame in [2, 3, 5, 6]:
			check_sword_hit()
	elif current_state == State.MECH_ARM and animated_sprite.animation == "mech arm_1":
		if animated_sprite.frame == 3:
			execute_mech_arm_aoe()

func _on_animation_finished():
	if current_state in [State.ATTACK, State.MECH_ARM, State.PARRY, State.DODGE, State.HURT]:
		if is_on_floor():
			change_state(State.IDLE)
		else:
			change_state(State.FALL)

func check_sword_hit():
	var targets = []
	for group_name in ["boss", "enemies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not node in targets:
				targets.append(node)

	for b in targets:
		if is_instance_valid(b) and not b in current_attack_damaged:
			if "is_dead" in b and b.is_dead:
				continue
			var to_boss_x = b.global_position.x - global_position.x
			var is_facing = (to_boss_x > 0.0 and not animated_sprite.flip_h) or (to_boss_x < 0.0 and animated_sprite.flip_h)
			var dist = global_position.distance_to(b.global_position)
			if (is_facing or dist <= 45.0) and dist <= ATTACK_RANGE:
				if b.has_method("take_damage"):
					b.take_damage(ATTACK_DAMAGE)
					current_attack_damaged.append(b)

func execute_mech_arm_aoe():
	if slam_particles:
		slam_particles.global_position = global_position
		slam_particles.restart()

	shockwave_active = true
	shockwave_radius = 20.0
	shockwave_alpha = 1.0
	shockwave_center = global_position

	var targets = []
	for group_name in ["boss", "enemies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not node in targets:
				targets.append(node)

	for b in targets:
		if is_instance_valid(b):
			if "is_dead" in b and b.is_dead:
				continue
			if global_position.distance_to(b.global_position) <= MECH_ARM_RADIUS:
				if b.has_method("take_damage"):
					b.take_damage(MECH_ARM_DAMAGE)

	var tween = create_tween()
	tween.tween_property(self, "shockwave_radius", MECH_ARM_RADIUS, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "shockwave_alpha", 0.0, 0.45)
	tween.finished.connect(func(): shockwave_active = false)

func take_damage(amount: float):
	if is_invulnerable or current_state == State.DEAD:
		return

	# If parrying, negate damage and trigger spark
	if current_state == State.PARRY:
		is_invulnerable = true
		invulnerable_timer = 0.4
		return

	current_health = max(0.0, current_health - amount)
	emit_signal("health_changed", current_health, MAX_HEALTH)

	is_invulnerable = true
	invulnerable_timer = 0.6

	if current_health <= 0.0:
		die()
	else:
		change_state(State.HURT)

func die():
	current_health = 0.0
	change_state(State.DEAD)
	emit_signal("player_died")

func lock_controls():
	controls_locked = true

func unlock_controls():
	controls_locked = false

func _draw():
	if shockwave_active and shockwave_alpha > 0.0:
		var center_local = to_local(shockwave_center)
		var col = Color(0.3, 0.9, 1.0, shockwave_alpha * 0.8)
		draw_arc(center_local, shockwave_radius, 0.0, TAU, 32, col, 4.0)
