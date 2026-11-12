extends CharacterBody2D

signal health_changed(current_hp, max_hp)
signal player_died

@onready var animated_sprite = $AnimatedSprite2D

const CHARACTER_NAME = "Nabab AKA N'"

const MAX_HITS = 8
const MAX_HEALTH = 8.0
const ATTACK_DAMAGE = 35.0
const ATTACK_RANGE = 95.0
const MECH_ARM_DAMAGE = 55.0
const MECH_ARM_RADIUS = 135.0

const WALK_SPEED = 120.0
const SPRINT_SPEED = 230.0
const DODGE_SPEED = 270.0
const ACCELERATION = 1100.0
const FRICTION = 2600.0

var current_health = MAX_HEALTH
var is_dead = false
var is_taunting = false
var is_attacking = false
var is_dodging = false
var controls_locked = false
var invulnerable_timer = 0.0
var mech_arm_cooldown = 0.0
var current_mech_arm_damaged: Array = []
var dodge_safety_timer = 0.0
var attack_safety_timer = 0.0
var mech_arm_safety_timer = 0.0
var has_executed_mech_arm_aoe: bool = false

var shockwave_active = false
var shockwave_radius = 12.0
var shockwave_alpha = 1.0
var shockwave_center = Vector2.ZERO
var shockwave_fissures: Array = []
var slam_particles: CPUParticles2D = null

var dodge_direction = 1.0

func _ready():
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	current_health = MAX_HEALTH

	# Dynamic AOE slam impact particles
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
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)
		if animated_sprite.sprite_frames:
			for anim in ["sword", "mech arm_1", "dodge"]:
				if animated_sprite.sprite_frames.has_animation(anim):
					animated_sprite.sprite_frames.set_animation_loop(anim, false)
			for anim in ["idle", "walk", "sprint"]:
				if animated_sprite.sprite_frames.has_animation(anim):
					animated_sprite.sprite_frames.set_animation_loop(anim, true)

	play_anim("idle")
	queue_redraw()
	emit_signal("health_changed", current_health, MAX_HEALTH)

func _physics_process(delta):
	velocity.y = 0.0

	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	if mech_arm_cooldown > 0.0:
		mech_arm_cooldown -= delta

	if shockwave_active:
		queue_redraw()

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		position.y = 0.0
		return

	if controls_locked:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		play_anim("idle")
		move_and_slide()
		position.y = 0.0
		return

	if is_dodging:
		dodge_safety_timer -= delta
		if dodge_safety_timer <= 0.0:
			is_dodging = false
			velocity.x = 0.0
		else:
			velocity.x = move_toward(velocity.x, dodge_direction * DODGE_SPEED, ACCELERATION * delta)
			move_and_slide()
			position.y = 0.0
			return

	if is_attacking:
		attack_safety_timer -= delta
		if attack_safety_timer <= 0.0:
			is_attacking = false
			velocity.x = 0.0
			current_attack_damaged.clear()
		else:
			if animated_sprite and animated_sprite.animation == "sword" and animated_sprite.frame >= 2 and animated_sprite.frame <= 6:
				check_sword_hit()
			velocity.x = 0.0
			move_and_slide()
			position.y = 0.0
			return

	if is_taunting:
		mech_arm_safety_timer -= delta
		if mech_arm_safety_timer <= 0.0:
			is_taunting = false
			velocity.x = 0.0
			current_mech_arm_damaged.clear()
			has_executed_mech_arm_aoe = false
			if animated_sprite:
				animated_sprite.speed_scale = 1.0
		else:
			if animated_sprite and animated_sprite.animation == "mech arm_1":
				if animated_sprite.frame >= 3 and not has_executed_mech_arm_aoe:
					has_executed_mech_arm_aoe = true
					execute_mech_arm_aoe()
				elif has_executed_mech_arm_aoe and animated_sprite.frame <= 6:
					check_mech_arm_ongoing_hit()
			velocity.x = 0.0
			move_and_slide()
			position.y = 0.0
			return

	var move_input = 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("walk") or Input.is_action_pressed("ui_right"):
		move_input += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		move_input -= 1.0

	var is_sprinting = Input.is_key_pressed(KEY_SHIFT)

	if move_input != 0.0:
		var target_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
		velocity.x = move_toward(velocity.x, move_input * target_speed, ACCELERATION * delta)
		animated_sprite.flip_h = (move_input < 0.0)
		play_anim("sprint" if is_sprinting else "walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if abs(velocity.x) < 3.0:
			velocity.x = 0.0
		play_anim("idle")

	move_and_slide()
	position.y = 0.0

func _unhandled_input(event):
	if is_dead:
		return

	if controls_locked:
		return

	if event.is_action_pressed("sword") or (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
		if can_act():
			attack()
			return

	if event.is_action_pressed("mech arm_1") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_T or event.keycode == KEY_K)):
		if can_act() and mech_arm_cooldown <= 0.0:
			use_mech_arm()
			return

	if event.is_action_pressed("dodge") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_M or event.keycode == KEY_SPACE or event.keycode == KEY_C)):
		if can_act():
			dodge()
			return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_J and can_act():
			attack()
			return

