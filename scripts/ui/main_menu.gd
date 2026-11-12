extends Control

signal play_game

@onready var backdrop = get_node_or_null("Backdrop")

var current_view: String = "main" # "main", "char_select", "options"

# Views containers
var main_view_container: Control = null
var char_select_container: Control = null
var options_container: Control = null

# Character Selection nodes
var nobab_idle_sprite: AnimatedSprite2D = null
var moveset_preview_sprite: AnimatedSprite2D = null
var moveset_status_label: Label = null
var moveset_anim_index: int = 0
var moveset_timer: float = 0.0
const MOVESET_CYCLE = ["sword", "mech arm_1", "dodge"]
const MOVESET_NAMES = [
	"▶ PREVIEW: [LMB / J] VOID BLADE SLICE",
	"▶ PREVIEW: [T / K] MECH ARM OVERDRIVE",
	"▶ PREVIEW: [M / C / SHIFT] SHADOW PHASE DODGE"
]

# Options nodes
var volume_label: Label = null
var volume_bar: ProgressBar = null
var resolution_label: Label = null
var fullscreen_btn: Button = null
var graphics_desc_label: Label = null
var low_btn: Button = null
var normal_btn: Button = null
var high_btn: Button = null

# World 2 Parallax Background nodes
var w2_bg_container: Control = null
var w2_sky: TextureRect = null
var w2_bg_back: TextureRect = null
var w2_bg_mid: TextureRect = null
var w2_bg_lights: TextureRect = null
var w2_bg_front: TextureRect = null
var w2_spores: CPUParticles2D = null
var w2_leaves: CPUParticles2D = null
var w2_vignette: TextureRect = null

var w2_scroll_back: float = 0.0
var w2_scroll_mid: float = 0.0
var w2_scroll_front: float = 0.0
var w2_lights_time: float = 0.0

# Flowing Flames nodes
var flame_layer: Control = null
var flame_particles: CPUParticles2D = null
var ember_particles: CPUParticles2D = null

# Loading Screen nodes & state
var loading_container: Control = null
var loading_nobab_sprite: AnimatedSprite2D = null
var loading_progress_bar: ProgressBar = null
var loading_percent_label: Label = null
var loading_subtitle: Label = null
var loading_tip_label: Label = null
var loading_runner_line: ColorRect = null
var loading_dust_particles: CPUParticles2D = null

var is_loading: bool = false
var loading_progress: float = 0.0
var loading_timer: float = 0.0
var loading_callback: Callable = Callable()
var loading_dots_timer: float = 0.0
var loading_tips: Array = [
	"TIP: Unleash Nobab's Mech Arm Overdrive [T / K] to trigger a ground slam shockwave.",
	"TIP: Timing your Shadow Phase Dodge [SHIFT / M / C] grants complete invulnerability frames.",
	"TIP: Speak with The Wise One across the dunes before daring to face ALLMIND.",
	"TIP: Slay the abominations of the Chrono Spire to reconstruct your shattered timeline."
]

var pop_font: Font = null
var pulse_time: float = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	pop_font = load("res://assets/fonts/CinzelDecorative-Bold.ttf")

	build_metroidvania_ui()
	switch_view("main")

	# Connect with SettingsManager
	if is_inside_tree() and has_node("/root/SettingsManager"):
		var sm = get_node("/root/SettingsManager")
		sm.volume_changed.connect(_on_settings_volume_changed)
		sm.resolution_changed.connect(_on_settings_res_changed)
		sm.graphics_changed.connect(_on_settings_graphics_changed)

	update_options_ui()

func _process(delta: float):
	pulse_time += delta * 3.5

	# Animate World 2 moving parallax background
	if w2_bg_container and w2_bg_container.visible:
		w2_scroll_back -= 10.0 * delta
		w2_scroll_mid -= 20.0 * delta
		w2_scroll_front -= 35.0 * delta

		const W2_TILE_WIDTH = 1836.0
		while w2_scroll_back <= -W2_TILE_WIDTH:
			w2_scroll_back += W2_TILE_WIDTH
		while w2_scroll_back > 0.0:
			w2_scroll_back -= W2_TILE_WIDTH

		while w2_scroll_mid <= -W2_TILE_WIDTH:
			w2_scroll_mid += W2_TILE_WIDTH
		while w2_scroll_mid > 0.0:
			w2_scroll_mid -= W2_TILE_WIDTH

		while w2_scroll_front <= -W2_TILE_WIDTH:
			w2_scroll_front += W2_TILE_WIDTH
		while w2_scroll_front > 0.0:
			w2_scroll_front -= W2_TILE_WIDTH

		if w2_bg_back:
			w2_bg_back.position.x = w2_scroll_back
		if w2_bg_mid:
			w2_bg_mid.position.x = w2_scroll_mid
		if w2_bg_lights:
			w2_bg_lights.position.x = w2_scroll_mid
			w2_lights_time += delta * 2.2
			w2_bg_lights.modulate.a = 0.35 + 0.25 * sin(w2_lights_time)
		if w2_bg_front:
			w2_bg_front.position.x = w2_scroll_front

	if is_loading:
		loading_timer += delta
		var p_ratio = clampf(loading_timer / 4.0, 0.0, 1.0)
		var curved_p = ease(p_ratio, -1.5) * 100.0
		loading_progress = clampf(curved_p, 0.0, 100.0)

		if loading_progress_bar:
			loading_progress_bar.value = loading_progress
		if loading_percent_label:
			loading_percent_label.text = str(int(loading_progress)) + " %"

		loading_dots_timer += delta * 4.2
		var dot_count = (int(loading_dots_timer) % 4) + 1
		var dots = ""
		for i in range(dot_count):
			dots += " ."
		if loading_subtitle:
			loading_subtitle.text = "SYNCHRONIZING TIMELINE" + dots

		if loading_progress >= 100.0 and loading_timer >= 4.1:
			finish_loading_sequence()
		return

	# Idle / Ambient pulse on active view
	if current_view == "main":
		var prompt = find_child("PressEnterPrompt", true, false)
		if prompt:
			prompt.modulate.a = 0.5 + 0.5 * sin(pulse_time)
	elif current_view == "char_select":
		# Cycle moveset preview animation
		moveset_timer += delta
		if moveset_timer >= 1.8:
			moveset_timer = 0.0
			cycle_moveset_animation()

# ================= UI STYLING HELPERS =================
func create_stylebox(bg_col: Color, border_col: Color, corner: int = 6, border_w: int = 2) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	return sb

func style_metroidvania_button(btn: Button, text: String, font_size: int = 18, is_primary: bool = false):
	btn.text = text
	if pop_font:
		btn.add_theme_font_override("font", pop_font)
	btn.add_theme_font_size_override("font_size", font_size)
	
	var norm_bg = Color(0.12, 0.08, 0.20, 0.92) if not is_primary else Color(0.24, 0.12, 0.16, 0.95)
	var norm_border = Color(0.65, 0.48, 0.28, 0.8) if not is_primary else Color(0.95, 0.65, 0.25, 0.95)
	
	var hov_bg = Color(0.25, 0.15, 0.38, 1.0) if not is_primary else Color(0.40, 0.15, 0.22, 1.0)
	var hov_border = Color(1.0, 0.85, 0.45, 1.0)

	btn.add_theme_stylebox_override("normal", create_stylebox(norm_bg, norm_border, 6, 2))
	btn.add_theme_stylebox_override("hover", create_stylebox(hov_bg, hov_border, 6, 2))
	btn.add_theme_stylebox_override("pressed", create_stylebox(hov_bg.lightened(0.1), hov_border, 6, 2))
	btn.add_theme_stylebox_override("focus", create_stylebox(hov_bg, hov_border, 6, 2))

	btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.9, 1.0))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# ================= UI CONSTRUCTION =================
