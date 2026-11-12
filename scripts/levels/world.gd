extends Node2D

@onready var player = get_node_or_null("player")
@onready var grimreaper = get_node_or_null("Grimreaper")
@onready var thewiseone = get_node_or_null("THEWISEONE")
@onready var allmind = get_node_or_null("ALLMIND")
@onready var submind1 = get_node_or_null("SUBMIND1")
@onready var submind2 = get_node_or_null("SUBMIND2")
@onready var wizard1 = get_node_or_null("wizardbosslevel1")
@onready var camera = get_node_or_null("EYES")

@onready var scenario = get_node_or_null("SCENARIO")
@onready var bg_sprite1 = get_node_or_null("SCENARIO/Sprite1")
@onready var bg_sprite2 = get_node_or_null("SCENARIO/Sprite2")
@onready var hell_horizon_glow = get_node_or_null("SCENARIO/HellHorizonGlow")

@onready var canvas = get_node_or_null("Canvas")
@onready var cinematic_bars = get_node_or_null("Canvas/CinematicBLACKEDGEBars")
@onready var top_bar = get_node_or_null("Canvas/CinematicBLACKEDGEBars/TopBar")
@onready var bottom_bar = get_node_or_null("Canvas/CinematicBLACKEDGEBars/BottomBar")
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

# Freeze End-Game Modal (Timeline Restored)
@onready var timeline_modal = get_node_or_null("Canvas/TimelineModal")
@onready var yes_button = get_node_or_null("Canvas/TimelineModal/Margin/VBox/ButtonBox/YesButton")
@onready var no_button = get_node_or_null("Canvas/TimelineModal/Margin/VBox/ButtonBox/NoButton")

# Reborn Modal (Death screen)
@onready var reborn_modal = get_node_or_null("Canvas/RebornModal")
@onready var reborn_yes_btn = get_node_or_null("Canvas/RebornModal/Margin/VBox/ButtonBox/YesButton")
@onready var reborn_no_btn = get_node_or_null("Canvas/RebornModal/Margin/VBox/ButtonBox/NoButton")

# Main Menu (Rokto & Rust)
@onready var main_menu = get_node_or_null("Canvas/MainMenu")
@onready var menu_title = get_node_or_null("Canvas/MainMenu/CenterBox/Title")
@onready var menu_start_btn = get_node_or_null("Canvas/MainMenu/CenterBox/StartButton")
@onready var menu_prompt_label = get_node_or_null("Canvas/MainMenu/CenterBox/PressEnterPrompt")

# Audio Background Music Nodes
@onready var main_menu_music = get_node_or_null("main menu music")
@onready var hellfire_music = get_node_or_null("helLFIRE")
@onready var present_music = get_node_or_null("back to the present")
@onready var boss_fight_music = get_node_or_null("boss fight music")

var music_blend_tween: Tween = null

static var start_in_gameplay_directly: bool = false
var in_main_menu: bool = true
var menu_pulse_time: float = 0.0

const CUTSCENE_ZOOM = Vector2(3.6, 3.6)
const GAMEPLAY_ZOOM = Vector2(3.2, 3.2)

# Distance thresholds for encounters
const ALLMIND_ENCOUNTER_X = 120.0
const WIZARD_ENCOUNTER_X = 850.0

var dialogues = [
	{
		"speaker": "THE GRIM REAPER",
		"text": "Awaken, Nabab AKA N'... You were betrayed. A cruel backstab ended your mortal life in your present era."
	},
	{
		"speaker": "THE GRIM REAPER",
		"text": "Your spirit was torn from your timeline and reincarnated into the burning abyss of this hellish realm."
	},
	{
		"speaker": "THE GRIM REAPER",
		"text": "If you yearn to return to your original present world, Nabab, you must slaughter the abominations that guard the Time Spire."
	},
	{
		"speaker": "THE GRIM REAPER",
		"text": "Clear the dunes, slay ALLMIND, and destroy the Wizard of Time to open the rift!"
	},
	{
		"speaker": "THE GRIM REAPER",
		"text": "Arise, Nabab AKA N'. Your blade awaits—carve your path back to the present time!"
	}
]

var current_dialogue_idx = 0
var in_cutscene = true
var is_typing = false
var type_tween: Tween
var prompt_time = 0.0
var bg_scroll_x = 0.0
var last_camera_x = -360.0
var hell_flicker_time = 0.0