func can_act():
	return not is_dead and not is_attacking and not is_taunting and not is_dodging and not controls_locked

var current_attack_damaged: Array = []

func attack():
	is_attacking = true
	attack_safety_timer = 0.7
	velocity.x = 0.0
	current_attack_damaged.clear()
	animated_sprite.stop()
	animated_sprite.play("sword")

func _on_frame_changed():
	if is_attacking and animated_sprite.animation == "sword" and animated_sprite.frame >= 2 and animated_sprite.frame <= 6:
		check_sword_hit()
	elif is_taunting and animated_sprite.animation == "mech arm_1":
		if animated_sprite.frame >= 3 and not has_executed_mech_arm_aoe:
			has_executed_mech_arm_aoe = true
			execute_mech_arm_aoe()

func check_sword_hit():
	var targets = []
	for node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(node) and not node in targets:
			targets.append(node)
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and not node in targets:
			targets.append(node)
	if get_parent():
		for child in get_parent().get_children():
			if is_instance_valid(child) and child != self and not child in targets:
				if child.has_method("take_damage") and not child.is_in_group("player") and not child.is_in_group("npcs"):
					targets.append(child)

	for b in targets:
		if is_instance_valid(b) and not b in current_attack_damaged:
			if "is_dead" in b and b.is_dead:
				continue
			if "is_dormant" in b and b.is_dormant:
				continue
			var to_boss_x = b.global_position.x - global_position.x
			var is_facing_boss = (to_boss_x > 0.0 and not animated_sprite.flip_h) or (to_boss_x < 0.0 and animated_sprite.flip_h)
			var x_dist = abs(to_boss_x)
			var y_dist = abs(b.global_position.y - global_position.y)
			var dist = global_position.distance_to(b.global_position)
			if (is_facing_boss or dist <= 55.0 or x_dist <= 65.0) and (dist <= ATTACK_RANGE + 45.0 or (x_dist <= ATTACK_RANGE + 35.0 and y_dist <= 95.0)):
				if b.has_method("take_damage"):
					b.take_damage(ATTACK_DAMAGE)
					current_attack_damaged.append(b)

func take_damage(_amount = 1.0, from_pos = Vector2.ZERO):
	if is_dead or is_dodging or invulnerable_timer > 0.0:
		return

	invulnerable_timer = 0.6 # Brief i-frame window
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

func taunt():
	use_mech_arm()

func use_mech_arm():
	if mech_arm_cooldown > 0.0:
		return
	is_taunting = true
	mech_arm_cooldown = 1.2
	mech_arm_safety_timer = 0.95
	has_executed_mech_arm_aoe = false
	velocity.x = 0.0
	current_mech_arm_damaged.clear()
	
	if animated_sprite:
		animated_sprite.speed_scale = 1.15
		animated_sprite.stop()
		animated_sprite.play("mech arm_1")
	
	# Cybernetic windup charge flash
	var windup_tween = create_tween()
	modulate = Color(0.65, 1.8, 2.6, 1.0)
	windup_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.22)

func execute_mech_arm_aoe():
	trigger_shockwave_fx()
	trigger_screen_shake(8.0, 0.25)
	
	# Kinetic ground slam flash on player
	var slam_tween = create_tween()
	modulate = Color(1.8, 3.5, 4.5, 1.0)
	slam_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.26)
	
	check_mech_arm_ongoing_hit()

