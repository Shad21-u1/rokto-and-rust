extends CharacterBody2D

signal health_changed(current_hp, max_hp)
signal darksaber_cinematic_end
signal darksaber_defeated

@onready var animated_sprite = $AnimatedSprite2D

const MAX_HEALTH = 650.0
const SPEED = 130.0
const RUN_SPEED = 240.0
const ATTACK_RANGE = 90.0
const DAMAGE = 1.0 # Takes 1 hit from player's 5 hits

var current_health = MAX_HEALTH
var target_player: Node2D = null
var can_act: bool = false
var is_attacking: bool = false
var is_howling: bool = false
var is_dead: bool = false
var has_hit_this_attack: bool = false
var attack_timer: float = 0.0
var battle_time: float = 0.0
var fatal_strike_triggered: bool = false

const GROUND_Y = -34.0

func _ready():
	add_to_group("boss")
	add_to_group("enemies")
	current_health = MAX_HEALTH
	collision_layer = 2
	collision_mask = 1
	position.y = GROUND_Y
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.frame_changed.connect(_on_frame_changed)
	queue_redraw()

func activate_boss(player_node: Node2D):
	target_player = player_node
	can_act = true
	current_health = MAX_HEALTH
	emit_signal("health_changed", current_health, MAX_HEALTH)
	
	# Start encounter with Howl roar!
	play_howl()

func play_howl():
	is_howling = true
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.play("howl")
	var tween = create_tween()
	modulate = Color(2.5, 0.4, 0.6, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.6)

func _physics_process(delta: float):
	velocity.y = 0.0
	
	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		position.y = GROUND_Y
		return

	if not can_act or not is_instance_valid(target_player):
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		position.y = GROUND_Y
		return
	
	battle_time += delta
	if attack_timer > 0.0:
		attack_timer -= delta
	
	if is_howling:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		position.y = GROUND_Y
		return
	
	if is_attacking:
		if animated_sprite and animated_sprite.frame >= 5 and animated_sprite.frame <= 11 and not has_hit_this_attack:
			check_melee_hit()
		var lunge = 1.0 if not animated_sprite.flip_h else -1.0
		velocity.x = move_toward(velocity.x, lunge * 85.0, 300.0 * delta)
		move_and_slide()
		position.y = GROUND_Y
		return
	
	var dist = global_position.distance_to(target_player.global_position)
	var dir_to_player = (target_player.global_position - global_position).normalized()
	
	if animated_sprite:
		animated_sprite.flip_h = (dir_to_player.x < 0.0)
	
	if dist <= ATTACK_RANGE and attack_timer <= 0.0:
		start_attack()
	elif dist > ATTACK_RANGE * 1.5:
		# Run toward player aggressively
		velocity.x = move_toward(velocity.x, dir_to_player.x * RUN_SPEED, 800.0 * delta)
		if animated_sprite.animation != "run":
			animated_sprite.play("run")
	elif dist > ATTACK_RANGE * 0.7:
		velocity.x = move_toward(velocity.x, dir_to_player.x * SPEED, 700.0 * delta)
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")
	
	move_and_slide()
	position.y = GROUND_Y

func start_attack():
	is_attacking = true
	has_hit_this_attack = false
	attack_timer = 1.3
	velocity.x = 0.0
	animated_sprite.stop()
	animated_sprite.play("attack")

func _on_frame_changed():
	if is_attacking and animated_sprite.animation == "attack" and (animated_sprite.frame >= 6 and animated_sprite.frame <= 11):
		check_melee_hit()

func check_melee_hit():
	if not is_instance_valid(target_player) or is_dead or has_hit_this_attack:
		return
	var dist = global_position.distance_to(target_player.global_position)
	var to_player_x = target_player.global_position.x - global_position.x
	var is_facing_player = (to_player_x > 0.0 and not animated_sprite.flip_h) or (to_player_x < 0.0 and animated_sprite.flip_h)
	if (is_facing_player or dist <= 50.0) and dist <= ATTACK_RANGE + 40.0:
		has_hit_this_attack = true
		if target_player.has_method("take_damage"):
			target_player.take_damage(DAMAGE, global_position)

func take_damage(amount: float):
	if is_dead:
		return
	
	current_health = max(0.0, current_health - amount)
	emit_signal("health_changed", current_health, MAX_HEALTH)
	
	var tween = create_tween()
	modulate = Color(3.0, 0.3, 0.3, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.22)
	
	if current_health <= 0.0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	can_act = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	
	emit_signal("darksaber_defeated")
	
	if animated_sprite:
		animated_sprite.stop()
	var t = create_tween().set_parallel(true)
	t.tween_property(self, "modulate", Color(4.0, 0.2, 0.2, 0.0), 1.3)
	t.tween_property(self, "scale", Vector2(1.5, 0.1), 1.3)

func trigger_fatal_void_strike():
	if is_dead:
		return
	fatal_strike_triggered = true
	can_act = false
	velocity = Vector2.ZERO
	
	# Flash red and howl
	animated_sprite.play("howl")
	var t = create_tween()
	modulate = Color(4.0, 0.1, 0.3, 1.0)
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)
	
	# Teleport slash through player
	t.chain().tween_callback(func():
		if is_instance_valid(target_player):
			var lunge_x = target_player.global_position.x + (25.0 if target_player.global_position.x > global_position.x else -25.0)
			global_position.x = lunge_x
			animated_sprite.play("attack")
			if target_player.has_method("die"):
				target_player.die()
			emit_signal("darksaber_cinematic_end")
	)

func _on_animation_finished():
	if animated_sprite.animation == "attack":
		is_attacking = false
		has_hit_this_attack = false
		animated_sprite.play("idle")
	elif animated_sprite.animation == "howl":
		is_howling = false
		animated_sprite.play("idle")

func _draw():
	var shadow_pts = PackedVector2Array()
	var shadow_y = 38.0
	var rx = 24.0
	var ry = 7.0
	for i in range(16):
		var angle = i * TAU / 16.0
		shadow_pts.append(Vector2(cos(angle) * rx, shadow_y + sin(angle) * ry))
	draw_colored_polygon(shadow_pts, Color(0.01, 0.04, 0.02, 0.45))