func build_metroidvania_ui():
	# Backdrop: semi-transparent dark overlay so world BG shows through behind menu
	if not backdrop:
		backdrop = ColorRect.new()
		backdrop.name = "Backdrop"
		backdrop.color = Color(0.0, 0.0, 0.0, 0.0)  # fully transparent — world BG visible
		backdrop.set_anchors_preset(PRESET_FULL_RECT)
		add_child(backdrop)
	else:
		if backdrop is ColorRect:
			backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
		var old_part = backdrop.get_node_or_null("CPUParticles2D")
		if old_part:
			old_part.visible = false

	# 0. World 2 Moving Parallax Background Layer
	build_world2_background()
	# 1. Flowing Flames Layer in background
	build_flames_fx()
	# 2. Main View (Home)
	build_main_view()
	# 3. Character Selection View
	build_char_select_view()
	# 4. Options View
	build_options_view()
	# 5. Loading Screen View (Running Nobab)
	build_loading_screen_view()

# ================= WORLD 2 MOVING PARALLAX BACKGROUND =================
func build_world2_background():
	w2_bg_container = Control.new()
	w2_bg_container.name = "World2Background"
	w2_bg_container.set_anchors_preset(PRESET_FULL_RECT)
	w2_bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(w2_bg_container)

	# 1. Forest Sky Gradient
	var sky_grad = Gradient.new()
	sky_grad.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	sky_grad.colors = PackedColorArray([
		Color(0.04, 0.08, 0.07, 1.0),
		Color(0.08, 0.20, 0.16, 1.0),
		Color(0.16, 0.36, 0.26, 1.0),
		Color(0.35, 0.60, 0.42, 1.0)
	])
	var sky_tex = GradientTexture2D.new()
	sky_tex.gradient = sky_grad
	sky_tex.fill_to = Vector2(0, 1)

	w2_sky = TextureRect.new()
	w2_sky.name = "ForestSky"
	w2_sky.texture = sky_tex
	w2_sky.set_anchors_preset(PRESET_FULL_RECT)
	w2_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	w2_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w2_bg_container.add_child(w2_sky)

	# 2. Back Trees Parallax Layer
	var back_tex = load("res://assets/sprites/backgrounds/parallax_forest/parallax-forest-back-trees.png")
	if back_tex:
		w2_bg_back = TextureRect.new()
		w2_bg_back.name = "BackTrees"
		w2_bg_back.texture = back_tex
		w2_bg_back.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		w2_bg_back.stretch_mode = TextureRect.STRETCH_TILE
		w2_bg_back.size = Vector2(1632.0, 160.0)
		w2_bg_back.scale = Vector2(6.75, 6.75)
		w2_bg_back.modulate = Color(0.72, 0.85, 0.82, 0.95)
		w2_bg_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w2_bg_container.add_child(w2_bg_back)

	# 3. Mid Trees Parallax Layer
	var mid_tex = load("res://assets/sprites/backgrounds/parallax_forest/parallax-forest-middle-trees.png")
	if mid_tex:
		w2_bg_mid = TextureRect.new()
		w2_bg_mid.name = "MidTrees"
		w2_bg_mid.texture = mid_tex
		w2_bg_mid.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		w2_bg_mid.stretch_mode = TextureRect.STRETCH_TILE
		w2_bg_mid.size = Vector2(1632.0, 160.0)
		w2_bg_mid.scale = Vector2(6.75, 6.75)
		w2_bg_mid.modulate = Color(0.85, 0.98, 0.92, 0.95)
		w2_bg_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w2_bg_container.add_child(w2_bg_mid)

	# 4. Forest Lights Animated Pulsing Layer
	var lights_tex = load("res://assets/sprites/backgrounds/parallax_forest/parallax-forest-lights.png")
	if lights_tex:
		w2_bg_lights = TextureRect.new()
		w2_bg_lights.name = "ForestLights"
		w2_bg_lights.texture = lights_tex
		w2_bg_lights.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		w2_bg_lights.stretch_mode = TextureRect.STRETCH_TILE
		w2_bg_lights.size = Vector2(1632.0, 160.0)
		w2_bg_lights.scale = Vector2(6.75, 6.75)
		w2_bg_lights.modulate = Color(1.15, 1.35, 0.95, 0.45)
		w2_bg_lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w2_bg_container.add_child(w2_bg_lights)

	# 5. Front Trees Parallax Layer
	var front_tex = load("res://assets/sprites/backgrounds/parallax_forest/parallax-forest-front-trees.png")
	if front_tex:
		w2_bg_front = TextureRect.new()
		w2_bg_front.name = "FrontTrees"
		w2_bg_front.texture = front_tex
		w2_bg_front.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		w2_bg_front.stretch_mode = TextureRect.STRETCH_TILE
		w2_bg_front.size = Vector2(1632.0, 160.0)
		w2_bg_front.scale = Vector2(6.75, 6.75)
		w2_bg_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w2_bg_container.add_child(w2_bg_front)

	# 6. Wind Spores Atmosphere Particles
	w2_spores = CPUParticles2D.new()
	w2_spores.name = "WindSpores"
	w2_spores.position = Vector2(960, 540)
	w2_spores.amount = 45
	w2_spores.lifetime = 6.0
	w2_spores.preprocess = 4.0
	w2_spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	w2_spores.emission_rect_extents = Vector2(1100, 600)
	w2_spores.direction = Vector2(-1.0, 0.15)
	w2_spores.spread = 25.0
	w2_spores.gravity = Vector2(-15, 8)
	w2_spores.initial_velocity_min = 18.0
	w2_spores.initial_velocity_max = 45.0
	w2_spores.tangential_accel_min = -12.0
	w2_spores.tangential_accel_max = 12.0
	w2_spores.scale_amount_min = 3.0
	w2_spores.scale_amount_max = 6.0

	var spore_curve = Curve.new()
	spore_curve.add_point(Vector2(0.0, 0.4), 0.0, 1.5)
	spore_curve.add_point(Vector2(0.5, 1.0), 0.0, 0.0)
	spore_curve.add_point(Vector2(1.0, 0.2), -1.8, 0.0)
	w2_spores.scale_amount_curve = spore_curve

	var spore_grad = Gradient.new()
	spore_grad.offsets = PackedFloat32Array([0.0, 0.4, 0.8, 1.0])
	spore_grad.colors = PackedColorArray([
		Color(0.85, 1.0, 0.8, 0.0),
		Color(0.60, 1.0, 0.75, 0.8),
		Color(0.40, 0.9, 0.65, 0.75),
		Color(0.20, 0.7, 0.4, 0.0)
	])
	w2_spores.color_ramp = spore_grad
	w2_bg_container.add_child(w2_spores)

	# 7. Falling Leaves Particles
	w2_leaves = CPUParticles2D.new()
	w2_leaves.name = "FallingLeaves"
	w2_leaves.position = Vector2(960, -20)
	w2_leaves.amount = 22
	w2_leaves.lifetime = 7.5
	w2_leaves.preprocess = 5.0
	w2_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	w2_leaves.emission_rect_extents = Vector2(1100, 20)
	w2_leaves.direction = Vector2(-0.85, 1.0)
	w2_leaves.spread = 35.0
	w2_leaves.gravity = Vector2(-22, 28)
	w2_leaves.initial_velocity_min = 25.0
	w2_leaves.initial_velocity_max = 55.0
	w2_leaves.angular_velocity_min = -60.0
	w2_leaves.angular_velocity_max = 60.0
	w2_leaves.tangential_accel_min = -18.0
	w2_leaves.tangential_accel_max = 18.0
	w2_leaves.scale_amount_min = 4.0
	w2_leaves.scale_amount_max = 8.5

	var leaf_curve = Curve.new()
	leaf_curve.add_point(Vector2(0.0, 0.6), 0.0, 1.0)
	leaf_curve.add_point(Vector2(0.4, 1.2), 0.2, -0.2)
	leaf_curve.add_point(Vector2(1.0, 0.4), -1.2, 0.0)
	w2_leaves.scale_amount_curve = leaf_curve

	var leaf_grad = Gradient.new()
	leaf_grad.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	leaf_grad.colors = PackedColorArray([
		Color(0.50, 0.85, 0.55, 0.0),
		Color(0.35, 0.75, 0.45, 0.85),
		Color(0.25, 0.65, 0.35, 0.80),
		Color(0.15, 0.45, 0.20, 0.0)
	])
	w2_leaves.color_ramp = leaf_grad
	w2_bg_container.add_child(w2_leaves)

	# 8. Forest Vignette
	var vig_grad = Gradient.new()
	vig_grad.offsets = PackedFloat32Array([0.45, 0.85, 1.0])
	vig_grad.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.02, 0.12, 0.06, 0.25),
		Color(0.01, 0.05, 0.02, 0.55)
	])
	var vig_tex = GradientTexture2D.new()
	vig_tex.gradient = vig_grad
	vig_tex.fill = GradientTexture2D.FILL_RADIAL
	vig_tex.fill_from = Vector2(0.5, 0.5)
	vig_tex.fill_to = Vector2(1.0, 1.0)

	w2_vignette = TextureRect.new()
	w2_vignette.name = "ForestVignette"
	w2_vignette.texture = vig_tex
	w2_vignette.set_anchors_preset(PRESET_FULL_RECT)
	w2_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	w2_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w2_bg_container.add_child(w2_vignette)