func check_mech_arm_ongoing_hit():
	if not is_inside_tree() or not get_tree():
		return
	var targets = []
	for node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(node) and not node in targets:
			targets.append(node)
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and not node in targets:
			targets.append(node)
	if get_parent():
		for child in get_parent().get_children():
			if is_instance_valid(child) and child != self and not child in targets:
				if child.has_method("take_damage") and not child.is_in_group("player") and not child.is_in_group("npcs"):
					targets.append(child)

	for b in targets:
		if is_instance_valid(b) and not b in current_mech_arm_damaged:
			if "is_dead" in b and b.is_dead:
				continue
			if "is_dormant" in b and b.is_dormant:
				continue

			var dist = global_position.distance_to(b.global_position)
			var x_dist = abs(b.global_position.x - global_position.x)
			var y_dist = abs(b.global_position.y - global_position.y)

			if dist <= MECH_ARM_RADIUS or (x_dist <= MECH_ARM_RADIUS + 30.0 and y_dist <= 80.0):
				current_mech_arm_damaged.append(b)
				
				# 1. High impact AOE Damage
				if b.has_method("take_damage"):
					b.take_damage(MECH_ARM_DAMAGE)

				# 2. Crowd Control (CC) & Throw Enemies Away
				apply_mech_arm_cc(b)

