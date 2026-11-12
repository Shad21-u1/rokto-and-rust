extends CharacterBody2D

signal health_changed(current_hp, max_hp)
signal boss_defeated

@onready var animated_sprite = $AnimatedSprite2D

const MAX_HEALTH = 360.0
const SPEED = 105.0
const PREFERRED_MIN_DIST = 100.0
const PREFERRED_MAX_DIST = 210.0
const FLOAT_BASE_Y = -41.0 # Form 3 (Final Archmage Phase) ground clearance

var current_health = MAX_HEALTH
var target_player: Node2D = null
var can_act: bool = false
var is_dead: bool = false
var is_casting: bool = false

var cast_cooldown: float = 1.6
var cast_timer: float = 0.8
var teleport_timer: float = 4.5
var spell_cycle: int = 0
var float_time: float = 0.0

var projectile_scene = preload("res://scenes/projectiles/wizard_projectile.tscn")

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
	modulate = Color(3.5, 0.4, 2.8, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.6)

func _physics_process(delta: float):
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		return
	
	# Continually float at the exact same level from ground as Grim Reaper
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
	teleport_timer -= delta
	
	var dist = global_position.distance_to(target_player.global_position)
	var dir_to_player = (target_player.global_position - global_position).normalized()
	
	if animated_sprite:
		animated_sprite.flip_h = (dir_to_player.x < 0.0)
	
	if is_casting:
		velocity.x = move_toward(velocity.x, 0.0, 350.0 * delta)
	else:
		if dist < PREFERRED_MIN_DIST:
			velocity.x = move_toward(velocity.x, -dir_to_player.x * SPEED * 1.3, 600.0 * delta)
		elif dist > PREFERRED_MAX_DIST:
			velocity.x = move_toward(velocity.x, dir_to_player.x * SPEED, 600.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 350.0 * delta)
	
	if teleport_timer <= 0.0:
		perform_teleport_ambush()
	elif cast_timer <= 0.0 and not is_casting:
		start_cast()
	
	move_and_slide()

func start_cast():
	is_casting = true
	cast_timer = cast_cooldown
	if animated_sprite and animated_sprite.sprite_frames.has_animation("cast"):
		animated_sprite.play("cast")
	
	spell_cycle += 1
	var tween = create_tween()
	if spell_cycle % 2 == 0:
		modulate = Color(3.5, 1.4, 0.4, 1.0)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.35)
		get_tree().create_timer(0.3).timeout.connect(fire_flameball_barrage)
	else:
		modulate = Color(2.5, 0.5, 3.5, 1.0)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.35)
		get_tree().create_timer(0.3).timeout.connect(fire_void_nova)

func fire_flameball_barrage():
	if is_dead or not is_instance_valid(target_player):
		return
	var aim_dir = (target_player.global_position - global_position).normalized()
	var angles = [-0.18, 0.0, 0.18]
	for ang in angles:
		var dir = aim_dir.rotated(ang)
		spawn_projectile(dir, 190.0, 16.0, "fireball")

func fire_void_nova():
	if is_dead or not is_instance_valid(target_player):
		return
	var aim_dir = (target_player.global_position - global_position).normalized()
	var angles = [-0.35, -0.17, 0.0, 0.17, 0.35]
	for ang in angles:
		var dir = aim_dir.rotated(ang)
		spawn_projectile(dir, 240.0, 10.0, "bullet")

func spawn_projectile(dir: Vector2, speed: float, dmg: float, p_type: String):
	if projectile_scene == null:
		return
	var p = projectile_scene.instantiate()
	get_parent().add_child(p)
	var spawn_pos = global_position + Vector2(0, 0) + dir * 22.0
	p.setup(spawn_pos, dir, speed, dmg, p_type)

func perform_teleport_ambush():
	teleport_timer = randf_range(4.0, 6.0)
	if not is_instance_valid(target_player):
		return
	
	var behind_dir = -1.0 if (target_player.global_position.x > global_position.x) else 1.0
	var new_x = target_player.global_position.x + behind_dir * 130.0
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func():
		global_position.x = new_x
		global_position.y = FLOAT_BASE_Y
		modulate = Color(3.0, 0.6, 2.5, 0.0)
	)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.22)

func _on_animation_finished():
	if animated_sprite.animation == "cast":
		is_casting = false
		animated_sprite.play("idle")

func take_damage(amount: float):
	if is_dead:
		return
	
	current_health = max(0.0, current_health - amount)
	emit_signal("health_changed", current_health, MAX_HEALTH)
	
	var tween = create_tween()
	modulate = Color(3.5, 0.3, 0.5, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)
	
	if current_health <= 0.0:
		die()

func die():
	is_dead = true
	can_act = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	emit_signal("boss_defeated")
	
	var death_tween = create_tween().set_parallel(true)
	modulate = Color(2.5, 0.2, 0.2, 1.0)
	death_tween.tween_property(self, "modulate:a", 0.0, 1.5)
	death_tween.tween_property(self, "scale", Vector2(0.2, 2.0), 1.5)
	death_tween.chain().tween_callback(func(): queue_free())

func _draw():
	if is_dead:
		return
	var shadow_pts = PackedVector2Array()
	var shadow_y = 16.0 - position.y
	var rx = 18.0
	var ry = 5.0
	for i in range(16):
		var angle = i * TAU / 16.0
		shadow_pts.append(Vector2(cos(angle) * rx, shadow_y + sin(angle) * ry))
	draw_colored_polygon(shadow_pts, Color(0.05, 0.0, 0.05, 0.45))