# ================= FLOWING FLAMES BACKGROUND =================
func build_flames_fx():
	flame_layer = Control.new()
	flame_layer.name = "FlameLayer"
	flame_layer.set_anchors_preset(PRESET_FULL_RECT)
	flame_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flame_layer)

	# (no background glow rect — just pure particles)

	# Flowing ground flames particle emitter across full bottom width
	flame_particles = CPUParticles2D.new()
	flame_particles.name = "FlameParticles"
	flame_particles.position = Vector2(960, 1080)
	flame_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flame_particles.emission_rect_extents = Vector2(1000, 24)
	flame_particles.direction = Vector2(0, -1)
	flame_particles.spread = 24.0
	flame_particles.gravity = Vector2(0, -110)
	flame_particles.initial_velocity_min = 140.0
	flame_particles.initial_velocity_max = 260.0
	flame_particles.tangential_accel_min = -50.0
	flame_particles.tangential_accel_max = 50.0
	flame_particles.lifetime = 1.6
	flame_particles.amount = 130
	flame_particles.scale_amount_min = 8.0
	flame_particles.scale_amount_max = 20.0
	
	var flame_grad = Gradient.new()
	flame_grad.set_color(0, Color(1.0, 0.95, 0.65, 0.95))
	flame_grad.add_point(0.24, Color(1.0, 0.55, 0.12, 0.9))
	flame_grad.add_point(0.58, Color(0.85, 0.18, 0.1, 0.65))
	flame_grad.add_point(0.84, Color(0.35, 0.06, 0.06, 0.3))
	flame_grad.set_color(flame_grad.get_point_count() - 1, Color(0.08, 0.02, 0.02, 0.0))
	flame_particles.color_ramp = flame_grad
	flame_layer.add_child(flame_particles)

	# Ambient rising embers emitter drifting across the full menu screen
	ember_particles = CPUParticles2D.new()
	ember_particles.name = "EmberParticles"
	ember_particles.position = Vector2(960, 1080)
	ember_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ember_particles.emission_rect_extents = Vector2(980, 50)
	ember_particles.direction = Vector2(0, -1)
	ember_particles.spread = 38.0
	ember_particles.gravity = Vector2(0, -55)
	ember_particles.initial_velocity_min = 70.0
	ember_particles.initial_velocity_max = 160.0
	ember_particles.tangential_accel_min = -30.0
	ember_particles.tangential_accel_max = 30.0
	ember_particles.lifetime = 3.6
	ember_particles.amount = 75
	ember_particles.scale_amount_min = 2.0
	ember_particles.scale_amount_max = 4.5
	
	var ember_grad = Gradient.new()
	ember_grad.set_color(0, Color(1.0, 0.82, 0.35, 0.95))
	ember_grad.add_point(0.65, Color(0.95, 0.4, 0.12, 0.75))
	ember_grad.set_color(ember_grad.get_point_count() - 1, Color(0.6, 0.1, 0.1, 0.0))
	ember_particles.color_ramp = ember_grad
	flame_layer.add_child(ember_particles)

