extends CharacterBody2D

signal spoken
signal departed

@onready var animated_sprite = $AnimatedSprite2D
@onready var interaction_area = $InteractionArea
@onready var prompt_label = $PromptLabel

var is_player_near: bool = false
var has_talked: bool = false
var is_departing: bool = false
var player_ref: Node2D = null
var float_time: float = 0.0
var initial_y: float = 0.0

func _ready():
	add_to_group("npcs")
	initial_y = position.y
	
	if animated_sprite:
		animated_sprite.play("idle")
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
	queue_redraw()

func _process(delta):
	if is_departing:
		return
	
	float_time += delta * 2.8
	position.y = initial_y + sin(float_time) * 2.2
	queue_redraw()
	
	if prompt_label and prompt_label.visible:
		prompt_label.modulate.a = 0.6 + 0.4 * sin(float_time * 2.5)

	# Proximity fallback check
	if not is_player_near and not has_talked and not is_departing:
		var p = get_tree().get_first_node_in_group("player")
		if not p and get_parent():
			p = get_parent().get_node_or_null("player")
		if p and is_instance_valid(p) and global_position.distance_to(p.global_position) <= 75.0:
			_on_interaction_body_entered(p)
	elif is_player_near and player_ref and not has_talked and not is_departing:
		if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) > 95.0:
			_on_interaction_body_exited(player_ref)

func _unhandled_input(event):
	if is_player_near and not has_talked and not is_departing:
		if (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)) or \
		   (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
			start_conversation()
			get_viewport().set_input_as_handled()

func _on_interaction_body_entered(body):
	if has_talked or is_departing:
		return
	if body.is_in_group("player") or body.name == "player" or body.name == "NABAB" or body.has_method("lock_controls"):
		is_player_near = true
		player_ref = body
		if prompt_label:
			prompt_label.text = "[E] SPEAK"
			prompt_label.visible = true

func _on_interaction_body_exited(body):
	if body == player_ref:
		is_player_near = false
		player_ref = null
		if prompt_label and not has_talked:
			prompt_label.visible = false

func start_conversation():
	if has_talked or is_departing:
		return
	
	has_talked = true
	if prompt_label:
		prompt_label.visible = false
	
	emit_signal("spoken")
	
	var dialogue_lines = [
		{
			"speaker": "GRUE",
			"text": "W-what?! Nabab AKA N'?! By all the stars... is that truly you, N'?! You're ALIVE?!"
		},
		{
			"speaker": "GRUE",
			"text": "You were dead, Nabab! We all saw it happen—you were betrayed and backstabbed in cold blood by someone... one of our very own!"
		},
		{
			"speaker": "GRUE",
			"text": "They severed your life, ripped your soul from this present world, and cast you into the searing abyss of hell!"
		},
		{
			"speaker": "GRUE",
			"text": "H-how did you ever make it back to the present time, N'?! Did you slaughter the warlords of the Time Spiral?!"
		},
		{
			"speaker": "GRUE",
			"text": "Listen to me, Nabab! Beware ahead—DARKSABER has seized command of the forest perimeter! He was stationed here in case you ever crawled back!"
		},
		{
			"speaker": "GRUE",
			"text": "His blade is forged from pure void steel! Steel yourself, Nabab AKA N'—the truth awaits past his corpse!"
		}
	]
	
	var world = get_tree().current_scene
	if not world or not world.has_method("show_npc_dialogue"):
		world = get_parent()
	if world and world.has_method("show_npc_dialogue"):
		world.show_npc_dialogue("GRUE", dialogue_lines, Callable(self, "depart"))
	else:
		get_tree().create_timer(1.0).timeout.connect(depart)

func depart():
	if is_departing:
		return
	is_departing = true
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("grin"):
		animated_sprite.play("grin")
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 1.8)
	tween.tween_property(self, "position:y", position.y - 45.0, 1.8).set_trans(Tween.TRANS_SINE)
	
	tween.chain().tween_callback(func():
		emit_signal("departed")
		queue_free()
	)

func _draw():
	if is_departing:
		return
	var shadow_pts = PackedVector2Array()
	var shadow_y = 26.0 - (position.y - initial_y)
	var rx = 14.0
	var ry = 4.5
	for i in range(16):
		var angle = i * TAU / 16.0
		shadow_pts.append(Vector2(cos(angle) * rx, shadow_y + sin(angle) * ry))
	draw_colored_polygon(shadow_pts, Color(0.02, 0.06, 0.03, 0.45))
