extends Node2D

@onready var player = get_node_or_null("player")
@onready var grue = get_node_or_null("GRUE")
@onready var darksaber = get_node_or_null("DARKSABER")
@onready var camera = get_node_or_null("EYES")

@onready var bg_back = get_node_or_null("SCENARIO/BackTrees")
@onready var bg_mid = get_node_or_null("SCENARIO/MidTrees")
@onready var bg_front = get_node_or_null("SCENARIO/FrontTrees")
@onready var bg_lights = get_node_or_null("SCENARIO/ForestLights")

@onready var canvas = get_node_or_null("Canvas")
@onready var dialogue_box = get_node_or_null("Canvas/Dialogues")
@onready var speaker_label = get_node_or_null("Canvas/Dialogues/outeredgeline/BOX/SPEAKER")
@onready var dialogue_label = get_node_or_null("Canvas/Dialogues/outeredgeline/BOX/DIALOGUES TEXT")
@onready var prompt_label = get_node_or_null("Canvas/Dialogues/outeredgeline/BOX/SKIP BUTTON")

@onready var hud = get_node_or_null("Canvas/HUDSYSTEMPROTOTYPE")
@onready var player_hp_bar = get_node_or_null("Canvas/HUDSYSTEMPROTOTYPE/HEALTH/HEALTHBar")
@onready var player_hp_text = get_node_or_null("Canvas/HUDSYSTEMPROTOTYPE/HEALTH/TEXT")
@onready var boss_vbox = get_node_or_null("Canvas/HUDSYSTEMPROTOTYPE/BOSSHEALTH")
@onready var boss_label = get_node_or_null("Canvas/HUDSYSTEMPROTOTYPE/BOSSHEALTH/BossLabel")
@onready var boss_hp_bar = get_node_or_null("Canvas/HUDSYSTEMPROTOTYPE/BOSSHEALTH/BOSSHEALTH")
@onready var status_banner = get_node_or_null("Canvas/status")

@onready var ending_screen = get_node_or_null("Canvas/EndingScreen")
@onready var ending_title = get_node_or_null("Canvas/EndingScreen/Center/VBox/Title")
@onready var ending_subtitle = get_node_or_null("Canvas/EndingScreen/Center/VBox/Subtitle")
@onready var ending_hint = get_node_or_null("Canvas/EndingScreen/Center/VBox/Hint")
@onready var ending_menu_btn = get_node_or_null("Canvas/EndingScreen/Center/VBox/MenuButton")

# Audio Background Music Nodes
@onready var present_music = get_node_or_null("back to the present")
@onready var boss_fight_music = get_node_or_null("boss fight music")

var music_blend_tween: Tween = null

const GAMEPLAY_ZOOM = Vector2(3.2, 3.2)
const GRUE_ENCOUNTER_X = 60.0
const DARKSABER_ENCOUNTER_X = 640.0

var has_talked_to_grue: bool = false
var darksaber_triggered: bool = false
var in_custom_dialogue: bool = false
var custom_dialogue_queue: Array = []
var custom_dialogue_idx: int = 0
var custom_dialogue_callback: Callable
var is_typing: bool = false
var type_tween: Tween