# ================= LOADING SCREEN VIEW =================
func build_loading_screen_view():
	loading_container = Control.new()
	loading_container.name = "LoadingScreen"
	loading_container.set_anchors_preset(PRESET_FULL_RECT)
	loading_container.visible = false
	loading_container.modulate.a = 0.0
	loading_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(loading_container)

	# 1. Dark Atmospheric Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.015, 0.01, 0.03, 0.98)
	loading_container.add_child(bg)

	# Ambient embers inside loading screen
	var load_embers = CPUParticles2D.new()
	load_embers.position = Vector2(960, 1080)
	load_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	load_embers.emission_rect_extents = Vector2(980, 40)
	load_embers.direction = Vector2(0, -1)
	load_embers.spread = 35.0
	load_embers.gravity = Vector2(0, -60)
	load_embers.initial_velocity_min = 60.0
	load_embers.initial_velocity_max = 140.0
	load_embers.lifetime = 3.0
	load_embers.amount = 45
	load_embers.scale_amount_min = 2.0
	load_embers.scale_amount_max = 4.0
	load_embers.color = Color(1.0, 0.7, 0.25, 0.8)
	loading_container.add_child(load_embers)

	# 2. Top Header: ENTERING THE ABYSS...
	var header = Label.new()
	header.text = "ENTERING THE ABYSS..."
	if pop_font:
		header.add_theme_font_override("font", pop_font)
	header.add_theme_font_size_override("font_size", 38)
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	header.add_theme_color_override("font_shadow_color", Color(0.65, 0.15, 0.1, 0.95))
	header.add_theme_constant_override("shadow_offset_x", 3)
	header.add_theme_constant_override("shadow_offset_y", 3)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(PRESET_CENTER)
	header.offset_left = -500
	header.offset_top = -280
	header.offset_right = 500
	header.offset_bottom = -220
	loading_container.add_child(header)

	# Subtitle: SYNCHRONIZING TIMELINE . . .
	loading_subtitle = Label.new()
	loading_subtitle.name = "LoadingSubtitle"
	loading_subtitle.text = "SYNCHRONIZING TIMELINE . . ."
	loading_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_subtitle.set_anchors_preset(PRESET_CENTER)
	loading_subtitle.offset_left = -400
	loading_subtitle.offset_top = -220
	loading_subtitle.offset_right = 400
	loading_subtitle.offset_bottom = -190
	loading_subtitle.add_theme_font_size_override("font_size", 16)
	loading_subtitle.add_theme_color_override("font_color", Color(0.85, 0.78, 0.92, 0.85))
	loading_container.add_child(loading_subtitle)

	# 3. Center Stage: Running Nobab!
	var stage = Control.new()
	stage.name = "NobabRunningStage"
	stage.set_anchors_preset(PRESET_CENTER)
	stage.custom_minimum_size = Vector2(700, 200)
	stage.offset_left = -350
	stage.offset_top = -140
	stage.offset_right = 350
	stage.offset_bottom = 60
	loading_container.add_child(stage)

	# Ground runner line
	loading_runner_line = ColorRect.new()
	loading_runner_line.custom_minimum_size = Vector2(650, 4)
	loading_runner_line.set_anchors_preset(PRESET_CENTER)
	loading_runner_line.offset_left = -325
	loading_runner_line.offset_top = 70
	loading_runner_line.offset_right = 325
	loading_runner_line.offset_bottom = 74
	loading_runner_line.color = Color(0.85, 0.65, 0.28, 0.9)
	stage.add_child(loading_runner_line)

	var runner_glow = ColorRect.new()
	runner_glow.custom_minimum_size = Vector2(650, 2)
	runner_glow.set_anchors_preset(PRESET_CENTER)
	runner_glow.offset_left = -325
	runner_glow.offset_top = 74
	runner_glow.offset_right = 325
	runner_glow.offset_bottom = 76
	runner_glow.color = Color(0.85, 0.25, 0.15, 0.6)
	stage.add_child(runner_glow)

	# Speed dust particles shooting backwards behind Nobab's sprint
	loading_dust_particles = CPUParticles2D.new()
	loading_dust_particles.name = "RunningDust"
	loading_dust_particles.position = Vector2(330, 168)
	loading_dust_particles.direction = Vector2(-1, -0.3)
	loading_dust_particles.spread = 20.0
	loading_dust_particles.gravity = Vector2(0, 80)
	loading_dust_particles.initial_velocity_min = 120.0
	loading_dust_particles.initial_velocity_max = 240.0
	loading_dust_particles.lifetime = 0.4
	loading_dust_particles.amount = 26
	loading_dust_particles.scale_amount_min = 2.0
	loading_dust_particles.scale_amount_max = 4.5
	loading_dust_particles.color = Color(0.9, 0.78, 0.45, 0.7)
	stage.add_child(loading_dust_particles)

	# Nobab Running Sprite!
	loading_nobab_sprite = AnimatedSprite2D.new()
	loading_nobab_sprite.name = "LoadingNobabSprite"
	loading_nobab_sprite.position = Vector2(350, 85)
	loading_nobab_sprite.scale = Vector2(4.5, 4.5)
	loading_nobab_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(loading_nobab_sprite)

	var frames = get_nobab_sprite_frames()
	if frames:
		loading_nobab_sprite.sprite_frames = frames
		if frames.has_animation("sprint"):
			loading_nobab_sprite.play("sprint")

	# 4. Progress Bar Section
	var bar_box = Control.new()
	bar_box.set_anchors_preset(PRESET_CENTER)
	bar_box.custom_minimum_size = Vector2(650, 50)
	bar_box.offset_left = -325
	bar_box.offset_top = 90
	bar_box.offset_right = 325
	bar_box.offset_bottom = 140
	loading_container.add_child(bar_box)

	loading_progress_bar = ProgressBar.new()
	loading_progress_bar.custom_minimum_size = Vector2(650, 22)
	loading_progress_bar.set_anchors_preset(PRESET_CENTER)
	loading_progress_bar.offset_left = -325
	loading_progress_bar.offset_top = -11
	loading_progress_bar.offset_right = 325
	loading_progress_bar.offset_bottom = 11
	loading_progress_bar.min_value = 0.0
	loading_progress_bar.max_value = 100.0
	loading_progress_bar.value = 0.0
	loading_progress_bar.show_percentage = false

	var bar_bg = create_stylebox(Color(0.06, 0.04, 0.10, 0.95), Color(0.7, 0.52, 0.25, 0.85), 6, 2)
	var bar_fill = create_stylebox(Color(0.85, 0.28, 0.15, 0.95), Color(1.0, 0.82, 0.35, 1.0), 5, 1)
	loading_progress_bar.add_theme_stylebox_override("background", bar_bg)
	loading_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	bar_box.add_child(loading_progress_bar)

	# Percentage Label
	loading_percent_label = Label.new()
	loading_percent_label.text = "0 %"
	if pop_font:
		loading_percent_label.add_theme_font_override("font", pop_font)
	loading_percent_label.add_theme_font_size_override("font_size", 16)
	loading_percent_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5, 1.0))
	loading_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_percent_label.set_anchors_preset(PRESET_CENTER)
	loading_percent_label.offset_left = -100
	loading_percent_label.offset_top = 22
	loading_percent_label.offset_right = 100
	loading_percent_label.offset_bottom = 48
	bar_box.add_child(loading_percent_label)

	# 5. Tips Box
	var tips_box = VBoxContainer.new()
	tips_box.set_anchors_preset(PRESET_CENTER)
	tips_box.custom_minimum_size = Vector2(800, 100)
	tips_box.offset_left = -400
	tips_box.offset_top = 180
	tips_box.offset_right = 400
	tips_box.offset_bottom = 280
	tips_box.add_theme_constant_override("separation", 10)
	tips_box.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_container.add_child(tips_box)

	var dec_tips = Label.new()
	dec_tips.text = "✦  ━━━━━━━━━━━━━ ⚔ ━━━━━━━━━━━━━  ✦"
	dec_tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dec_tips.add_theme_color_override("font_color", Color(0.75, 0.55, 0.3, 0.65))
	tips_box.add_child(dec_tips)

	loading_tip_label = Label.new()
	loading_tip_label.text = loading_tips[0]
	loading_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	loading_tip_label.add_theme_font_size_override("font_size", 15)
	loading_tip_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.95, 0.9))
	tips_box.add_child(loading_tip_label)

