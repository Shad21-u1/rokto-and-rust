extends CharacterBody2D

signal health_changed(current_hp, max_hp)
signal player_died

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const CHARACTER_NAME = "Nabab AKA N'"

# Combat stats
const MAX_HEALTH: float = 5.0
const ATTACK_DAMAGE: float = 35.0
const ATTACK_RANGE: float = 95.0
const MECH_ARM_DAMAGE: float = 55.0
const MECH_ARM_RADIUS: float = 140.0

# Movement physics
const MOVE_SPEED: float = 210.0
const DODGE_SPEED: float = 320.0
const JUMP_VELOCITY: float = -420.0
const GRAVITY: float = 1100.0
const ACCELERATION: float = 1600.0
const FRICTION: float = 2400.0
const AIR_ACCEL: float = 1100.0

# States enum
enum State {
	IDLE,
	WALK,
	SPRINT,
	JUMP,
	DODGE,
	ATTACK,
	MECH_ARM,
	PARRY,
	HURT,
	DEAD
}

var current_state: State = State.IDLE
var current_health: float = MAX_HEALTH
var is_dead: bool = false
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0
var controls_locked: bool = false

# Compatibility flags for level scripts
var is_attacking: bool = false
var is_dodging: bool = false
var is_taunting: bool = false

# Action timers
var dodge_timer: float = 0.0
var dodge_dir: float = 1.0
var attack_timer: float = 0.0
var mech_arm_cooldown: float = 0.0

# Combat targets
var current_attack_damaged: Array = []
var shockwave_active: bool = false
var shockwave_radius: float = 16.0
var shockwave_alpha: float = 1.0
var shockwave_center: Vector2 = Vector2.ZERO

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

	visible = true
	change_state(State.IDLE)
	position.y = 0.0
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

	if is_dead or current_state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		_apply_gravity(delta)
		move_and_slide()
		_clamp_ground()
		return

	if controls_locked:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		_apply_gravity(delta)
		if current_state != State.IDLE and position.y >= 0.0:
			change_state(State.IDLE)
		move_and_slide()
		_clamp_ground()
		return

	# State physics
	match current_state:
		State.IDLE, State.WALK, State.SPRINT:
			_handle_ground_movement(delta)

		State.JUMP:
			_handle_air_movement(delta)

		State.DODGE:
			velocity.x = dodge_dir * DODGE_SPEED
			dodge_timer -= delta
			if dodge_timer <= 0.0:
				is_dodging = false
				is_invulnerable = false
				if position.y >= 0.0:
					change_state(State.IDLE)
				else:
					change_state(State.JUMP)

		State.ATTACK, State.MECH_ARM, State.PARRY:
			if position.y >= 0.0:
				velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, AIR_ACCEL * 0.5 * delta)
			attack_timer -= delta
			if attack_timer <= 0.0:
				is_attacking = false
				is_taunting = false
				if position.y >= 0.0:
					change_state(State.IDLE)
				else:
					change_state(State.JUMP)

		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# Apply gravity whenever off the ground
	_apply_gravity(delta)

	move_and_slide()
	_clamp_ground()

func _apply_gravity(delta: float):
	if position.y < 0.0 or not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _clamp_ground():
	if position.y >= 0.0:
		position.y = 0.0
		if velocity.y > 0.0:
			velocity.y = 0.0
		if current_state == State.JUMP:
			var move_input = _get_horizontal_input()
			if move_input != 0.0:
				change_state(State.SPRINT)
			else:
				change_state(State.IDLE)

func _update_timers(delta: float):
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0 and current_state != State.DODGE:
			is_invulnerable = false

	if mech_arm_cooldown > 0.0:
		mech_arm_cooldown -= delta

func _get_horizontal_input() -> float:
	var move = 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right") or (InputMap.has_action("walk") and Input.is_action_pressed("walk")):
		move += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		move -= 1.0
	return move

func _handle_ground_movement(delta: float):
	var move_input = _get_horizontal_input()

	if move_input != 0.0:
		velocity.x = move_toward(velocity.x, move_input * MOVE_SPEED, ACCELERATION * delta)
		if animated_sprite:
			animated_sprite.flip_h = (move_input < 0.0)
		if current_state != State.SPRINT:
			change_state(State.SPRINT)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if abs(velocity.x) < 5.0:
			velocity.x = 0.0
			if current_state != State.IDLE:
				change_state(State.IDLE)

func _handle_air_movement(delta: float):
	var move_input = _get_horizontal_input()
	if move_input != 0.0:
		velocity.x = move_toward(velocity.x, move_input * MOVE_SPEED, AIR_ACCEL * delta)
		if animated_sprite:
			animated_sprite.flip_h = (move_input < 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, AIR_ACCEL * 0.4 * delta)

	# Keep jump animation in sync with vertical velocity
	if animated_sprite and animated_sprite.animation == "jump":
		if velocity.y < -100.0:
			animated_sprite.frame = min(2, animated_sprite.frame)
		elif velocity.y >= -100.0 and velocity.y <= 100.0:
			animated_sprite.frame = 3
		elif velocity.y > 100.0:
			animated_sprite.frame = 4