var scroll_back: float = 0.0
var scroll_mid: float = 0.0
var scroll_front: float = 0.0
var lights_time: float = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").apply_graphics_quality(get_node("/root/SettingsManager").graphics_quality, self)

	# Apply Prince of Persia font
	var pop_font = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	if pop_font:
		if ending_title:
			ending_title.add_theme_font_override("font", pop_font)
		if ending_subtitle:
			ending_subtitle.add_theme_font_override("font", pop_font)
		if ending_menu_btn:
			ending_menu_btn.add_theme_font_override("font", pop_font)
		if status_banner:
			status_banner.add_theme_font_override("font", pop_font)

	if ending_menu_btn:
		ending_menu_btn.pressed.connect(_on_return_to_main_menu)

	if player:
		player.position = Vector2(-380.0, 0.0)
		player.unlock_controls()
		if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("player_died") and not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)

	if grue:
		grue.position = Vector2(160.0, -18.0)
		if grue.has_signal("spoken") and not grue.spoken.is_connected(_on_grue_spoken):
			grue.spoken.connect(_on_grue_spoken)

	if darksaber:
		darksaber.position = Vector2(850.0, -34.0)
		darksaber.visible = false
		darksaber.collision_layer = 0
		if darksaber.has_signal("health_changed") and not darksaber.health_changed.is_connected(_on_boss_health_changed):
			darksaber.health_changed.connect(_on_boss_health_changed)
		if darksaber.has_signal("darksaber_cinematic_end") and not darksaber.darksaber_cinematic_end.is_connected(_on_darksaber_cinematic_end):
			darksaber.darksaber_cinematic_end.connect(_on_darksaber_cinematic_end)
		if darksaber.has_signal("darksaber_defeated") and not darksaber.darksaber_defeated.is_connected(_on_darksaber_defeated):
			darksaber.darksaber_defeated.connect(_on_darksaber_defeated)

	if camera:
		camera.position = Vector2(-380.0, -20.0)
		camera.zoom = GAMEPLAY_ZOOM
		camera.position_smoothing_enabled = false

	if boss_vbox:
		boss_vbox.modulate.a = 0.0
	if ending_screen:
		ending_screen.visible = false
		ending_screen.modulate.a = 0.0

	if dialogue_box:
		dialogue_box.visible = false
		dialogue_box.gui_input.connect(_on_dialogue_gui_input)

	if player_hp_text:
		player_hp_text.text = "NABAB AKA N'  |  HP: 8 / 8"

	if present_music == null:
		present_music = get_node_or_null("back to the present")
	if boss_fight_music == null:
		boss_fight_music = get_node_or_null("boss fight music")

	# Audio looping configuration
	for p in [present_music, boss_fight_music]:
		if p and p.stream is AudioStreamMP3:
			p.stream.loop = true
	if boss_fight_music:
		boss_fight_music.stop()

	# Background music for Level 2
	if present_music:
		present_music.volume_db = -25.0
		present_music.play()
		var t_p = create_tween()
		t_p.tween_property(present_music, "volume_db", 0.0, 1.5)

	show_temporary_banner("LEVEL II: THE VERDANT PRESENT - CHRONO NEXUS", Color(0.4, 1.0, 0.7, 1.0), 3.0)

func _process(delta: float):
	# Parallax scrolling matching player movement with gentle ambient wind drift
	var p_vel = player.velocity.x if (player and "velocity" in player) else 0.0
	
	const TILE_WIDTH = 1836.0 # 272px * 6.75 scale = 1836.0px
	scroll_back -= (p_vel * 0.10 * delta + 8.0 * delta)
	scroll_mid -= (p_vel * 0.28 * delta + 16.0 * delta)
	scroll_front -= (p_vel * 0.55 * delta + 26.0 * delta)
	
	while scroll_back <= -TILE_WIDTH:
		scroll_back += TILE_WIDTH
	while scroll_back > 0.0:
		scroll_back -= TILE_WIDTH
		
	while scroll_mid <= -TILE_WIDTH:
		scroll_mid += TILE_WIDTH
	while scroll_mid > 0.0:
		scroll_mid -= TILE_WIDTH
		
	while scroll_front <= -TILE_WIDTH:
		scroll_front += TILE_WIDTH
	while scroll_front > 0.0:
		scroll_front -= TILE_WIDTH
	
	if bg_back:
		bg_back.position.x = scroll_back
	if bg_mid:
		bg_mid.position.x = scroll_mid
	if bg_front:
		bg_front.position.x = scroll_front
	
	lights_time += delta * 2.5
	if bg_lights:
		bg_lights.position.x = scroll_mid
		bg_lights.modulate.a = 0.40 + 0.30 * sin(lights_time)

	# Camera follow (anchored to player with subtle clamped boss framing)
	if player and camera:
		var target_x = player.global_position.x
		if player.has_node("AnimatedSprite2D") and player.get_node("AnimatedSprite2D").flip_h:
			target_x -= 16.0
		else:
			target_x += 16.0

		if darksaber_triggered and darksaber and is_instance_valid(darksaber):
			var to_boss = darksaber.global_position.x - player.global_position.x
			var boss_bias = clampf(to_boss * 0.15, -28.0, 28.0)
			target_x += boss_bias

		var cam_lerp = clampf(8.5 * delta, 0.0, 1.0)
		camera.global_position.x = lerp(camera.global_position.x, target_x, cam_lerp)
		camera.global_position.y = lerp(camera.global_position.y, player.global_position.y - 18.0, cam_lerp)

	# Progression boundaries & triggers
	if player:
		var px = player.global_position.x
		
		# Halt player before speaking with Grue
		if px >= GRUE_ENCOUNTER_X and not has_talked_to_grue:
			if px >= 120.0:
				player.global_position.x = 115.0
				player.velocity.x = 0.0
				show_temporary_banner("SPEAK WITH GRUE BEFORE ADVANCING!", Color(0.35, 1.0, 0.65, 1.0), 1.5)

		# Trigger Darksaber Boss after crossing Grue
		if px >= DARKSABER_ENCOUNTER_X and has_talked_to_grue and not darksaber_triggered:
			trigger_darksaber_encounter()