# ================= LOADING CONTROL HELPERS =================
func start_loading_sequence(on_complete: Callable = Callable()):
	if is_loading:
		return
	is_loading = true
	loading_callback = on_complete
	loading_progress = 0.0
	loading_timer = 0.0
	loading_dots_timer = 0.0

	# Hide menu views & flames
	if main_view_container:
		main_view_container.visible = false
	if char_select_container:
		char_select_container.visible = false
	if options_container:
		options_container.visible = false
	if flame_layer:
		flame_layer.visible = false

	# Pick random gameplay tip
	if loading_tip_label and loading_tips.size() > 0:
		loading_tip_label.text = loading_tips[randi() % loading_tips.size()]

	# Show and fade in loading screen
	if loading_container:
		loading_container.visible = true
		loading_container.modulate.a = 0.0
		var in_tween = create_tween()
		in_tween.tween_property(loading_container, "modulate:a", 1.0, 0.25)

	if loading_nobab_sprite and loading_nobab_sprite.sprite_frames:
		if loading_nobab_sprite.sprite_frames.has_animation("sprint"):
			loading_nobab_sprite.play("sprint")

func finish_loading_sequence():
	if not is_loading:
		return
	is_loading = false

	var out_tween = create_tween()
	if loading_container:
		out_tween.tween_property(loading_container, "modulate:a", 0.0, 0.35)
	out_tween.finished.connect(func():
		if loading_container:
			loading_container.visible = false
		emit_signal("play_game")
		if loading_callback.is_valid():
			loading_callback.call()
	)

func build_main_view():
	# Hide or reuse existing CenterBox if present
	var old_center = get_node_or_null("CenterBox")
	if old_center:
		old_center.visible = false

	main_view_container = Control.new()
	main_view_container.name = "MainView"
	main_view_container.set_anchors_preset(PRESET_FULL_RECT)
	add_child(main_view_container)

	var center_vbox = VBoxContainer.new()
	center_vbox.set_anchors_preset(PRESET_CENTER)
	center_vbox.custom_minimum_size = Vector2(650, 600)
	center_vbox.offset_left = -325
	center_vbox.offset_top = -300
	center_vbox.offset_right = 325
	center_vbox.offset_bottom = 300
	center_vbox.add_theme_constant_override("separation", 18)
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_view_container.add_child(center_vbox)

	# Ornate Top Header Filigree
	var dec_top = Label.new()
	dec_top.text = "✦  ━━━━━━━━━━━━━  ✦"
	dec_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dec_top.add_theme_color_override("font_color", Color(0.85, 0.65, 0.35, 0.75))
	center_vbox.add_child(dec_top)

	# Title: Rokto & Rust (Exact text preserved!)
	var title = Label.new()
	title.name = "Title"
	title.text = "Rokto & Rust"
	if pop_font:
		title.add_theme_font_override("font", pop_font)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.65, 0.15, 0.1, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(title)

	# Subtitle: TOUGH TIMES ?? (Exact text preserved!)
	var prompt = Label.new()
	prompt.name = "PressEnterPrompt"
	prompt.text = "TOUGH TIMES ??"
	if pop_font:
		prompt.add_theme_font_override("font", pop_font)
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	prompt.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(prompt)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	center_vbox.add_child(spacer)

	# 1. PLAY BUTTON (Exact StartButton name for backward compatibility with world.gd!)
	var play_btn = Button.new()
	play_btn.name = "StartButton"
	play_btn.custom_minimum_size = Vector2(340, 54)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_metroidvania_button(play_btn, "PLAY  •  TEST YOUR FATE", 19, true)
	play_btn.pressed.connect(func():
		start_loading_sequence()
	)
	center_vbox.add_child(play_btn)

	# 2. CHARACTER SELECTION BUTTON
	var char_btn = Button.new()
	char_btn.name = "CharSelectButton"
	char_btn.custom_minimum_size = Vector2(340, 52)
	char_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_metroidvania_button(char_btn, "CHARACTER SELECTION", 18, false)
	char_btn.pressed.connect(func():
		switch_view("char_select")
	)
	center_vbox.add_child(char_btn)

	# 3. OPTIONS BUTTON
	var opt_btn = Button.new()
	opt_btn.name = "OptionsButton"
	opt_btn.custom_minimum_size = Vector2(340, 52)
	opt_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_metroidvania_button(opt_btn, "OPTIONS & REALM SETTINGS", 18, false)
	opt_btn.pressed.connect(func():
		switch_view("options")
	)
	center_vbox.add_child(opt_btn)

	# 4. QUIT BUTTON
	var quit_btn = Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.custom_minimum_size = Vector2(340, 50)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_metroidvania_button(quit_btn, "ABANDON REALM", 17, false)
	quit_btn.pressed.connect(func():
		get_tree().quit()
	)
	center_vbox.add_child(quit_btn)