func _unhandled_input(event: InputEvent):
	if controls_locked or is_dead or current_state == State.DEAD:
		return

	# Jump: Space button (or W / ui_up)
	if (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_SPACE or event.keycode == KEY_W)) or event.is_action_pressed("ui_up") or (InputMap.has_action("jump") and event.is_action_pressed("jump")):
		if can_jump():
			jump()
			return

	# Dash / Dodge: Shift button (or M / C)
	if (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_SHIFT or event.keycode == KEY_M or event.keycode == KEY_C)) or (InputMap.has_action("dodge") and event.is_action_pressed("dodge")):
		if can_act():
			dodge()
			return

	# Attack: LMB or J
	if (InputMap.has_action("sword") and event.is_action_pressed("sword")) or (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_J):
		if can_attack():
			attack()
			return

	# Mech Arm Overdrive: T or K
	if (InputMap.has_action("mech arm_1") and event.is_action_pressed("mech arm_1")) or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_T or event.keycode == KEY_K)):
		if can_act() and mech_arm_cooldown <= 0.0:
			use_mech_arm()
			return

	# Parry Shield: RMB or E
	if (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_E) or (InputMap.has_action("parry") and event.is_action_pressed("parry")):
		if can_act():
			parry()
			return

func can_act() -> bool:
	return current_state in [State.IDLE, State.WALK, State.SPRINT, State.JUMP] and not controls_locked and not is_dead

func can_jump() -> bool:
	return (position.y >= 0.0 or is_on_floor() or current_state in [State.IDLE, State.WALK, State.SPRINT]) and not controls_locked and not is_dead

func can_attack() -> bool:
	return current_state in [State.IDLE, State.WALK, State.SPRINT, State.JUMP] and not controls_locked and not is_dead

func jump():
	change_state(State.JUMP)
	velocity.y = JUMP_VELOCITY
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("jump")

func attack():
	change_state(State.ATTACK)
	is_attacking = true
	attack_timer = 0.65
	current_attack_damaged.clear()
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("sword")

func parry():
	change_state(State.PARRY)
	attack_timer = 0.35
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
	is_dodging = true
	dodge_timer = 0.38
	is_invulnerable = true
	invulnerable_timer = 0.38

	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("dodge")

func use_mech_arm():
	change_state(State.MECH_ARM)
	is_taunting = true
	attack_timer = 0.6
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
		State.WALK:
			animated_sprite.play("walk")
		State.SPRINT:
			animated_sprite.play("sprint")
		State.JUMP:
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
		State.DEAD:
			animated_sprite.play("dead")

func _on_frame_changed():
	if current_state == State.ATTACK and animated_sprite.animation == "sword":
		if animated_sprite.frame in [2, 3, 5, 6]:
			check_sword_hit()
	elif current_state == State.MECH_ARM and animated_sprite.animation == "mech arm_1":
		if animated_sprite.frame == 3:
			execute_mech_arm_aoe()

func _on_animation_finished():
	if current_state in [State.ATTACK, State.MECH_ARM, State.PARRY, State.DODGE, State.HURT]:
		is_attacking = false
		is_dodging = false
		is_taunting = false
		if position.y >= 0.0:
			change_state(State.IDLE)
		else:
			change_state(State.JUMP)

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

func take_damage(_amount = 1.0, from_pos = Vector2.ZERO):
	if is_invulnerable or is_dead or current_state == State.DEAD:
		return

	if current_state == State.PARRY:
		is_invulnerable = true
		invulnerable_timer = 0.4
		return

	invulnerable_timer = 0.6
	is_invulnerable = true
	current_health = max(0.0, current_health - 1.0)
	emit_signal("health_changed", current_health, MAX_HEALTH)

	var tween = create_tween()
	modulate = Color(3.5, 0.2, 0.2, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.28)

	if from_pos != Vector2.ZERO:
		var knock_dir = 1.0 if global_position.x > from_pos.x else -1.0
		velocity.x = knock_dir * 50.0

	if current_health <= 0.0:
		die()
	else:
		change_state(State.HURT)

func die():
	is_dead = true
	current_health = 0.0
	change_state(State.DEAD)
	emit_signal("player_died")

func lock_controls():
	controls_locked = true

func unlock_controls():
	controls_locked = false

func play_anim(anim_name: String):
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _draw():
	if shockwave_active and shockwave_alpha > 0.0:
		var center_local = to_local(shockwave_center)
		var col = Color(0.3, 0.9, 1.0, shockwave_alpha * 0.8)
		draw_arc(center_local, shockwave_radius, 0.0, TAU, 32, col, 4.0)
