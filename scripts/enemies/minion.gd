extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

const MAX_HEALTH = 75.0
const SPEED = 70.0
const DAMAGE = 9.0
const ATTACK_RANGE = 42.0

var current_health = MAX_HEALTH
var target_player = null
var is_dead = false
var is_attacking = false
var can_act = false
var is_dormant = false
var has_hit_this_attack = false
var attack_timer = 0.0

func _ready():
	add_to_group("enemies")
	current_health = MAX_HEALTH
	collision_layer = 2
	collision_mask = 1
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.frame_changed.connect(_on_frame_changed)
	queue_redraw()

func set_dormant(dormant: bool):
	is_dormant = dormant
	can_act = not dormant
	visible = not dormant
	if dormant:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 2
		collision_mask = 1
	queue_redraw()

func activate_enemy(player_node):
	set_dormant(false)
	target_player = player_node
	can_act = true

const GROUND_Y = -14.0

func _physics_process(delta):
	velocity.y = 0.0

	if is_dead or is_dormant:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		position.y = GROUND_Y
		return

	if not can_act or not is_instance_valid(target_player):
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		position.y = GROUND_Y
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	if is_attacking:
		if animated_sprite and (animated_sprite.frame == 1 or animated_sprite.frame == 2) and not has_hit_this_attack:
			check_melee_hit()
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		position.y = GROUND_Y
		return

	var dist = global_position.distance_to(target_player.global_position)
	var dir = 1.0 if target_player.global_position.x > global_position.x else -1.0

	animated_sprite.flip_h = (dir > 0.0)

	if dist <= ATTACK_RANGE and attack_timer <= 0.0:
		start_attack()
	else:
		velocity.x = move_toward(velocity.x, dir * SPEED, 600.0 * delta)
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")

	move_and_slide()
	position.y = GROUND_Y

func start_attack():
	is_attacking = true
	has_hit_this_attack = false
	attack_timer = 1.4
	velocity.x = 0.0
	animated_sprite.stop()
	animated_sprite.play("attack")

func _on_frame_changed():
	if is_attacking and animated_sprite.animation == "attack" and (animated_sprite.frame == 1 or animated_sprite.frame == 2):
		check_melee_hit()

func check_melee_hit():
	if is_instance_valid(target_player) and not is_dead and not has_hit_this_attack:
		var dist = global_position.distance_to(target_player.global_position)
		var to_player_x = target_player.global_position.x - global_position.x
		var is_facing_player = (to_player_x > 0.0 and animated_sprite.flip_h) or (to_player_x < 0.0 and not animated_sprite.flip_h)
		if (is_facing_player or dist <= 30.0) and dist <= ATTACK_RANGE + 25.0:
			has_hit_this_attack = true
			if target_player.has_method("take_damage"):
				target_player.take_damage(DAMAGE, global_position)

func _on_animation_finished():
	if animated_sprite.animation == "attack":
		is_attacking = false
		has_hit_this_attack = false
		animated_sprite.play("walk")

func take_damage(amount):
	if is_dead or is_dormant:
		return

	current_health = max(0.0, current_health - amount)

	var tween = create_tween()
	modulate = Color(2.5, 0.3, 0.3, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)

	if target_player:
		var knock_dir = -1.0 if target_player.global_position.x > global_position.x else 1.0
		velocity.x = knock_dir * 100.0

	if current_health <= 0.0:
		die()

func die():
	is_dead = true
	can_act = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.8)
	t.finished.connect(func(): queue_free())

func _draw():
	if is_dead or is_dormant:
		return
	var shadow_pts = PackedVector2Array()
	var shadow_y = 30.0
	var rx = 12.0
	var ry = 4.0
	for i in range(16):
		var angle = i * TAU / 16.0
		shadow_pts.append(Vector2(cos(angle) * rx, shadow_y + sin(angle) * ry))
	draw_colored_polygon(shadow_pts, Color(0.0, 0.0, 0.05, 0.35))