# ================= CHARACTER SELECTION VIEW =================
func build_char_select_view():
	char_select_container = Control.new()
	char_select_container.name = "CharSelectView"
	char_select_container.set_anchors_preset(PRESET_FULL_RECT)
	char_select_container.visible = false
	add_child(char_select_container)

	# Header
	var header = Label.new()
	header.text = "VESSEL SELECTION"
	if pop_font:
		header.add_theme_font_override("font", pop_font)
	header.add_theme_font_size_override("font_size", 42)
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	header.add_theme_color_override("font_shadow_color", Color(0.6, 0.1, 0.1, 0.9))
	header.add_theme_constant_override("shadow_offset_x", 3)
	header.add_theme_constant_override("shadow_offset_y", 3)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(PRESET_TOP_WIDE)
	header.offset_top = 40.0
	char_select_container.add_child(header)

	var sub_header = Label.new()
	sub_header.text = "Choose your avatar to challenge the Chrono Spire"
	sub_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_header.set_anchors_preset(PRESET_TOP_WIDE)
	sub_header.offset_top = 96.0
	sub_header.add_theme_font_size_override("font_size", 16)
	sub_header.add_theme_color_override("font_color", Color(0.8, 0.75, 0.85, 0.8))
	char_select_container.add_child(sub_header)

	# Horizontal Layout: Left Side (Character Roster & Stage), Right Side (Moveset Box)
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(PRESET_CENTER)
	main_hbox.custom_minimum_size = Vector2(1650, 750)
	main_hbox.offset_left = -825
	main_hbox.offset_top = -320
	main_hbox.offset_right = 825
	main_hbox.offset_bottom = 430
	main_hbox.add_theme_constant_override("separation", 35)
	char_select_container.add_child(main_hbox)

	# ---------------- LEFT PANEL: Character Stage & Roster ----------------
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(780, 720)
	left_panel.add_theme_stylebox_override("panel", create_stylebox(Color(0.06, 0.04, 0.10, 0.95), Color(0.7, 0.52, 0.25, 0.85), 10, 2))
	main_hbox.add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 14)
	left_panel.add_child(left_vbox)

	# Character Tab Bar
	var tab_hbox = HBoxContainer.new()
	tab_hbox.custom_minimum_size = Vector2(0, 54)
	tab_hbox.add_theme_constant_override("separation", 10)
	left_vbox.add_child(tab_hbox)

	var nobab_tab = Button.new()
	nobab_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_metroidvania_button(nobab_tab, "✦ NOBAB AKA N' ✦\n[ PLAYABLE ]", 14, true)
	nobab_tab.pressed.connect(func():
		show_character_status("NOBAB AKA N'", "Betrayed. Murdered. Reincarnated into Hell.\nFights his way back with a Void Blade and Mech Arm.")
	)
	tab_hbox.add_child(nobab_tab)

	var kallista_tab = Button.new()
	kallista_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_metroidvania_button(kallista_tab, "🔒 ? UNKNOWN\n[ COMING SOON ]", 13, false)
	kallista_tab.modulate = Color(0.7, 0.7, 0.7, 0.8)
	kallista_tab.pressed.connect(func():
		show_character_status("?  UNKNOWN", "COMING SOON")
	)
	tab_hbox.add_child(kallista_tab)

	var sylvas_tab = Button.new()
	sylvas_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_metroidvania_button(sylvas_tab, "🔒 ? UNKNOWN\n[ COMING SOON ]", 13, false)
	sylvas_tab.modulate = Color(0.7, 0.7, 0.7, 0.8)
	sylvas_tab.pressed.connect(func():
		show_character_status("?  UNKNOWN", "COMING SOON")
	)
	tab_hbox.add_child(sylvas_tab)

	# Stage Area for Character Display (Runic Circle & Idle Animation)
	var stage_box = Control.new()
	stage_box.custom_minimum_size = Vector2(760, 390)
	stage_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(stage_box)

	# Decorative stage background
	var stage_bg = ColorRect.new()
	stage_bg.set_anchors_preset(PRESET_FULL_RECT)
	stage_bg.color = Color(0.02, 0.015, 0.04, 0.9)
	stage_box.add_child(stage_bg)

	# Altar Pedestal drawing
	var pedestal = ColorRect.new()
	pedestal.custom_minimum_size = Vector2(320, 24)
	pedestal.set_anchors_preset(PRESET_CENTER)
	pedestal.offset_left = -160
	pedestal.offset_top = 110
	pedestal.offset_right = 160
	pedestal.offset_bottom = 134
	pedestal.color = Color(0.18, 0.12, 0.28, 0.95)
	stage_box.add_child(pedestal)

	var ped_glow = ColorRect.new()
	ped_glow.custom_minimum_size = Vector2(340, 4)
	ped_glow.set_anchors_preset(PRESET_CENTER)
	ped_glow.offset_left = -170
	ped_glow.offset_top = 108
	ped_glow.offset_right = 170
	ped_glow.offset_bottom = 112
	ped_glow.color = Color(1.0, 0.8, 0.35, 0.9)
	stage_box.add_child(ped_glow)

	# Nobab Idle AnimatedSprite2D!
	nobab_idle_sprite = AnimatedSprite2D.new()
	nobab_idle_sprite.name = "NobabIdleSprite"
	nobab_idle_sprite.position = Vector2(380, 245)
	nobab_idle_sprite.scale = Vector2(4.2, 4.2)
	nobab_idle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage_box.add_child(nobab_idle_sprite)

	var frames = get_nobab_sprite_frames()
	if frames:
		nobab_idle_sprite.sprite_frames = frames
		if frames.has_animation("idle"):
			nobab_idle_sprite.play("idle")

	# Character Info Card
	var info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	left_vbox.add_child(info_box)

	var char_name = Label.new()
	char_name.name = "SelectedCharName"
	char_name.text = "NOBAB AKA N'"
	if pop_font:
		char_name.add_theme_font_override("font", pop_font)
	char_name.add_theme_font_size_override("font_size", 21)
	char_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	char_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_box.add_child(char_name)

	var char_lore = Label.new()
	char_lore.name = "SelectedCharLore"
	char_lore.text = "Betrayed. Murdered. Reincarnated into Hell.\nFights his way back with a Void Blade and Mech Arm."
	char_lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_lore.add_theme_font_size_override("font_size", 14)
	char_lore.add_theme_color_override("font_color", Color(0.85, 0.8, 0.9, 0.9))
	info_box.add_child(char_lore)

	var pad_bottom = Control.new()
	pad_bottom.custom_minimum_size = Vector2(0, 6)
	left_vbox.add_child(pad_bottom)

	# ---------------- RIGHT PANEL: Moveset Box with Little Animation! ----------------
	var right_panel = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(810, 720)
	right_panel.add_theme_stylebox_override("panel", create_stylebox(Color(0.06, 0.04, 0.10, 0.95), Color(0.85, 0.28, 0.35, 0.85), 10, 2))
	main_hbox.add_child(right_panel)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	# Moveset Box Title
	var moveset_title = Label.new()
	moveset_title.text = "⚔  NOBAB'S COMBAT ARSENAL  ⚔"
	if pop_font:
		moveset_title.add_theme_font_override("font", pop_font)
	moveset_title.add_theme_font_size_override("font_size", 22)
	moveset_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 1.0))
	moveset_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(moveset_title)

	# Mini Animation Preview Box (Little Animation!)
	var anim_box = PanelContainer.new()
	anim_box.custom_minimum_size = Vector2(780, 200)
	anim_box.add_theme_stylebox_override("panel", create_stylebox(Color(0.03, 0.02, 0.06, 0.98), Color(0.65, 0.45, 0.9, 0.7), 8, 2))
	right_vbox.add_child(anim_box)

	var anim_inner = Control.new()
	anim_inner.set_anchors_preset(PRESET_FULL_RECT)
	anim_box.add_child(anim_inner)

	# Preview animated sprite
	moveset_preview_sprite = AnimatedSprite2D.new()
	moveset_preview_sprite.name = "MovesetPreviewSprite"
	moveset_preview_sprite.position = Vector2(390, 100)
	moveset_preview_sprite.scale = Vector2(3.8, 3.8)
	moveset_preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim_inner.add_child(moveset_preview_sprite)

	if frames:
		moveset_preview_sprite.sprite_frames = frames
		moveset_preview_sprite.play("sword")

	# Status Label below preview
	moveset_status_label = Label.new()
	moveset_status_label.text = MOVESET_NAMES[0]
	moveset_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moveset_status_label.set_anchors_preset(PRESET_BOTTOM_WIDE)
	moveset_status_label.offset_top = -32.0
	moveset_status_label.add_theme_font_size_override("font_size", 14)
	moveset_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.75, 1.0))
	anim_inner.add_child(moveset_status_label)

	# Detailed Moveset Descriptions
	var moves_vbox = VBoxContainer.new()
	moves_vbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(moves_vbox)

	moves_vbox.add_child(create_move_card("VOID BLADE SLICE", "[ LMB / J ]", "Quick sword strike. 35 DMG.", Color(1.0, 0.4, 0.4, 1.0)))
	moves_vbox.add_child(create_move_card("MECH ARM OVERDRIVE", "[ T / K ]", "Ground slam shockwave. 55 DMG, knocks enemies back.", Color(0.3, 0.9, 1.0, 1.0)))
	moves_vbox.add_child(create_move_card("SHADOW PHASE DODGE", "[ M / C / SHIFT ]", "Invulnerable roll dodge.", Color(0.9, 0.8, 0.3, 1.0)))
	moves_vbox.add_child(create_move_card("TACTICAL SPRINT", "[ SHIFT + A/D ]", "Sprint across the battlefield.", Color(0.8, 0.6, 0.95, 1.0)))

	# Bottom Action Buttons
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 16)
	right_vbox.add_child(action_hbox)

	var embark_btn = Button.new()
	embark_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	embark_btn.custom_minimum_size = Vector2(0, 52)
	style_metroidvania_button(embark_btn, "EMBARK AS NOBAB  •  PLAY", 18, true)
	embark_btn.pressed.connect(func():
		start_loading_sequence()
	)
	action_hbox.add_child(embark_btn)

	var back_btn = Button.new()
	back_btn.custom_minimum_size = Vector2(220, 52)
	style_metroidvania_button(back_btn, "BACK TO MENU", 17, false)
	back_btn.pressed.connect(func():
		switch_view("main")
	)
	action_hbox.add_child(back_btn)

