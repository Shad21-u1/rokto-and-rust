extends CharacterBody2D

signal spoken
signal perished

@onready var animated_sprite = $AnimatedSprite2D
@onready var interaction_area = $InteractionArea
@onready var prompt_label = get_node_or_null("speak") if has_node("speak") else get_node_or_null("PromptLabel")

var is_player_near: bool = false
var has_talked: bool = false
var is_perishing: bool = false
var player_ref: Node2D = null
var float_time: float = 0.0
var initial_y: float = 0.0

func _ready():
	add_to_group("npcs")
	initial_y = position.y
	
	var random_x = randf_range(-140.0, -90.0)
	position.x = random_x
	
	if animated_sprite:
		animated_sprite.play("idle")
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
	queue_redraw()

func _process(delta):
	if is_perishing:
		return
	
	float_time += delta * 3.0
	position.y = initial_y + sin(float_time) * 2.5
	queue_redraw()
	
	if prompt_label and prompt_label.visible:
		prompt_label.modulate.a = 0.65 + 0.35 * sin(float_time * 2.0)

	# Proximity fallback check
	if not is_player_near and not has_talked and not is_perishing:
		var p = get_tree().get_first_node_in_group("player")
		if not p and get_parent():
			p = get_parent().get_node_or_null("player")
		if p and is_instance_valid(p) and global_position.distance_to(p.global_position) <= 75.0:
			_on_interaction_body_entered(p)
	elif is_player_near and player_ref and not has_talked and not is_perishing:
		if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) > 95.0:
			_on_interaction_body_exited(player_ref)

func _unhandled_input(event):
	if is_player_near and not has_talked and not is_perishing:
		if (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)) or \
		   (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
			start_conversation()
			get_viewport().set_input_as_handled()

func _on_interaction_body_entered(body):
	if has_talked or is_perishing:
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
	if has_talked or is_perishing:
		return
	
	has_talked = true
	if prompt_label:
		prompt_label.visible = false
	
	emit_signal("spoken")
	
	var world = get_tree().current_scene
	if not world or not world.has_method("show_npc_dialogue"):
		world = get_parent()

	var dialogue_lines = [
		{
			"speaker": "THE WISE ONE",
			"text": "Halt, Nabab AKA N'! The wicked backstab that struck you down fractured the timeline itself."
		},
		{
			"speaker": "THE WISE ONE",
			"text": "To break this infernal curse and return to your original present world, Nabab, you must slaughter the horrors of this abyss!"
		},
		{
			"speaker": "THE WISE ONE",
			"text": "Ahead lies ALLMIND and his ravenous subminds. Crush them to reach the Wizard of Time!"
		},
		{
			"speaker": "THE WISE ONE",
			"text": "The Wizard commands 3 lethal forms. Destroy his final Archmage form to mend the timeline temporarily!"
		},
		{
			"speaker": "THE WISE ONE",
			"text": "My purpose is fulfilled... Strike true with your blade, Nabab AKA N', and reclaim your stolen present time!"
		}
	]
	
	if world and world.has_method("show_npc_dialogue"):
		world.show_npc_dialogue("THE WISE ONE", dialogue_lines, Callable(self, "perish"))
	else:
		get_tree().create_timer(1.0).timeout.connect(perish)

func perish():
	if is_perishing:
		return
	is_perishing = true
	
	if prompt_label:
		prompt_label.visible = false
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("perish"):
		animated_sprite.play("perish")
	
	var tween = create_tween().set_parallel(true)
	modulate = Color(1.5, 2.0, 3.0, 1.0) # Bright celestial aura glow
	tween.tween_property(self, "modulate", Color(0.8, 1.2, 2.5, 0.0), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 18.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.6, 1.4), 1.6)
	
	tween.chain().tween_callback(func():
		emit_signal("perished")
		queue_free()
	)

func _draw():
	if is_perishing:
		return
	var shadow_pts = PackedVector2Array()
	var shadow_y = 16.0 - position.y
	var rx = 12.0
	var ry = 4.0
	for i in range(16):
		var angle = i * TAU / 16.0
		shadow_pts.append(Vector2(cos(angle) * rx, shadow_y + sin(angle) * ry))
	draw_colored_polygon(shadow_pts, Color(0.01, 0.0, 0.04, 0.4))