# Level Progression Flags
var has_talked_to_grimreaper: bool = false
var has_talked_to_wiseone: bool = false
var allmind_triggered: bool = false
var allmind_defeated: bool = false
var wizard_triggered: bool = false
var wizard_part1_defeated: bool = false
var wizard_part2_defeated: bool = false
var wizard_part3_defeated: bool = false

var active_boss_node: Node2D = null

# Custom NPC Dialogue
var in_custom_dialogue: bool = false
var custom_dialogue_queue: Array = []
var custom_dialogue_idx: int = 0
var custom_dialogue_callback: Callable

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	if camera == null:
		camera = find_child("EYES", true, false)
	if camera == null:
		camera = find_child("*Camera*", true, false)

	if player == null:
		player = find_child("player", true, false)
	if player == null:
		player = find_child("CharacterBody2D*", true, false)

	if grimreaper == null:
		grimreaper = find_child("Grimreaper", true, false)
	if thewiseone == null:
		thewiseone = find_child("THEWISEONE", true, false)
	if allmind == null:
		allmind = find_child("ALLMIND", true, false)
	if allmind == null:
		allmind = find_child("Boss", true, false)

	if submind1 == null:
		submind1 = find_child("SUBMIND1", true, false)
	if submind2 == null:
		submind2 = find_child("SUBMIND2", true, false)
	if wizard1 == null:
		wizard1 = find_child("wizardbosslevel1", true, false)

	if bg_sprite1 == null:
		bg_sprite1 = find_child("Sprite1", true, false)
	if bg_sprite2 == null:
		bg_sprite2 = find_child("Sprite2", true, false)
	if hell_horizon_glow == null:
		hell_horizon_glow = find_child("HellHorizonGlow", true, false)

	if cinematic_bars == null:
		cinematic_bars = find_child("CinematicBLACKEDGEBars", true, false)
	if top_bar == null:
		top_bar = find_child("TopBar", true, false)
	if bottom_bar == null:
		bottom_bar = find_child("BottomBar", true, false)

	if dialogue_box == null:
		dialogue_box = find_child("Dialogues", true, false)
	if speaker_label == null:
		speaker_label = find_child("SPEAKER", true, false)
	if dialogue_label == null:
		dialogue_label = find_child("DIALOGUES TEXT", true, false)
	if prompt_label == null:
		prompt_label = find_child("SKIP BUTTON", true, false)

	if hud == null:
		hud = find_child("HUDSYSTEMPROTOTYPE", true, false)
	if player_hp_bar == null:
		player_hp_bar = find_child("HEALTHBar", true, false)
	if boss_vbox == null:
		boss_vbox = find_child("BOSSHEALTH", true, false)
	if boss_label == null:
		boss_label = find_child("BossLabel", true, false)
	if boss_hp_bar == null:
		boss_hp_bar = find_child("BOSSHEALTH", true, false)

	if status_banner == null:
		status_banner = find_child("status", true, false)

	if timeline_modal == null:
		timeline_modal = find_child("TimelineModal", true, false)
	if yes_button == null and timeline_modal:
		yes_button = timeline_modal.find_child("YesButton", true, false)
	if no_button == null and timeline_modal:
		no_button = timeline_modal.find_child("NoButton", true, false)

	if reborn_modal == null:
		reborn_modal = find_child("RebornModal", true, false)
	if reborn_yes_btn == null and reborn_modal:
		reborn_yes_btn = reborn_modal.find_child("YesButton", true, false)
	if reborn_no_btn == null and reborn_modal:
		reborn_no_btn = reborn_modal.find_child("NoButton", true, false)

	if main_menu_music == null:
		main_menu_music = get_node_or_null("main menu music")
	if hellfire_music == null:
		hellfire_music = get_node_or_null("helLFIRE")
	if present_music == null:
		present_music = get_node_or_null("back to the present")
	if boss_fight_music == null:
		boss_fight_music = get_node_or_null("boss fight music")

	if main_menu == null:
		main_menu = find_child("MainMenu", true, false)
	if menu_title == null and main_menu:
		menu_title = main_menu.find_child("Title", true, false)
	if menu_start_btn == null and main_menu:
		menu_start_btn = main_menu.find_child("StartButton", true, false)
	if menu_prompt_label == null and main_menu:
		menu_prompt_label = main_menu.find_child("PressEnterPrompt", true, false)

	if player_hp_text == null:
		player_hp_text = find_child("TEXT", true, false)

	# Apply Prince of Persia font (Cinzel Decorative)
	var pop_font = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	if pop_font:
		if menu_title:
			menu_title.add_theme_font_override("font", pop_font)
		if menu_prompt_label:
			menu_prompt_label.add_theme_font_override("font", pop_font)
		if menu_start_btn:
			menu_start_btn.add_theme_font_override("font", pop_font)
		var t_title = timeline_modal.find_child("Title", true, false) if timeline_modal else null
		if t_title:
			t_title.add_theme_font_override("font", pop_font)
		var r_title = reborn_modal.find_child("Title", true, false) if reborn_modal else null
		if r_title:
			r_title.add_theme_font_override("font", pop_font)
		if status_banner:
			status_banner.add_theme_font_override("font", pop_font)

	if yes_button and not yes_button.pressed.is_connected(_on_yes_button_pressed):
		yes_button.pressed.connect(_on_yes_button_pressed)
	if no_button and not no_button.pressed.is_connected(_on_no_button_pressed):
		no_button.pressed.connect(_on_no_button_pressed)

	if reborn_yes_btn and not reborn_yes_btn.pressed.is_connected(_on_reborn_yes_pressed):
		reborn_yes_btn.pressed.connect(_on_reborn_yes_pressed)
	if reborn_no_btn and not reborn_no_btn.pressed.is_connected(_on_reborn_no_pressed):
		reborn_no_btn.pressed.connect(_on_reborn_no_pressed)

	if menu_start_btn and not menu_start_btn.pressed.is_connected(start_game_from_menu):
		menu_start_btn.pressed.connect(start_game_from_menu)
	if main_menu and main_menu.has_signal("play_game") and not main_menu.play_game.is_connected(start_game_from_menu):
		main_menu.play_game.connect(start_game_from_menu)

	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").apply_graphics_quality(get_node("/root/SettingsManager").graphics_quality, self)

	if player:
		player.position = Vector2(-400.0, 0.0)
		if player.has_method("lock_controls"):
			player.lock_controls()
		if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("player_died") and not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)

	if grimreaper:
		grimreaper.position = Vector2(-320.0, -29.0)

	if thewiseone:
		thewiseone.position = Vector2(-120.0, 0.0)

	# ALLMIND & Subminds wait dormant until player walks forward
	if allmind:
		allmind.position = Vector2(420.0, -26.0)
		if allmind.has_method("set_dormant"):
			allmind.set_dormant(true)
		else:
			allmind.visible = false
			allmind.collision_layer = 0

	if submind1:
		submind1.position = Vector2(350.0, -14.0)
		if submind1.has_method("set_dormant"):
			submind1.set_dormant(true)
		else:
			submind1.visible = false
			submind1.collision_layer = 0

	if submind2:
		submind2.position = Vector2(490.0, -14.0)
		if submind2.has_method("set_dormant"):
			submind2.set_dormant(true)
		else:
			submind2.visible = false
			submind2.collision_layer = 0

	# Wizard Boss Part 1 positioned further ahead floating at the exact same ground clearance level
	if wizard1:
		wizard1.position = Vector2(1150.0, -40.0)
		wizard1.visible = false
		wizard1.collision_layer = 0
		if wizard1.has_signal("phase_transition"):
			wizard1.phase_transition.connect(_on_wizard_phase1_transition)

	if camera:
		camera.position = Vector2(-360.0, -20.0)
		camera.zoom = CUTSCENE_ZOOM
		camera.position_smoothing_enabled = false
		last_camera_x = camera.global_position.x

	if hud:
		hud.modulate.a = 0.0
	if player_hp_text:
		player_hp_text.text = "NABAB AKA N'  |  HP: 8 / 8"
	if boss_vbox:
		boss_vbox.modulate.a = 0.0

	if dialogue_box:
		dialogue_box.gui_input.connect(_on_dialogue_gui_input)

	if prompt_label:
		prompt_label.text = "SPACE/CLICK"

	# Audio looping configuration
	for p in [main_menu_music, hellfire_music, present_music, boss_fight_music]:
		if p and p.stream is AudioStreamMP3:
			p.stream.loop = true
	if boss_fight_music:
		boss_fight_music.stop()

	if start_in_gameplay_directly:
		start_in_gameplay_directly = false
		if main_menu_music:
			main_menu_music.stop()
		if hellfire_music:
			hellfire_music.volume_db = -20.0
			hellfire_music.play()
			var t_h = create_tween()
			t_h.tween_property(hellfire_music, "volume_db", 0.0, 1.2)
		start_game_from_menu(true)
	else:
		in_main_menu = true
		if hellfire_music:
			hellfire_music.stop()
		if main_menu_music:
			main_menu_music.volume_db = -20.0
			main_menu_music.play()
			var t_m = create_tween()
			t_m.tween_property(main_menu_music, "volume_db", 0.0, 1.0)
		if main_menu:
			main_menu.visible = true
			main_menu.modulate.a = 1.0
			if menu_start_btn:
				menu_start_btn.grab_focus()
		if cinematic_bars:
			cinematic_bars.visible = false
		if dialogue_box:
			dialogue_box.visible = false