func create_move_card(move_title: String, keys: String, desc: String, accent_col: Color) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 68)
	card.add_theme_stylebox_override("panel", create_stylebox(Color(0.10, 0.07, 0.16, 0.85), accent_col.darkened(0.4), 6, 1))

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)

	var title_hb = HBoxContainer.new()
	vb.add_child(title_hb)

	var t_lbl = Label.new()
	t_lbl.text = move_title
	t_lbl.add_theme_font_size_override("font_size", 15)
	t_lbl.add_theme_color_override("font_color", accent_col)
	title_hb.add_child(t_lbl)

	var k_lbl = Label.new()
	k_lbl.text = "   " + keys
	k_lbl.add_theme_font_size_override("font_size", 13)
	k_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1.0))
	title_hb.add_child(k_lbl)

	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.add_theme_font_size_override("font_size", 13)
	d_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.88, 0.85))
	vb.add_child(d_lbl)

	return card

func cycle_moveset_animation():
	if not moveset_preview_sprite or not moveset_preview_sprite.sprite_frames:
		return
	moveset_anim_index = (moveset_anim_index + 1) % MOVESET_CYCLE.size()
	var anim = MOVESET_CYCLE[moveset_anim_index]
	if moveset_preview_sprite.sprite_frames.has_animation(anim):
		moveset_preview_sprite.stop()
		moveset_preview_sprite.play(anim)
	if moveset_status_label:
		moveset_status_label.text = MOVESET_NAMES[moveset_anim_index]

func show_character_status(char_name: String, lore_text: String):
	var name_lbl = find_child("SelectedCharName", true, false)
	if name_lbl:
		name_lbl.text = char_name
	var lore_lbl = find_child("SelectedCharLore", true, false)
	if lore_lbl:
		lore_lbl.text = lore_text

# ================= OPTIONS VIEW =================
func build_options_view():
	options_container = Control.new()
	options_container.name = "OptionsView"
	options_container.set_anchors_preset(PRESET_FULL_RECT)
	options_container.visible = false
	add_child(options_container)

	var center_panel = PanelContainer.new()
	center_panel.custom_minimum_size = Vector2(900, 680)
	center_panel.set_anchors_preset(PRESET_CENTER)
	center_panel.offset_left = -450
	center_panel.offset_top = -340
	center_panel.offset_right = 450
	center_panel.offset_bottom = 340
	center_panel.add_theme_stylebox_override("panel", create_stylebox(Color(0.06, 0.04, 0.11, 0.96), Color(0.75, 0.55, 0.28, 0.9), 12, 2))
	options_container.add_child(center_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	center_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "REALM SETTINGS"
	if pop_font:
		header.add_theme_font_override("font", pop_font)
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# 1. SOUND VOLUME (Decrease & Increase Sound)
	var sound_title = Label.new()
	sound_title.text = "🔊  MASTER AUDIO VOLUME"
	sound_title.add_theme_font_size_override("font_size", 18)
	sound_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	vbox.add_child(sound_title)

	var sound_hbox = HBoxContainer.new()
	sound_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(sound_hbox)

	var vol_down_btn = Button.new()
	vol_down_btn.custom_minimum_size = Vector2(65, 42)
	style_metroidvania_button(vol_down_btn, "[ - ]", 18, false)
	vol_down_btn.pressed.connect(func():
		if has_node("/root/SettingsManager"):
			get_node("/root/SettingsManager").decrease_volume(10.0)
	)
	sound_hbox.add_child(vol_down_btn)

	volume_bar = ProgressBar.new()
	volume_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_bar.custom_minimum_size = Vector2(0, 36)
	volume_bar.min_value = 0.0
	volume_bar.max_value = 100.0
	volume_bar.step = 1.0
	volume_bar.value = 85.0
	volume_bar.show_percentage = false
	sound_hbox.add_child(volume_bar)

	var vol_up_btn = Button.new()
	vol_up_btn.custom_minimum_size = Vector2(65, 42)
	style_metroidvania_button(vol_up_btn, "[ + ]", 18, false)
	vol_up_btn.pressed.connect(func():
		if has_node("/root/SettingsManager"):
			get_node("/root/SettingsManager").increase_volume(10.0)
	)
	sound_hbox.add_child(vol_up_btn)

	volume_label = Label.new()
	volume_label.custom_minimum_size = Vector2(85, 0)
	volume_label.text = "85%"
	volume_label.add_theme_font_size_override("font_size", 18)
	volume_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85, 1.0))
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sound_hbox.add_child(volume_label)

	# 2. RESOLUTION (Decrease & Increase Resolution + Fullscreen)
	var res_title = Label.new()
	res_title.text = "🖥  DISPLAY RESOLUTION & SCREEN MODE"
	res_title.add_theme_font_size_override("font_size", 18)
	res_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	vbox.add_child(res_title)

	var res_hbox = HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(res_hbox)

	var res_prev_btn = Button.new()
	res_prev_btn.custom_minimum_size = Vector2(90, 42)
	style_metroidvania_button(res_prev_btn, "[ < PREV ]", 15, false)
	res_prev_btn.pressed.connect(func():
		if has_node("/root/SettingsManager"):
			get_node("/root/SettingsManager").prev_resolution()
	)
	res_hbox.add_child(res_prev_btn)

	resolution_label = Label.new()
	resolution_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution_label.text = "1920 x 1080 (FHD)"
	resolution_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolution_label.add_theme_font_size_override("font_size", 18)
	resolution_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85, 1.0))
	res_hbox.add_child(resolution_label)

	var res_next_btn = Button.new()
	res_next_btn.custom_minimum_size = Vector2(90, 42)
	style_metroidvania_button(res_next_btn, "[ NEXT > ]", 15, false)
	res_next_btn.pressed.connect(func():
		if has_node("/root/SettingsManager"):
			get_node("/root/SettingsManager").next_resolution()
	)
	res_hbox.add_child(res_next_btn)

	fullscreen_btn = Button.new()
	fullscreen_btn.custom_minimum_size = Vector2(180, 42)
	style_metroidvania_button(fullscreen_btn, "FULLSCREEN: OFF", 15, false)
	fullscreen_btn.pressed.connect(func():
		if has_node("/root/SettingsManager"):
			get_node("/root/SettingsManager").toggle_fullscreen()
	)
	res_hbox.add_child(fullscreen_btn)

	# 3. GRAPHICS QUALITY (High / Normal / Low)
	var gfx_title = Label.new()
	gfx_title.text = "✨  GRAPHICS QUALITY & POLISH PRESETS"
	gfx_title.add_theme_font_size_override("font_size", 18)
	gfx_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	vbox.add_child(gfx_title)

	var gfx_hbox = HBoxContainer.new()
	gfx_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(gfx_hbox)

	low_btn = Button.new()
	low_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low_btn.custom_minimum_size = Vector2(0, 44)
	style_metroidvania_button(low_btn, "LOW", 16, false)
	low_btn.pressed.connect(func():
		if has_node("/root/SettingsManager"):
			get_node("/root/SettingsManager").set_graphics_quality("low")
	)
	gfx_hbox.add_child(low_btn)

	normal_btn = Button.new()
	normal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	normal_btn.custom_minimum_size = Vector2(0, 44)
	style_metroidvania_button(normal_btn, "NORMAL", 16, false)
	normal_btn.pressed.connect(func():
		if has_node("/root/SettingsManager"):
			get_node("/root/SettingsManager").set_graphics_quality("normal")
	)
	gfx_hbox.add_child(normal_btn)

	high_btn = Button.new()
	high_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	high_btn.custom_minimum_size = Vector2(0, 44)
	style_metroidvania_button(high_btn, "HIGH", 16, true)
	high_btn.pressed.connect(func():
		if has_node("/root/SettingsManager"):
			get_node("/root/SettingsManager").set_graphics_quality("high")
	)
	gfx_hbox.add_child(high_btn)

	# Graphics Polish Description Card
	var gfx_card = PanelContainer.new()
	gfx_card.custom_minimum_size = Vector2(0, 110)
	gfx_card.add_theme_stylebox_override("panel", create_stylebox(Color(0.04, 0.03, 0.07, 0.9), Color(0.5, 0.35, 0.7, 0.6), 8, 1))
	vbox.add_child(gfx_card)

	var gfx_margin = MarginContainer.new()
	gfx_margin.add_theme_constant_override("margin_left", 14)
	gfx_margin.add_theme_constant_override("margin_right", 14)
	gfx_margin.add_theme_constant_override("margin_top", 10)
	gfx_margin.add_theme_constant_override("margin_bottom", 10)
	gfx_card.add_child(gfx_margin)

	graphics_desc_label = Label.new()
	graphics_desc_label.text = "Full effects — flames, embers, glow. Maximum polish."
	graphics_desc_label.add_theme_font_size_override("font_size", 14)
	graphics_desc_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 0.95))
	gfx_margin.add_child(graphics_desc_label)

	# Back Button
	var back_btn = Button.new()
	back_btn.custom_minimum_size = Vector2(240, 48)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_metroidvania_button(back_btn, "BACK TO MAIN MENU", 17, false)
	back_btn.pressed.connect(func():
		switch_view("main")
	)
	vbox.add_child(back_btn)