func _input(event):
	if get_tree().paused and ending_screen and ending_screen.visible:
		if (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E)) or \
		   (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
			_on_return_to_main_menu()
			get_viewport().set_input_as_handled()
			return

	if in_custom_dialogue:
		if (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E)) or \
		   (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
			advance_custom_dialogue()
			get_viewport().set_input_as_handled()


func _on_dialogue_gui_input(event):
	if in_custom_dialogue and event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		advance_custom_dialogue()
		get_viewport().set_input_as_handled()

func _on_grue_spoken():
	has_talked_to_grue = true

func trigger_darksaber_encounter():
	darksaber_triggered = true
	blend_to_boss_music(1.2)
	
	if boss_label:
		boss_label.text = "DARKSABER - THE VOID ENFORCER"
	if boss_hp_bar:
		boss_hp_bar.value = 100.0
	if boss_vbox:
		var t = create_tween()
		t.tween_property(boss_vbox, "modulate:a", 1.0, 0.6)

	if darksaber:
		darksaber.visible = true
		darksaber.collision_layer = 2
		if darksaber.has_method("activate_boss"):
			darksaber.activate_boss(player)

	show_temporary_banner("BOSS: DARKSABER - THE BETRAYER'S VOID BLADE", Color(1.0, 0.35, 0.45, 1.0), 3.0)

func _on_darksaber_defeated():
	trigger_victory_ending()

func trigger_victory_ending():
	blend_to_level_music(1.6)
	if is_instance_valid(boss_vbox):
		boss_vbox.modulate.a = 0.0
	if is_instance_valid(hud):
		hud.modulate.a = 0.0

	get_tree().paused = true

	if ending_screen:
		if ending_title:
			ending_title.text = "YOU HAVE DEFEATED THE TIME BEAST"
		if ending_subtitle:
			ending_subtitle.text = "THE FUTURE JOURNEY WILL TO BE CONTINUED"
		if ending_hint:
			ending_hint.text = "PRESS ENTER OR CLICK TO RETURN TO MAIN MENU"
		if ending_menu_btn:
			ending_menu_btn.visible = true
			ending_menu_btn.grab_focus()

		ending_screen.visible = true
		ending_screen.modulate.a = 1.0

func _on_return_to_main_menu():
	get_tree().paused = false
	if boss_fight_music and boss_fight_music.playing:
		var t_b = create_tween()
		t_b.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t_b.tween_property(boss_fight_music, "volume_db", -40.0, 0.8)
		t_b.finished.connect(func():
			if boss_fight_music:
				boss_fight_music.stop()
		)
	if present_music and present_music.playing:
		var t_out = create_tween()
		t_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t_out.tween_property(present_music, "volume_db", -40.0, 0.8)
		t_out.finished.connect(func():
			get_tree().change_scene_to_file("res://scenes/levels/world.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://scenes/levels/world.tscn")

func _on_player_died():
	# Player fell to Darksaber's overwhelming might -> trigger defeat ending
	trigger_tale_will_continue()

func _on_darksaber_cinematic_end():
	trigger_tale_will_continue()

func trigger_tale_will_continue():
	if ending_screen and ending_screen.visible:
		return
	
	if boss_fight_music and boss_fight_music.playing:
		var t_bf = create_tween()
		t_bf.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t_bf.tween_property(boss_fight_music, "volume_db", -40.0, 1.0)
		t_bf.finished.connect(func():
			if boss_fight_music:
				boss_fight_music.stop()
		)

	if boss_vbox:
		create_tween().tween_property(boss_vbox, "modulate:a", 0.0, 0.4)
	if hud:
		create_tween().tween_property(hud, "modulate:a", 0.0, 0.4)

	if ending_screen:
		if ending_title:
			ending_title.text = "THE TALE WILL CONTINUE ...."
		if ending_subtitle:
			ending_subtitle.text = "The Betrayer still reigns in the shadows of the present.\nThe Time Spiral has only just begun."
		if ending_hint:
			ending_hint.text = "Returning to Timeline Origin..."
		if ending_menu_btn:
			ending_menu_btn.visible = false

		ending_screen.visible = true
		var t = create_tween()
		t.tween_property(ending_screen, "modulate:a", 1.0, 1.2)
		
		# Display ending for 4.2 seconds then return to main menu starting screen
		t.tween_interval(4.2)
		t.tween_callback(func():
			_on_return_to_main_menu()
		)

func show_npc_dialogue(speaker: String, lines: Array, on_complete: Callable = Callable()):
	if lines.is_empty():
		return
	in_custom_dialogue = true
	custom_dialogue_queue = lines
	custom_dialogue_idx = 0
	custom_dialogue_callback = on_complete

	if player and player.has_method("lock_controls"):
		player.lock_controls()

	if dialogue_box:
		dialogue_box.visible = true
		dialogue_box.modulate.a = 1.0

	show_custom_dialogue_line()

func show_custom_dialogue_line():
	if custom_dialogue_idx >= custom_dialogue_queue.size():
		finish_custom_dialogue()
		return

	var d = custom_dialogue_queue[custom_dialogue_idx]
	if speaker_label:
		speaker_label.text = d["speaker"]
	if dialogue_label:
		dialogue_label.text = d["text"]
		dialogue_label.visible_characters = 0
	if prompt_label:
		prompt_label.visible = false

	is_typing = true
	var char_count = d["text"].length()
	var duration = float(char_count) * 0.03

	if type_tween and type_tween.is_valid():
		type_tween.kill()

	if dialogue_label:
		type_tween = create_tween()
		type_tween.tween_property(dialogue_label, "visible_characters", char_count, duration)
		type_tween.finished.connect(func():
			is_typing = false
			if prompt_label:
				prompt_label.visible = true
		)
	else:
		is_typing = false

func advance_custom_dialogue():
	if is_typing:
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		if dialogue_label:
			dialogue_label.visible_characters = dialogue_label.text.length()
		is_typing = false
		if prompt_label:
			prompt_label.visible = true
	else:
		custom_dialogue_idx += 1
		show_custom_dialogue_line()

func finish_custom_dialogue():
	in_custom_dialogue = false
	if dialogue_box:
		var t = create_tween()
		t.tween_property(dialogue_box, "modulate:a", 0.0, 0.4)
		t.finished.connect(func():
			dialogue_box.visible = false
			if player and player.has_method("unlock_controls"):
				player.unlock_controls()
			if custom_dialogue_callback.is_valid():
				custom_dialogue_callback.call()
		)
	else:
		if player and player.has_method("unlock_controls"):
			player.unlock_controls()
		if custom_dialogue_callback.is_valid():
			custom_dialogue_callback.call()

func _on_player_health_changed(hp, max_hp):
	if player_hp_bar:
		player_hp_bar.value = (hp / max_hp) * 100.0
	if player_hp_text:
		player_hp_text.text = "NABAB AKA N'  |  HP: %d / 8" % [int(hp)]

func _on_boss_health_changed(hp, max_hp):
	if boss_hp_bar:
		boss_hp_bar.value = (hp / max_hp) * 100.0

func show_temporary_banner(text_msg: String, color: Color, duration: float = 2.0):
	if status_banner == null:
		return
	status_banner.text = text_msg
	status_banner.modulate = color
	status_banner.visible = true
	var t = create_tween()
	t.tween_interval(duration)
	t.tween_property(status_banner, "modulate:a", 0.0, 0.5)
	t.tween_callback(func():
		status_banner.visible = false
		status_banner.modulate.a = 1.0
	)

# Music Blending System (Level 2 Ambient vs Boss Fight Music)
func blend_to_boss_music(duration: float = 1.2):
	if music_blend_tween and music_blend_tween.is_valid():
		music_blend_tween.kill()
	music_blend_tween = create_tween().set_parallel(true)
	music_blend_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if present_music and present_music.playing:
		music_blend_tween.tween_property(present_music, "volume_db", -40.0, duration)
		music_blend_tween.chain().tween_callback(func():
			if present_music:
				present_music.stop()
		)
	if boss_fight_music:
		if not boss_fight_music.playing:
			boss_fight_music.volume_db = -30.0
			boss_fight_music.play()
		music_blend_tween.tween_property(boss_fight_music, "volume_db", 0.0, duration)

func blend_to_level_music(duration: float = 1.4):
	if music_blend_tween and music_blend_tween.is_valid():
		music_blend_tween.kill()
	music_blend_tween = create_tween().set_parallel(true)
	music_blend_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if boss_fight_music and boss_fight_music.playing:
		music_blend_tween.tween_property(boss_fight_music, "volume_db", -40.0, duration)
		music_blend_tween.chain().tween_callback(func():
			if boss_fight_music:
				boss_fight_music.stop()
		)
	if present_music:
		if not present_music.playing:
			present_music.volume_db = -25.0
			present_music.play()
		music_blend_tween.tween_property(present_music, "volume_db", 0.0, duration)