func _process(delta):
	if in_main_menu:
		# Keep the world background scrolling slowly behind the main menu
		bg_scroll_x -= 2.5 * delta
		var screen_w_m = 1920.0
		if is_inside_tree():
			var vp_m = get_viewport_rect()
			if vp_m.size.x > 0.0:
				screen_w_m = vp_m.size.x
		bg_scroll_x = fmod(bg_scroll_x, screen_w_m)
		if bg_scroll_x > 0.0:
			bg_scroll_x -= screen_w_m
		if bg_sprite1 and bg_sprite2:
			bg_sprite1.position.x = bg_scroll_x
			bg_sprite2.position.x = bg_scroll_x + screen_w_m
		# Subtle hellfire horizon glow flicker behind menu too
		hell_flicker_time += delta * 4.2
		var flicker_m = 1.0 + 0.07 * sin(hell_flicker_time * 2.3) + 0.04 * sin(hell_flicker_time * 5.7)
		if hell_horizon_glow:
			hell_horizon_glow.modulate.a = clampf(0.65 * flicker_m, 0.45, 0.85)
		if menu_prompt_label:
			menu_pulse_time += delta * 3.5
			menu_prompt_label.modulate.a = 0.45 + 0.55 * sin(menu_pulse_time)
		return

	if is_inside_tree() and get_tree().paused:
		return

	# Camera-synced parallax scrolling (eliminates idle sliding and matches player movement)
	if in_cutscene or in_custom_dialogue:
		bg_scroll_x -= 3.5 * delta
	elif camera:
		var cam_dx = camera.global_position.x - last_camera_x
		bg_scroll_x -= cam_dx * 0.18

	var screen_w = 1920.0
	if is_inside_tree():
		var vp = get_viewport_rect()
		if vp.size.x > 0.0:
			screen_w = vp.size.x

	bg_scroll_x = fmod(bg_scroll_x, screen_w)
	if bg_scroll_x > 0.0:
		bg_scroll_x -= screen_w

	if bg_sprite1 and bg_sprite2:
		bg_sprite1.position.x = bg_scroll_x
		bg_sprite2.position.x = bg_scroll_x + screen_w

	hell_flicker_time += delta * 4.2
	var flicker = 1.0 + 0.07 * sin(hell_flicker_time * 2.3) + 0.04 * sin(hell_flicker_time * 5.7) + 0.025 * sin(hell_flicker_time * 11.1)
	if hell_horizon_glow:
		hell_horizon_glow.modulate.a = clampf(0.65 * flicker, 0.45, 0.85)

	if prompt_label and prompt_label.visible:
		prompt_time += delta * 4.0
		prompt_label.modulate.a = 0.5 + 0.5 * sin(prompt_time)

	# Smooth, player-centric camera tracking
	if not in_cutscene and player and camera:
		var target_x = player.global_position.x
		if player.has_node("AnimatedSprite2D") and player.get_node("AnimatedSprite2D").flip_h:
			target_x -= 16.0
		else:
			target_x += 16.0

		# Subtle boss framing: keep camera anchored to the player, with only a small clamped bias toward active boss
		if is_instance_valid(active_boss_node) and "is_dead" in active_boss_node and not active_boss_node.is_dead:
			var to_boss = active_boss_node.global_position.x - player.global_position.x
			var boss_bias = clampf(to_boss * 0.15, -28.0, 28.0)
			target_x += boss_bias

		var cam_lerp = clampf(8.5 * delta, 0.0, 1.0)
		camera.global_position.x = lerp(camera.global_position.x, target_x, cam_lerp)
		camera.global_position.y = lerp(camera.global_position.y, player.global_position.y - 18.0, cam_lerp)
		last_camera_x = camera.global_position.x

	# LEVEL PROGRESSION CHECK VIA WALKING DISTANCE:
	if not in_cutscene and player:
		var px = player.global_position.x

		# Zone 1: Encounter ALLMIND & Subminds after crossing distance
		if px >= ALLMIND_ENCOUNTER_X:
			if not has_talked_to_wiseone:
				player.global_position.x = ALLMIND_ENCOUNTER_X - 8.0
				player.velocity.x = 0.0
				show_temporary_banner("SPEAK WITH THE WISE ONE BEFORE ADVANCING!", Color(1.0, 0.85, 0.3, 1.0), 1.5)
			elif not allmind_triggered:
				trigger_allmind_encounter()
			elif not allmind_defeated and px >= 650.0:
				player.global_position.x = 650.0
				if player.velocity.x > 0.0:
					player.velocity.x = 0.0
				show_temporary_banner("DEFEAT ALLMIND BEFORE ADVANCING!", Color(1.0, 0.45, 0.45, 1.0), 1.5)

		# Zone 2: Encounter Wizard Boss after defeating ALLMIND and crossing small distance
		if px >= WIZARD_ENCOUNTER_X and allmind_defeated and not wizard_triggered:
			trigger_wizard_encounter()