func apply_mech_arm_cc(b: Node2D):
	if not is_instance_valid(b):
		return

	# Calculate horizontal throw direction away from player
	var dir_x = 1.0 if b.global_position.x >= global_position.x else -1.0
	if abs(b.global_position.x - global_position.x) < 4.0:
		dir_x = -1.0 if (animated_sprite and animated_sprite.flip_h) else 1.0

	var b_name_str = String(b.name).to_lower()
	var is_boss_enemy = b.is_in_group("boss") or "boss" in b_name_str or "allmind" in b_name_str or "wizard" in b_name_str or "darksaber" in b_name_str
	var throw_dist = 75.0 if is_boss_enemy else 145.0
	var throw_velocity = 240.0 if is_boss_enemy else 400.0

	# 1. Physical displacement velocity
	if "velocity" in b:
		b.velocity.x = dir_x * throw_velocity

	# 2. Smooth physical throw-back tween
	var launch_tween = b.create_tween()
	var target_x = b.global_position.x + dir_x * throw_dist
	launch_tween.tween_property(b, "global_position:x", target_x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3. Crowd control: interrupt ongoing attack and stagger
	if "attack_timer" in b:
		b.attack_timer = max(b.attack_timer, 1.0)
	if "is_attacking" in b:
		b.is_attacking = false
	if "has_hit_this_attack" in b:
		b.has_hit_this_attack = true

	# 4. Electric / kinetic CC visual flash
	var flash_tween = b.create_tween()
	b.modulate = Color(0.2, 3.0, 3.5, 1.0) # Bright kinetic electric surge
	flash_tween.tween_property(b, "modulate", Color(1, 1, 1, 1), 0.3)

func trigger_shockwave_fx():
	shockwave_active = true
	shockwave_radius = 10.0
	shockwave_alpha = 1.0
	shockwave_center = Vector2(-8.0 if (animated_sprite and animated_sprite.flip_h) else 8.0, 14.0)
	
	# Generate ground fissure crack lines
	shockwave_fissures.clear()
	var pts_l = PackedVector2Array()
	var cur = shockwave_center
	pts_l.append(cur)
	for i in range(5):
		cur += Vector2(-randf_range(18.0, 28.0), randf_range(-3.5, 3.5))
		pts_l.append(cur)
	shockwave_fissures.append(pts_l)

	var pts_r = PackedVector2Array()
	cur = shockwave_center
	pts_r.append(cur)
	for i in range(5):
		cur += Vector2(randf_range(18.0, 28.0), randf_range(-3.5, 3.5))
		pts_r.append(cur)
	shockwave_fissures.append(pts_r)
	
	if slam_particles:
		slam_particles.position = shockwave_center
		slam_particles.restart()
		slam_particles.emitting = true
	
	var sw_tween = create_tween().set_parallel(true)
	sw_tween.tween_property(self, "shockwave_radius", MECH_ARM_RADIUS, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	sw_tween.tween_property(self, "shockwave_alpha", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sw_tween.chain().tween_callback(func():
		shockwave_active = false
		shockwave_fissures.clear()
		queue_redraw()
	)

func trigger_screen_shake(intensity: float = 8.0, duration: float = 0.25):
	var cam: Camera2D = null
	if is_inside_tree():
		var vp = get_viewport()
		if vp:
			cam = vp.get_camera_2d()
	if not cam and get_parent():
		cam = get_parent().get_node_or_null("EYES")
	if cam:
		var orig_offset = cam.offset
		var st = create_tween()
		st.tween_method(func(val: float):
			var cur = intensity * val
			if is_instance_valid(cam):
				cam.offset = Vector2(randf_range(-cur, cur), randf_range(-cur * 0.6, cur * 0.6))
		, 1.0, 0.0, duration)
		st.tween_callback(func():
			if is_instance_valid(cam):
				cam.offset = orig_offset
		)

func dodge():
	is_dodging = true
	dodge_safety_timer = 0.45
	if animated_sprite:
		dodge_direction = -1.0 if animated_sprite.flip_h else 1.0
		animated_sprite.stop()
		animated_sprite.play("dodge")

func die():
	is_dead = true
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("dodge")
	emit_signal("player_died")

func reset_player(spawn_pos: Vector2 = Vector2(-400.0, 0.0)):
	is_dead = false
	is_dodging = false
	is_attacking = false
	is_taunting = false
	has_executed_mech_arm_aoe = false
	controls_locked = false
	invulnerable_timer = 0.0
	current_health = MAX_HEALTH
	velocity = Vector2.ZERO
	global_position = spawn_pos
	modulate = Color(1, 1, 1, 1)
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
	play_anim("idle")
	emit_signal("health_changed", current_health, MAX_HEALTH)

func play_anim(anim_name):
	if animated_sprite and animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _on_animation_finished():
	if is_dead:
		return

	if animated_sprite.animation == "sword":
		is_attacking = false
		velocity.x = 0.0
		current_attack_damaged.clear()
	elif animated_sprite.animation == "mech arm_1":
		is_taunting = false
		has_executed_mech_arm_aoe = false
		if animated_sprite:
			animated_sprite.speed_scale = 1.0
		velocity.x = 0.0
		current_mech_arm_damaged.clear()
	elif animated_sprite.animation == "dodge":
		is_dodging = false
		velocity.x = 0.0

	if not controls_locked:
		var moving = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_LEFT)
		var sprinting = Input.is_key_pressed(KEY_SHIFT)
		if moving:
			play_anim("sprint" if sprinting else "walk")
		else:
			play_anim("idle")
	else:
		play_anim("idle")

func lock_controls():
	controls_locked = true
	velocity = Vector2.ZERO
	play_anim("idle")

func unlock_controls():
	controls_locked = false

func _draw():
	var shadow_pts = PackedVector2Array()
	var shadow_y = 16.0
	var rx = 9.0
	var ry = 3.5
	for i in range(16):
		var angle = i * TAU / 16.0
		shadow_pts.append(Vector2(cos(angle) * rx, shadow_y + sin(angle) * ry))
	draw_colored_polygon(shadow_pts, Color(0.0, 0.0, 0.05, 0.35))

	if shockwave_active and shockwave_alpha > 0.0:
		# 1. Primary outer electric plasma shockwave (Electric Cyan)
		var cyan_col = Color(0.2, 0.95, 1.0, shockwave_alpha * 0.95)
		draw_arc(shockwave_center, shockwave_radius, 0, TAU, 36, cyan_col, 3.5)

		# 2. Secondary solar-gold shockwave ring
		if shockwave_radius > 16.0:
			var gold_col = Color(1.0, 0.85, 0.25, shockwave_alpha * 0.8)
			draw_arc(shockwave_center, shockwave_radius * 0.72, 0, TAU, 30, gold_col, 2.5)

		# 3. Inner core energy flash disc
		if shockwave_radius > 22.0:
			var core_col = Color(0.65, 0.92, 1.0, shockwave_alpha * 0.28)
			draw_circle(shockwave_center, shockwave_radius * 0.38, core_col)

		# 4. Radiating electric lightning arcs
		for i in range(8):
			var ang = i * TAU / 8.0 + (shockwave_radius * 0.02)
			var p_inner = shockwave_center + Vector2(cos(ang), sin(ang)) * (shockwave_radius * 0.38)
			var p_outer = shockwave_center + Vector2(cos(ang), sin(ang)) * shockwave_radius
			var p_mid = (p_inner + p_outer) * 0.5 + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
			draw_polyline(PackedVector2Array([p_inner, p_mid, p_outer]), Color(0.35, 0.95, 1.0, shockwave_alpha * 0.7), 1.5)

		# 5. Jagged ground fissures with glowing ember cracks
		for fissure in shockwave_fissures:
			if fissure is PackedVector2Array and fissure.size() > 1:
				draw_polyline(fissure, Color(1.0, 0.82, 0.3, shockwave_alpha * 0.85), 2.2)
