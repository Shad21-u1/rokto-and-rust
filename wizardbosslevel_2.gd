extends CharacterBody2D

signal health_changed(current_hp, max_hp)
signal phase_transition(next_boss_instance)
signal boss_defeated

@onready var animated_sprite = $AnimatedSprite2D

const MAX_HEALTH = 280.0
const SPEED = 95.0
const PREFERRED_MIN_DIST = 95.0
const PREFERRED_MAX_DIST = 200.0
const FLOAT_BASE_Y = -41.0 # Aligns visual bottom robe with ground surface

var current_health = MAX_HEALTH
var target_player: Node2D = null
var can_act: bool = false
var is_dead: bool = false
var is_casting: bool = false
var is_transitioning: bool = false

var cast_cooldown: float = 1.6
var cast_timer: float = 0.9
var teleport_cooldown: float = 0.0
var spell_cycle: int = 0
var float_time: float = 0.0

var projectile_scene = preload("res://wizard_projectile.tscn")
var phase3_scene = preload("res://wizardboss.tscn")

func _ready():
	add_to_group("boss")
	add_to_group("enemies")
	current_health = MAX_HEALTH
	collision_layer = 2
	collision_mask = 1
	position.y = FLOAT_BASE_Y
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	queue_redraw()

func activate_boss(player_node: Node2D):
	target_player = player_node
	can_act = true
	emit_signal("health_changed", current_health, MAX_HEALTH)
	
	var tween = create_tween()
	modulate = Color(3.2, 1.8, 0.4, 1.0) # Golden-orange arcane emergence surge
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func _physics_process(delta: float):
	if is_dead or is_transitioning:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		return
	
	# Continually float at the exact same level from ground as Grim Reaper and Phase 1
	float_time += delta
	var target_float_y = FLOAT_BASE_Y + sin(float_time * 2.2) * 3.5
	position.y = lerp(position.y, target_float_y, 8.0 * delta)
	velocity.y = 0.0
	queue_redraw()
	
	if not can_act or not is_instance_valid(target_player):
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return
	
	cast_timer -= delta
	if teleport_cooldown > 0.0:
		teleport_cooldown -= delta
	
	var dist = global_position.distance_to(target_player.global_position)
	var dir_to_player = (target_player.global_position - global_position).normalized()
	
	if animated_sprite:
		animated_sprite.flip_h = (dir_to_player.x < 0.0)
	
	if is_casting:
		velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)
	else:
		if dist < PREFERRED_MIN_DIST:
			velocity.x = move_toward(velocity.x, -dir_to_player.x * SPEED * 1.25, 500.0 * delta)
			if dist < 55.0 and teleport_cooldown <= 0.0:
				perform_teleport_escape()
		elif dist > PREFERRED_MAX_DIST:
			velocity.x = move_toward(velocity.x, dir_to_player.x * SPEED, 500.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)
	
	if cast_timer <= 0.0 and not is_casting:
		start_cast()
	
	move_and_slide()

func start_cast():
	is_casting = true
	cast_timer = cast_cooldown
	if animated_sprite and animated_sprite.sprite_frames.has_animation("cast"):
		animated_sprite.play("cast")
	
	spell_cycle += 1
	var tween = create_tween()
	if spell_cycle % 2 == 1:
		modulate = Color(2.8, 1.8, 0.5, 1.0)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.35)
		get_tree().create_timer(0.28).timeout.connect(fire_flame_barrage)
	else:
		modulate = Color(1.8, 2.5, 3.5, 1.0)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.35)
		get_tree().create_timer(0.28).timeout.connect(fire_arcane_spread)

func fire_flame_barrage():
	if is_dead or is_transitioning or not is_instance_valid(target_player):
		return
	var aim_dir = (target_player.global_position - global_position).normalized()
	var angles = [-0.15, 0.15]
	for ang in angles:
		var dir = aim_dir.rotated(ang)
		spawn_projectile(dir, 205.0, 15.0, "fireball")

func fire_arcane_spread():
	if is_dead or is_transitioning or not is_instance_valid(target_player):
		return
	var aim_dir = (target_player.global_position - global_position).normalized()
	var angles = [-0.26, 0.0, 0.26]
	for ang in angles:
		var dir = aim_dir.rotated(ang)
		spawn_projectile(dir, 240.0, 12.0, "bullet")

func spawn_projectile(dir: Vector2, speed: float, dmg: float, p_type: String):
	if projectile_scene == null:
		return
	var p = projectile_scene.instantiate()
	get_parent().add_child(p)
	var spawn_pos = global_position + Vector2(0, 0) + dir * 20.0
	p.setup(spawn_pos, dir, speed, dmg, p_type)

func perform_teleport_escape():
	teleport_cooldown = 4.0
	var escape_dir = 1.0 if (target_player.global_position.x > global_position.x) else -1.0
	var target_x = global_position.x - escape_dir * 145.0
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.1, 0.15)
	tween.tween_callback(func():
		global_position.x = target_x
		global_position.y = FLOAT_BASE_Y
	)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _on_animation_finished():
	if animated_sprite.animation == "cast":
		is_casting = false
		animated_sprite.play("idle")

func take_damage(amount: float):
	if is_dead or is_transitioning:
		return
	
	current_health = max(0.0, current_health - amount)
	emit_signal("health_changed", current_health, MAX_HEALTH)
	
	var tween = create_tween()
	modulate = Color(3.0, 0.4, 0.4, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)
	
	if current_health <= 0.0:
		transition_to_phase_3()

func transition_to_phase_3():
	is_transitioning = true
	can_act = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	
	# Dramatic phase transition animation: ascension into Archmage Form 3
	var t = create_tween().set_parallel(true)
	modulate = Color(3.5, 0.6, 2.5, 1.0)
	t.tween_property(self, "position:y", position.y - 45.0, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2(1.3, 1.3), 1.2)
	
	t.chain().tween_callback(func():
		spawn_phase_3_boss()
	)

func spawn_phase_3_boss():
	if phase3_scene:
		var p3 = phase3_scene.instantiate()
		p3.position = Vector2(position.x, -41.0) # Matches ground clearance
		get_parent().add_child(p3)
		if is_instance_valid(target_player) and p3.has_method("activate_boss"):
			p3.activate_boss(target_player)
		emit_signal("phase_transition", p3)
	
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.4)
	fade.finished.connect(func(): queue_free())

func _draw():
	if is_dead or is_transitioning:
		return
	var shadow_pts = PackedVector2Array()
	var shadow_y = 16.0 - position.y
	var rx = 20.0
	var ry = 5.5
	for i in range(16):
		var angle = i * TAU / 16.0
		shadow_pts.append(Vector2(cos(angle) * rx, shadow_y + sin(angle) * ry))
	draw_colored_polygon(shadow_pts, Color(0.0, 0.0, 0.05, 0.35))