func _input(event):
	if in_main_menu:
		if main_menu and "is_loading" in main_menu and main_menu.is_loading:
			return
		if main_menu and "current_view" in main_menu and main_menu.current_view != "main":
			return
		if event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E):
			start_game_from_menu()
			get_viewport().set_input_as_handled()
		return

	if is_inside_tree() and get_tree().paused:
		if reborn_modal and reborn_modal.visible:
			if event is InputEventKey and event.is_pressed() and not event.is_echo():
				if event.keycode == KEY_Y or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
					_on_reborn_yes_pressed()
					get_viewport().set_input_as_handled()
				elif event.keycode == KEY_N or event.keycode == KEY_ESCAPE:
					_on_reborn_no_pressed()
					get_viewport().set_input_as_handled()
			return

		if timeline_modal and timeline_modal.visible:
			if event is InputEventKey and event.is_pressed() and not event.is_echo():
				if event.keycode == KEY_Y or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
					_on_yes_button_pressed()
					get_viewport().set_input_as_handled()
				elif event.keycode == KEY_N or event.keycode == KEY_ESCAPE or event.keycode == KEY_R:
					_on_no_button_pressed()
					get_viewport().set_input_as_handled()
		return

	if in_cutscene:
		if (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E)) or \
		   (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
			advance_dialogue()
			get_viewport().set_input_as_handled()
	elif in_custom_dialogue:
		if (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E)) or \
		   (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
			advance_custom_dialogue()
			get_viewport().set_input_as_handled()

func start_game_from_menu(instant: bool = false):
	if not in_main_menu and not instant:
		return
	if not instant and main_menu and main_menu.has_method("start_loading_sequence") and not main_menu.is_loading:
		main_menu.start_loading_sequence(func(): start_game_from_menu(true))
		return
	in_main_menu = false

	# Smoothly transition audio: fade out main menu music, fade in hellfire music!
	if boss_fight_music:
		boss_fight_music.stop()
	if main_menu_music and main_menu_music.playing:
		var t_out = create_tween()
		t_out.tween_property(main_menu_music, "volume_db", -40.0, 1.2)
		t_out.finished.connect(func():
			if main_menu_music:
				main_menu_music.stop()
				main_menu_music.volume_db = 0.0
		)
	
	if hellfire_music and not hellfire_music.playing:
		hellfire_music.volume_db = -30.0
		hellfire_music.play()
		var t_in = create_tween()
		t_in.tween_property(hellfire_music, "volume_db", 0.0, 1.5)

	if cinematic_bars:
		cinematic_bars.visible = true
		cinematic_bars.modulate.a = 1.0
		if top_bar:
			top_bar.position.y = 0.0
		var viewport_h = 1080.0
		if is_inside_tree():
			var vp_rect = get_viewport_rect()
			if vp_rect.size.y > 0.0:
				viewport_h = vp_rect.size.y
		if bottom_bar:
			bottom_bar.position.y = viewport_h - 100.0

	if dialogue_box:
		dialogue_box.visible = true
		dialogue_box.modulate.a = 1.0

	if main_menu:
		if instant:
			main_menu.visible = false
			start_dialogue()
		else:
			var t = create_tween()
			t.tween_property(main_menu, "modulate:a", 0.0, 0.4)
			t.finished.connect(func():
				main_menu.visible = false
				start_dialogue()
			)
	else:
		start_dialogue()

func _on_dialogue_gui_input(event):
	if (in_cutscene or in_custom_dialogue) and event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if in_cutscene:
			advance_dialogue()
		elif in_custom_dialogue:
			advance_custom_dialogue()
		get_viewport().set_input_as_handled()

func start_dialogue():
	current_dialogue_idx = 0
	show_current_dialogue()

func show_current_dialogue():
	if current_dialogue_idx >= dialogues.size():
		finish_cutscene()
		return

	var d = dialogues[current_dialogue_idx]
	if speaker_label:
		speaker_label.text = d["speaker"]
	if dialogue_label:
		dialogue_label.text = d["text"]
		dialogue_label.visible_characters = 0
	if prompt_label:
		prompt_label.visible = false

	is_typing = true
	var char_count = d["text"].length()
	var duration = float(char_count) * 0.032

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

func advance_dialogue():
	if is_typing:
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		if dialogue_label:
			dialogue_label.visible_characters = dialogue_label.text.length()
		is_typing = false
		if prompt_label:
			prompt_label.visible = true
	else:
		current_dialogue_idx += 1
		show_current_dialogue()

func finish_cutscene():
	in_cutscene = false
	has_talked_to_grimreaper = true

	# Grim reaper floats away into the abyss
	if grimreaper:
		var gr_tween = create_tween().set_parallel(true)
		gr_tween.tween_property(grimreaper, "position:y", grimreaper.position.y - 120.0, 2.5).set_trans(Tween.TRANS_SINE)
		gr_tween.tween_property(grimreaper, "modulate:a", 0.0, 2.5)

	var fade_tween = create_tween().set_parallel(true)
	if dialogue_box:
		fade_tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.6)
	if top_bar:
		fade_tween.tween_property(top_bar, "position:y", -140.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var viewport_h = 1080.0
	if is_inside_tree():
		var vp_rect = get_viewport_rect()
		if vp_rect.size.y > 0.0:
			viewport_h = vp_rect.size.y
	if bottom_bar:
		fade_tween.tween_property(bottom_bar, "position:y", viewport_h + 140.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if cinematic_bars:
		fade_tween.tween_property(cinematic_bars, "modulate:a", 0.0, 1.2)

	if camera:
		fade_tween.tween_property(camera, "zoom", GAMEPLAY_ZOOM, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if hud:
		fade_tween.tween_property(hud, "modulate:a", 1.0, 0.8).set_delay(0.5)

	fade_tween.finished.connect(func():
		if dialogue_box:
			dialogue_box.visible = false
		if cinematic_bars:
			cinematic_bars.visible = false
		if player and player.has_method("unlock_controls"):
			player.unlock_controls()
		
		show_temporary_banner("[E] WALK FORWARD & SPEAK TO THE WISE ONE", Color(0.95, 0.88, 0.45, 1.0), 3.5)
	)

# Custom NPC Dialogue (used by The Wise One)
func show_npc_dialogue(speaker: String, lines: Array, on_complete_callback: Callable = Callable()):
	custom_dialogue_queue = lines
	custom_dialogue_idx = 0
	custom_dialogue_callback = on_complete_callback
	in_custom_dialogue = true

	if player and player.has_method("lock_controls"):
		player.lock_controls()

	if dialogue_box:
		dialogue_box.visible = true
		dialogue_box.modulate.a = 1.0

	show_custom_dialogue()

func show_custom_dialogue():
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
	var duration = float(char_count) * 0.032

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
		show_custom_dialogue()

func finish_custom_dialogue():
	in_custom_dialogue = false
	has_talked_to_wiseone = true

	var t = create_tween()
	if dialogue_box:
		t.tween_property(dialogue_box, "modulate:a", 0.0, 0.4)
	t.finished.connect(func():
		if dialogue_box:
			dialogue_box.visible = false
		if player and player.has_method("unlock_controls"):
			player.unlock_controls()
		
		# Execute callback (The Wise One perishes!)
		if custom_dialogue_callback.is_valid():
			custom_dialogue_callback.call()
		
		show_temporary_banner("WALK FORWARD TO CONFRONT ALLMIND >>", Color(0.9, 0.8, 1.0, 1.0), 3.0)
	)

# Zone 1: Encounter ALLMIND & Subminds
func trigger_allmind_encounter():
	allmind_triggered = true
	blend_to_boss_music(1.2)
	
	if boss_label:
		boss_label.text = "ALLMIND & THE SUBMINDS"
	if boss_hp_bar:
		boss_hp_bar.value = 100.0
	if boss_vbox:
		boss_vbox.modulate.a = 1.0

	if allmind:
		active_boss_node = allmind
		if allmind.has_method("activate_boss"):
			allmind.activate_boss(player)
		if allmind.has_signal("health_changed") and not allmind.health_changed.is_connected(_on_boss_health_changed):
			allmind.health_changed.connect(_on_boss_health_changed)
		if allmind.has_signal("boss_defeated") and not allmind.boss_defeated.is_connected(_on_allmind_defeated):
			allmind.boss_defeated.connect(_on_allmind_defeated)

	if submind1 and submind1.has_method("activate_enemy"):
		submind1.activate_enemy(player)
	if submind2 and submind2.has_method("activate_enemy"):
		submind2.activate_enemy(player)

	show_temporary_banner("TRIAL I: ALLMIND & THE VOID SUBMINDS", Color(1.0, 0.35, 0.45, 1.0), 2.5)

func _on_allmind_defeated():
	allmind_defeated = true
	blend_to_level_music(1.4)
	if boss_vbox:
		var t = create_tween()
		t.tween_property(boss_vbox, "modulate:a", 0.0, 0.8)

	for sub in [submind1, submind2]:
		if is_instance_valid(sub) and "is_dead" in sub and not sub.is_dead:
			if sub.has_method("die"):
				sub.die()
	
	show_temporary_banner("ALLMIND HAS FALLEN!\nCROSS FORWARD TO CONFRONT THE WIZARD >>", Color(1.0, 0.85, 0.3, 1.0), 3.5)

# Zone 2: Encounter Wizard Boss (Phases 1, 2 & 3)
func trigger_wizard_encounter():
	wizard_triggered = true
	blend_to_boss_music(1.2)

	if boss_label:
		boss_label.text = "THE WIZARD - PHASE I (SORCERER)"
	if boss_hp_bar:
		boss_hp_bar.value = 100.0
	if boss_vbox:
		boss_vbox.modulate.a = 1.0

	if wizard1:
		wizard1.visible = true
		wizard1.collision_layer = 2
		active_boss_node = wizard1
		if wizard1.has_signal("health_changed") and not wizard1.health_changed.is_connected(_on_boss_health_changed):
			wizard1.health_changed.connect(_on_boss_health_changed)
		if wizard1.has_signal("phase_transition") and not wizard1.phase_transition.is_connected(_on_wizard_phase1_transition):
			wizard1.phase_transition.connect(_on_wizard_phase1_transition)
		if wizard1.has_method("activate_boss"):
			wizard1.activate_boss(player)

	show_temporary_banner("FINAL TRIAL: THE WIZARD OF TIME - PHASE I", Color(0.85, 0.45, 1.0, 1.0), 2.5)

func _on_wizard_phase1_transition(wizard2_node):
	wizard_part1_defeated = true
	active_boss_node = wizard2_node

	if boss_label:
		boss_label.text = "THE WIZARD - PHASE II (ARCANE ASCENDANT)"
	if boss_hp_bar:
		boss_hp_bar.value = 100.0

	if wizard2_node:
		if wizard2_node.has_signal("health_changed"):
			wizard2_node.health_changed.connect(_on_boss_health_changed)
		if wizard2_node.has_signal("phase_transition"):
			wizard2_node.phase_transition.connect(_on_wizard_phase2_transition)

	show_temporary_banner("PHASE II: THE ARCANE MAGE UNLEASHED!", Color(1.0, 0.6, 0.2, 1.0), 2.8)

func _on_wizard_phase2_transition(wizard3_node):
	wizard_part2_defeated = true
	active_boss_node = wizard3_node

	if boss_label:
		boss_label.text = "THE ARCHMAGE - FINAL PHASE"
	if boss_hp_bar:
		boss_hp_bar.value = 100.0

	if wizard3_node:
		if wizard3_node.has_signal("health_changed"):
			wizard3_node.health_changed.connect(_on_boss_health_changed)
		if wizard3_node.has_signal("boss_defeated"):
			wizard3_node.boss_defeated.connect(_on_wizard3_defeated)

	show_temporary_banner("FINAL PHASE: THE ARCHMAGE AWAKENS AT SURFACE LEVEL!", Color(1.0, 0.35, 0.9, 1.0), 2.8)

# Wizard Boss Phase 3 Defeated -> Freeze Screen & Show Timeline Modal!
func _on_wizard3_defeated():
	wizard_part3_defeated = true
	blend_to_level_music(1.6)
	
	if boss_vbox:
		var t = create_tween()
		t.tween_property(boss_vbox, "modulate:a", 0.0, 0.5)

	# Wait a short moment for death animation, then completely freeze screen
	if is_inside_tree():
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_inside_tree():
				get_tree().paused = true
				if timeline_modal:
					timeline_modal.visible = true
					if yes_button:
						yes_button.grab_focus()
		)

func _on_yes_button_pressed():
	if is_inside_tree():
		get_tree().paused = false
	if timeline_modal:
		timeline_modal.visible = false
	
	# Smoothly fade out hellfire music before entering present level 2
	if hellfire_music and hellfire_music.playing:
		var t_fade = create_tween()
		t_fade.tween_property(hellfire_music, "volume_db", -40.0, 2.0)

	show_temporary_banner("THE TIMELINE HAS BEEN RESTORED TEMPORARILY!\nTRAVELING BACK TO THE PRESENT TIME...", Color(1.0, 0.86, 0.4, 1.0), 2.4)
	if is_inside_tree():
		get_tree().create_timer(2.5).timeout.connect(func():
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scenes/levels/level2.tscn")
		)

func _on_no_button_pressed():
	start_in_gameplay_directly = false
	if is_inside_tree():
		get_tree().paused = false
		get_tree().reload_current_scene()

func _on_player_died():
	if boss_fight_music and boss_fight_music.playing:
		var t_d = create_tween()
		t_d.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t_d.tween_property(boss_fight_music, "volume_db", -40.0, 0.8)
	# Wait brief moment for death animation, then freeze screen and show reborn modal
	if is_inside_tree():
		get_tree().create_timer(0.65).timeout.connect(func():
			if is_inside_tree():
				get_tree().paused = true
				if reborn_modal:
					reborn_modal.visible = true
					if reborn_yes_btn:
						reborn_yes_btn.grab_focus()
		)

func _on_reborn_yes_pressed():
	start_in_gameplay_directly = true
	if boss_fight_music:
		boss_fight_music.stop()
	if is_inside_tree():
		get_tree().paused = false
		get_tree().reload_current_scene()

func _on_reborn_no_pressed():
	start_in_gameplay_directly = false
	if boss_fight_music:
		boss_fight_music.stop()
	if hellfire_music:
		hellfire_music.stop()
	if is_inside_tree():
		get_tree().paused = false
		get_tree().reload_current_scene()

# Music Blending System (Level 1 Ambient vs Boss Fight Music)
func blend_to_boss_music(duration: float = 1.2):
	if music_blend_tween and music_blend_tween.is_valid():
		music_blend_tween.kill()
	music_blend_tween = create_tween().set_parallel(true)
	music_blend_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if hellfire_music and hellfire_music.playing:
		music_blend_tween.tween_property(hellfire_music, "volume_db", -40.0, duration)
		music_blend_tween.chain().tween_callback(func():
			if hellfire_music and not in_main_menu:
				hellfire_music.stop()
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
	if hellfire_music and not in_main_menu:
		if not hellfire_music.playing:
			hellfire_music.volume_db = -25.0
			hellfire_music.play()
		music_blend_tween.tween_property(hellfire_music, "volume_db", 0.0, duration)

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
		if not wizard_part3_defeated:
			status_banner.visible = false
			status_banner.modulate.a = 1.0
	)
