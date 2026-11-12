extends Node2D

@onready var animated_sprite = $AnimatedSprite2D

const FLOAT_BASE_Y = -29.0
var initial_y = FLOAT_BASE_Y
var time = 0.0

func _ready():
	position.y = FLOAT_BASE_Y
	initial_y = FLOAT_BASE_Y
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("move left"):
			animated_sprite.play("move left")
		else:
			animated_sprite.play("idle")
	queue_redraw()

func _process(delta):
	time += delta
	position.y = initial_y + sin(time * 2.2) * 3.5
	queue_redraw()

func _draw():
	var shadow_pts = PackedVector2Array()
	var shadow_y = 16.0 - position.y
	var rx = 15.0
	var ry = 5.0
	for i in range(16):
		var angle = i * TAU / 16.0
		shadow_pts.append(Vector2(cos(angle) * rx, shadow_y + sin(angle) * ry))
	draw_colored_polygon(shadow_pts, Color(0.01, 0.0, 0.04, 0.45))
