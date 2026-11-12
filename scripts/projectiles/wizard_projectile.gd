extends Area2D

@export var speed: float = 230.0
@export var damage: float = 14.0
@export var projectile_type: String = "bullet"

var direction: Vector2 = Vector2.LEFT
var lifetime: float = 4.0
var has_hit: bool = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	add_to_group("enemy_projectiles")
	collision_layer = 0
	collision_mask = 5 # 1 (Ground) + 4 (Player)
	body_entered.connect(_on_body_entered)
	
	if animated_sprite and animated_sprite.sprite_frames:
		if projectile_type == "fireball" and animated_sprite.sprite_frames.has_animation("fireball"):
			animated_sprite.play("fireball")
		elif animated_sprite.sprite_frames.has_animation("bullet"):
			animated_sprite.play("bullet")
	
	rotation = direction.angle()

func setup(pos: Vector2, dir: Vector2, p_speed: float = 230.0, p_damage: float = 14.0, p_type: String = "bullet"):
	global_position = pos
	direction = dir.normalized()
	speed = p_speed
	damage = p_damage
	projectile_type = p_type
	rotation = direction.angle()
	
	if animated_sprite and animated_sprite.sprite_frames:
		if projectile_type == "fireball" and animated_sprite.sprite_frames.has_animation("fireball"):
			animated_sprite.play("fireball")
		elif animated_sprite.sprite_frames.has_animation("bullet"):
			animated_sprite.play("bullet")

func _physics_process(delta: float):
	if has_hit:
		return
	
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		dissipate()
		return

	# Proximity guarantee check for player
	var p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p) and not p.is_dead:
		if global_position.distance_to(p.global_position) <= 24.0:
			_on_body_entered(p)
			return

func _on_body_entered(body: Node2D):
	if has_hit:
		return
	if body.is_in_group("boss") or body.is_in_group("enemies") or body.is_in_group("npcs"):
		return
	
	if body.is_in_group("player") or body.has_method("take_damage"):
		has_hit = true
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		impact()
	elif body.name == "GroundTiles" or body is StaticBody2D or body is TileMap:
		has_hit = true
		impact()

func impact():
	has_hit = true
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", scale * 1.6, 0.12)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	tween.finished.connect(func(): queue_free())

func dissipate():
	has_hit = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func(): queue_free())