# ================= VIEW SWITCHER =================
func switch_view(view_name: String):
	if is_loading:
		return
	current_view = view_name
	if flame_layer:
		flame_layer.visible = true
	if main_view_container:
		main_view_container.visible = (view_name == "main")
	if char_select_container:
		char_select_container.visible = (view_name == "char_select")
	if options_container:
		options_container.visible = (view_name == "options")
	if loading_container:
		loading_container.visible = false

	if view_name == "char_select":
		moveset_timer = 0.0
		moveset_anim_index = 0
		if nobab_idle_sprite and nobab_idle_sprite.sprite_frames:
			nobab_idle_sprite.play("idle")
		if moveset_preview_sprite and moveset_preview_sprite.sprite_frames:
			moveset_preview_sprite.play("sword")
		if moveset_status_label:
			moveset_status_label.text = MOVESET_NAMES[0]
	elif view_name == "options":
		update_options_ui()

# ================= OPTIONS EVENT HANDLERS =================
func _on_settings_volume_changed(val: float):
	if volume_bar:
		volume_bar.value = val
	if volume_label:
		volume_label.text = str(int(val)) + "%"

func _on_settings_res_changed(res: Vector2i, is_fs: bool):
	if resolution_label:
		resolution_label.text = str(res.x) + " x " + str(res.y)
	if fullscreen_btn:
		fullscreen_btn.text = "FULLSCREEN: " + ("ON" if is_fs else "OFF")

func _on_settings_graphics_changed(q: String):
	update_graphics_buttons_ui(q)

func update_options_ui():
	if not is_inside_tree() or not has_node("/root/SettingsManager"):
		return
	var sm = get_node("/root/SettingsManager")
	_on_settings_volume_changed(sm.master_volume)
	_on_settings_res_changed(sm.RESOLUTIONS[clamp(sm.resolution_index, 0, sm.RESOLUTIONS.size() - 1)], sm.is_fullscreen)
	update_graphics_buttons_ui(sm.graphics_quality)

func update_graphics_buttons_ui(quality: String):
	if low_btn:
		low_btn.modulate = Color(1.4, 1.4, 0.4, 1.0) if quality == "low" else Color(0.7, 0.7, 0.7, 0.85)
	if normal_btn:
		normal_btn.modulate = Color(1.4, 1.4, 0.4, 1.0) if quality == "normal" else Color(0.7, 0.7, 0.7, 0.85)
	if high_btn:
		high_btn.modulate = Color(1.4, 1.4, 0.4, 1.0) if quality == "high" else Color(0.7, 0.7, 0.7, 0.85)

	if flame_particles:
		if quality == "high":
			flame_particles.amount = 130
			flame_particles.visible = true
		elif quality == "normal":
			flame_particles.amount = 60
			flame_particles.visible = true
		else: # low
			flame_particles.amount = 20
			flame_particles.visible = true

	if ember_particles:
		if quality == "high":
			ember_particles.amount = 75
			ember_particles.visible = true
		elif quality == "normal":
			ember_particles.amount = 30
			ember_particles.visible = true
		else: # low
			ember_particles.amount = 8
			ember_particles.visible = false

	if w2_spores:
		if quality == "high":
			w2_spores.amount = 45
			w2_spores.visible = true
		elif quality == "normal":
			w2_spores.amount = 20
			w2_spores.visible = true
		else: # low
			w2_spores.amount = 5
			w2_spores.visible = false

	if w2_leaves:
		if quality == "high":
			w2_leaves.amount = 22
			w2_leaves.visible = true
		elif quality == "normal":
			w2_leaves.amount = 10
			w2_leaves.visible = true
		else: # low
			w2_leaves.amount = 4
			w2_leaves.visible = false

	if graphics_desc_label:
		if quality == "high":
			graphics_desc_label.text = "Full effects — flames, embers, glow. Maximum polish."
			graphics_desc_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 0.95))
		elif quality == "normal":
			graphics_desc_label.text = "Balanced — moderate particles, soft ambient lighting."
			graphics_desc_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.95))
		else: # low
			graphics_desc_label.text = "Performance — minimal effects, crisp pixel look."
			graphics_desc_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.85, 0.95))

# ================= HELPERS =================
var cached_nobab_frames: SpriteFrames = null
func get_nobab_sprite_frames() -> SpriteFrames:
	if cached_nobab_frames:
		return cached_nobab_frames
	var player_scene = load("res://scenes/player/character_body_2d.tscn")
	if player_scene:
		var temp_node = player_scene.instantiate()
		var anim_sprite = temp_node.get_node_or_null("AnimatedSprite2D")
		if anim_sprite and anim_sprite.sprite_frames:
			cached_nobab_frames = anim_sprite.sprite_frames
			temp_node.queue_free()
			return cached_nobab_frames
		temp_node.queue_free()
	return null
