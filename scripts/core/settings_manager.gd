extends Node

const CONFIG_PATH = "user://settings.cfg"

var master_volume: float = 85.0 # 0% to 100%
var resolution_index: int = 2   # Default 1920x1080
var is_fullscreen: bool = false
var graphics_quality: String = "high" # "high", "normal", "low"

const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

const RESOLUTION_LABELS = [
	"1280 x 720 (HD)",
	"1600 x 900 (HD+)",
	"1920 x 1080 (FHD)",
	"2560 x 1440 (QHD)"
]

signal volume_changed(new_vol)
signal resolution_changed(new_res, is_fs)
signal graphics_changed(new_quality)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all_settings()

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		master_volume = cfg.get_value("audio", "master_volume", 85.0)
		resolution_index = cfg.get_value("display", "resolution_index", 2)
		is_fullscreen = cfg.get_value("display", "is_fullscreen", false)
		graphics_quality = cfg.get_value("graphics", "graphics_quality", "high")

func save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("display", "is_fullscreen", is_fullscreen)
	cfg.set_value("graphics", "graphics_quality", graphics_quality)
	cfg.save(CONFIG_PATH)

func apply_all_settings():
	apply_volume(master_volume)
	apply_resolution(resolution_index, is_fullscreen)
	apply_graphics_quality(graphics_quality)

# ================= AUDIO =================
func set_volume(val: float):
	master_volume = clampf(val, 0.0, 100.0)
	apply_volume(master_volume)
	save_settings()
	emit_signal("volume_changed", master_volume)

func increase_volume(step: float = 5.0):
	set_volume(master_volume + step)

func decrease_volume(step: float = 5.0):
	set_volume(master_volume - step)

func apply_volume(val: float):
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if val <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			# Convert linear 0..100 to db (-40dB to 0dB)
			var linear = val / 100.0
			var db = linear_to_db(linear)
			AudioServer.set_bus_volume_db(bus_idx, db)

# ================= DISPLAY / RESOLUTION =================
func set_resolution_index(idx: int):
	resolution_index = posmod(idx, RESOLUTIONS.size())
	apply_resolution(resolution_index, is_fullscreen)
	save_settings()
	emit_signal("resolution_changed", RESOLUTIONS[resolution_index], is_fullscreen)

func next_resolution():
	set_resolution_index(resolution_index + 1)

func prev_resolution():
	set_resolution_index(resolution_index - 1)

func toggle_fullscreen():
	is_fullscreen = not is_fullscreen
	apply_resolution(resolution_index, is_fullscreen)
	save_settings()
	emit_signal("resolution_changed", RESOLUTIONS[resolution_index], is_fullscreen)

func set_fullscreen(fs: bool):
	is_fullscreen = fs
	apply_resolution(resolution_index, is_fullscreen)
	save_settings()
	emit_signal("resolution_changed", RESOLUTIONS[resolution_index], is_fullscreen)

func get_current_resolution_text() -> String:
	if is_fullscreen:
		return RESOLUTION_LABELS[clamp(resolution_index, 0, RESOLUTION_LABELS.size() - 1)] + " [FULLSCREEN]"
	return RESOLUTION_LABELS[clamp(resolution_index, 0, RESOLUTION_LABELS.size() - 1)]

func apply_resolution(idx: int, fs: bool):
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var target_size = RESOLUTIONS[clamp(idx, 0, RESOLUTIONS.size() - 1)]
		DisplayServer.window_set_size(target_size)
		var screen_rect = DisplayServer.screen_get_usable_rect()
		var center_pos = screen_rect.position + (screen_rect.size - target_size) / 2
		DisplayServer.window_set_position(center_pos)

# ================= GRAPHICS PRESETS =================
func set_graphics_quality(quality: String):
	if quality in ["high", "normal", "low"]:
		graphics_quality = quality
		apply_graphics_quality(graphics_quality)
		save_settings()
		emit_signal("graphics_changed", graphics_quality)

func apply_graphics_quality(quality: String, target_root: Node = null):
	var root = target_root
	if root == null and is_inside_tree():
		root = get_tree().root
	if not root:
		return
	
	# 1. Particles (Hellfire, embers, smoke, backdrop)
	var particles = root.find_children("*", "CPUParticles2D", true, false)
	for p in particles:
		var p_name = p.name.to_lower()
		if "smoke" in p_name or "ember" in p_name:
			if quality == "low":
				p.emitting = false
				p.visible = false
			elif quality == "normal":
				p.emitting = true
				p.visible = true
				p.amount = max(6, int(p.amount * 0.45))
			else: # high
				p.emitting = true
				p.visible = true
				if "smoke" in p_name:
					p.amount = 28
				elif "backgroundembers" in p_name:
					p.amount = 30
				elif "embers" in p_name:
					p.amount = 70
		elif "hellfire" in p_name:
			if quality == "low":
				p.emitting = true
				p.visible = true
				p.amount = 18
			elif quality == "normal":
				p.emitting = true
				p.visible = true
				p.amount = 45
			else: # high
				p.emitting = true
				p.visible = true
				p.amount = 120 if p.name == "hellfire" else 80
		else:
			p.emitting = (quality != "low")

	# 2. Vignettes
	var vignettes = root.find_children("*Vignette*", "TextureRect", true, false)
	for v in vignettes:
		if quality == "low":
			v.visible = false
		elif quality == "normal":
			v.visible = true
			v.modulate.a = 0.45
		else:
			v.visible = true
			v.modulate.a = 1.0

	# 3. Horizon Glows & Special Atmosphere
	var horizon_glows = root.find_children("*HorizonGlow*", "TextureRect", true, false)
	for g in horizon_glows:
		if quality == "low":
			g.visible = false
		elif quality == "normal":
			g.visible = true
			g.modulate.a = 0.35
		else:
			g.visible = true
			g.modulate.a = 0.85

	# 4. Forest Lights (Level 2)
	var forest_lights = root.find_children("*ForestLights*", "Node2D", true, false)
	for fl in forest_lights:
		if quality == "low":
			fl.visible = false
		elif quality == "normal":
			fl.visible = true
			fl.modulate.a = 0.30
		else:
			fl.visible = true
			fl.modulate.a = 0.75

