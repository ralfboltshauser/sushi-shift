extends Node

const ASSET_ROOT := "res://assets/quaternius-sushi-restaurant-kit/Sushi Restaurant Kit - May 2023"
const SHIFT_LENGTH := 180.0
const PLAYER_SPEED := 5.4
const PLAYER_RADIUS := 0.32
const INTERACT_DISTANCE := 1.9
const ORDER_SPAWN_MIN := 7.5
const ORDER_SPAWN_MAX := 11.0
const WALK_MIN_X := -6.65
const WALK_MAX_X := 6.65
const WALK_MIN_Z := -2.55
const WALK_MAX_Z := 0.28
const PREP_ROW_Z := -1.65

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var state: int = GameState.MENU
var rng := RandomNumberGenerator.new()

var world: Node3D
var ui_layer: CanvasLayer
var overlay_layer: CanvasLayer
var player: CharacterBody3D
var player_visual: Node3D
var hold_socket: Node3D
var held_visual: Node3D
var animation_player: AnimationPlayer
var current_animation := ""
var forced_animation := ""

var hud_time_label: Label
var hud_score_label: Label
var hud_held_label: Label
var hud_prompt_label: Label
var hud_guide_title_label: Label
var hud_guide_steps_label: Label
var hud_progress_bar: ProgressBar
var hud_message_panel: PanelContainer
var hud_message_label: Label
var orders_container: HBoxContainer

var music_player: AudioStreamPlayer
var success_player: AudioStreamPlayer
var error_player: AudioStreamPlayer
var action_player: AudioStreamPlayer
var pickup_player: AudioStreamPlayer
var chop_player: AudioStreamPlayer
var assemble_player: AudioStreamPlayer
var drop_player: AudioStreamPlayer

var stations: Array = []
var collision_blockers: Array[StaticBody3D] = []
var nearest_station: Dictionary = {}
var highlighted_station: Dictionary = {}
var held_item := ""
var assembly_ingredients: Array = []
var processing := false
var process_station_id := ""
var process_output_item := ""
var process_timer := 0.0
var process_duration := 1.0
var process_label := ""

var score := 0
var served_orders := 0
var missed_orders := 0
var shift_time := SHIFT_LENGTH
var order_spawn_timer := 1.0
var next_order_id := 1
var orders: Array = []
var model_load_count := 0
var model_fallback_count := 0
var model_fallback_paths: Array = []

var items := {}
var recipes := {}
var recipe_order: Array = []


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	rng.randomize()
	_setup_data()
	if _has_user_arg("--asset-load-audit"):
		_setup_audio()
		_run_asset_load_audit()
		return
	_setup_audio()
	show_main_menu()


func _has_user_arg(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)


func _run_asset_load_audit() -> void:
	start_game()
	var audio_ok := _audio_assets_loaded()
	var status := "PASS" if model_fallback_count == 0 and audio_ok else "FAIL"
	print("ASSET_LOAD_AUDIT status=%s loaded=%d fallbacks=%d audio=%s" % [status, model_load_count, model_fallback_count, str(audio_ok)])
	for path in model_fallback_paths:
		push_error("ASSET_LOAD_AUDIT missing_or_unloadable=%s" % path)
	if not audio_ok:
		push_error("ASSET_LOAD_AUDIT audio_not_loaded")
	get_tree().quit(0 if model_fallback_count == 0 and audio_ok else 1)


func _audio_assets_loaded() -> bool:
	return (
		music_player != null and music_player.stream != null
		and pickup_player != null and pickup_player.stream != null
		and chop_player != null and chop_player.stream != null
		and assemble_player != null and assemble_player.stream != null
		and success_player != null and success_player.stream != null
		and error_player != null and error_player.stream != null
		and drop_player != null and drop_player.stream != null
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if state == GameState.PLAYING:
			show_pause_menu()
			get_viewport().set_input_as_handled()
		elif state == GameState.PAUSED:
			resume_game()
			get_viewport().set_input_as_handled()

	if state != GameState.PLAYING:
		return

	if event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("drop_item"):
		drop_held_item()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if state != GameState.PLAYING:
		return

	_update_player(delta)
	_update_nearest_station()
	_update_processing(delta)
	_update_orders(delta)
	_update_hud()


func _setup_data() -> void:
	items = {
		"rice": {
			"display": "Rice",
			"type": "ingredient",
			"model": ASSET_ROOT + "/Food/glTF/FoodIngredient_Rice.gltf",
			"scale": 1.0,
		},
		"salmon": {
			"display": "Salmon",
			"type": "ingredient",
			"model": ASSET_ROOT + "/Food/glTF/FoodIngredient_Salmon.gltf",
			"scale": 1.0,
		},
		"nori": {
			"display": "Nori",
			"type": "ingredient",
			"model": ASSET_ROOT + "/Food/glTF/FoodIngredient_Nori.gltf",
			"scale": 1.0,
		},
		"cucumber": {
			"display": "Cucumber",
			"type": "ingredient",
			"model": ASSET_ROOT + "/Food/glTF/FoodIngredient_Cucumber.gltf",
			"scale": 1.0,
		},
		"sliced_cucumber": {
			"display": "Sliced Cucumber",
			"type": "prepared",
			"model": ASSET_ROOT + "/Food/glTF/FoodIngredient_SlicedCucumber.gltf",
			"scale": 1.0,
		},
		"onigiri": {
			"display": "Onigiri",
			"type": "dish",
			"model": ASSET_ROOT + "/Food/glTF/Food_Onigiri.gltf",
			"scale": 1.0,
		},
		"salmon_nigiri": {
			"display": "Salmon Nigiri",
			"type": "dish",
			"model": ASSET_ROOT + "/Food/glTF/Food_SalmonNigiri.gltf",
			"scale": 1.0,
		},
		"cucumber_roll": {
			"display": "Cucumber Roll",
			"type": "dish",
			"model": ASSET_ROOT + "/Food/glTF/Food_Roll.gltf",
			"scale": 1.0,
		},
	}

	recipes = {
		"onigiri": {
			"display": "Onigiri",
			"ingredients": ["rice"],
			"output": "onigiri",
			"score": 100,
			"patience": 30.0,
		},
		"salmon_nigiri": {
			"display": "Salmon Nigiri",
			"ingredients": ["rice", "salmon"],
			"output": "salmon_nigiri",
			"score": 150,
			"patience": 34.0,
		},
		"cucumber_roll": {
			"display": "Cucumber Roll",
			"ingredients": ["rice", "nori", "sliced_cucumber"],
			"output": "cucumber_roll",
			"score": 200,
			"patience": 42.0,
		},
	}
	recipe_order = ["onigiri", "salmon_nigiri", "cucumber_roll"]


func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.volume_db = -19.0
	music_player.stream = _load_audio_stream("res://assets/audio/sushi_shift_theme.mp3")
	if music_player.stream != null:
		if music_player.stream is AudioStreamMP3:
			(music_player.stream as AudioStreamMP3).loop = true
		add_child(music_player)
		music_player.play()

	success_player = AudioStreamPlayer.new()
	success_player.name = "SuccessTone"
	success_player.stream = _load_audio_stream("res://assets/audio/sfx_serve_success.mp3")
	if success_player.stream == null:
		success_player.stream = _make_tone(880.0, 0.09, 0.22)
	success_player.volume_db = -5.0
	add_child(success_player)

	error_player = AudioStreamPlayer.new()
	error_player.name = "ErrorTone"
	error_player.stream = _load_audio_stream("res://assets/audio/sfx_error.mp3")
	if error_player.stream == null:
		error_player.stream = _make_tone(180.0, 0.14, 0.2)
	error_player.volume_db = -6.0
	add_child(error_player)

	action_player = AudioStreamPlayer.new()
	action_player.name = "ActionTone"
	action_player.stream = _make_tone(520.0, 0.06, 0.16)
	action_player.volume_db = -8.0
	add_child(action_player)

	pickup_player = AudioStreamPlayer.new()
	pickup_player.name = "PickupSfx"
	pickup_player.stream = _load_audio_stream("res://assets/audio/sfx_pickup.mp3")
	if pickup_player.stream == null:
		pickup_player.stream = _make_tone(620.0, 0.05, 0.12)
	pickup_player.volume_db = -7.0
	add_child(pickup_player)

	chop_player = AudioStreamPlayer.new()
	chop_player.name = "ChopSfx"
	chop_player.stream = _load_audio_stream("res://assets/audio/sfx_chop.mp3")
	if chop_player.stream == null:
		chop_player.stream = _make_tone(320.0, 0.07, 0.14)
	chop_player.volume_db = -6.5
	add_child(chop_player)

	assemble_player = AudioStreamPlayer.new()
	assemble_player.name = "AssembleSfx"
	assemble_player.stream = _load_audio_stream("res://assets/audio/sfx_assemble.mp3")
	if assemble_player.stream == null:
		assemble_player.stream = _make_tone(740.0, 0.08, 0.12)
	assemble_player.volume_db = -7.0
	add_child(assemble_player)

	drop_player = AudioStreamPlayer.new()
	drop_player.name = "DropSfx"
	drop_player.stream = _load_audio_stream("res://assets/audio/sfx_drop.mp3")
	if drop_player.stream == null:
		drop_player.stream = _make_tone(260.0, 0.08, 0.12)
	drop_player.volume_db = -8.0
	add_child(drop_player)


func _load_audio_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream := ResourceLoader.load(path)
	if stream is AudioStream:
		return stream as AudioStream
	return null


func _make_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var samples := int(duration * mix_rate)
	var bytes := PackedByteArray()
	for i in range(samples):
		var envelope: float = 1.0 - (float(i) / max(1.0, float(samples)))
		var sample: float = sin(TAU * frequency * float(i) / float(mix_rate)) * volume * envelope
		var value := int(clamp(sample, -1.0, 1.0) * 32767.0)
		if value < 0:
			value += 65536
		bytes.append(value & 0xff)
		bytes.append((value >> 8) & 0xff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	return stream


func show_main_menu() -> void:
	state = GameState.MENU
	_clear_play_nodes()

	var layer := CanvasLayer.new()
	layer.name = "MainMenu"
	add_child(layer)
	overlay_layer = layer

	var preview := TextureRect.new()
	preview.texture = ResourceLoader.load(ASSET_ROOT + "/Preview.jpg") as Texture2D
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(preview)

	var wash := ColorRect.new()
	wash.color = Color(0.13, 0.055, 0.035, 0.64)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(wash)

	var top_sash := ColorRect.new()
	top_sash.color = Color(0.56, 0.06, 0.035, 0.72)
	top_sash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_sash.offset_bottom = 76
	layer.add_child(top_sash)

	var bottom_sash := ColorRect.new()
	bottom_sash.color = Color(0.11, 0.055, 0.035, 0.78)
	bottom_sash.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_sash.offset_top = -92
	layer.add_child(bottom_sash)

	var panel := PanelContainer.new()
	panel.name = "MainMenuPanel"
	panel.custom_minimum_size = Vector2(900, 540)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-450, -270)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.13, 0.065, 0.04, 0.92), Color(1.0, 0.67, 0.25, 0.96), 8, 2, 30))
	layer.add_child(panel)

	var layout := HBoxContainer.new()
	layout.name = "MainMenuLayout"
	layout.add_theme_constant_override("separation", 30)
	panel.add_child(layout)

	var left := VBoxContainer.new()
	left.name = "MainMenuIntro"
	left.custom_minimum_size = Vector2(520, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	layout.add_child(left)

	var badge := _make_ui_label("TODAY'S COUNTER RUSH", 14, Color(1.0, 0.67, 0.26), HORIZONTAL_ALIGNMENT_LEFT)
	badge.add_theme_constant_override("outline_size", 1)
	badge.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 0.85))
	left.add_child(badge)

	var title := Label.new()
	title.name = "MainMenuTitle"
	title.text = "Sushi Shift"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.89, 0.65))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	left.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "MainMenuSubtitle"
	subtitle.text = "Plate fast. Serve warm. Keep the counter moving."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.98, 0.78, 0.48))
	left.add_child(subtitle)

	var badge_row := HBoxContainer.new()
	badge_row.name = "MainMenuBadgeRow"
	badge_row.add_theme_constant_override("separation", 8)
	left.add_child(badge_row)
	_add_menu_badge(badge_row, "3 minute shift")
	_add_menu_badge(badge_row, "3 recipes")
	_add_menu_badge(badge_row, "4 active orders")

	_add_divider(left, Color(1.0, 0.67, 0.25, 0.44), 2)

	var controls_title := _make_ui_label("Controls", 18, Color(1.0, 0.88, 0.64), HORIZONTAL_ALIGNMENT_LEFT)
	left.add_child(controls_title)

	var controls := HBoxContainer.new()
	controls.name = "MainMenuControls"
	controls.add_theme_constant_override("separation", 8)
	left.add_child(controls)
	_add_key_hint(controls, "WASD", "Move")
	_add_key_hint(controls, "E", "Interact")
	_add_key_hint(controls, "Q", "Drop")
	_add_key_hint(controls, "Esc", "Pause")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	var start_button := Button.new()
	start_button.name = "MainMenuStartButton"
	start_button.text = "Start Shift"
	start_button.custom_minimum_size = Vector2(320, 60)
	_style_button(start_button, true)
	start_button.pressed.connect(start_game)
	left.add_child(start_button)

	var quit_button := Button.new()
	quit_button.name = "MainMenuQuitButton"
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(320, 48)
	_style_button(quit_button)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	left.add_child(quit_button)

	var hint := Label.new()
	hint.name = "MainMenuHint"
	hint.text = "Serve the first ticket fast, then keep the next orders from timing out."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.86, 0.68, 0.45))
	left.add_child(hint)

	var right := VBoxContainer.new()
	right.name = "MainMenuRecipeList"
	right.custom_minimum_size = Vector2(290, 0)
	right.add_theme_constant_override("separation", 10)
	layout.add_child(right)

	var ticket_title := _make_ui_label("Today's Menu", 24, Color(1.0, 0.89, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
	right.add_child(ticket_title)
	var ticket_subtitle := _make_ui_label("Learn these three. Everything in the MVP comes from them.", 14, Color(0.92, 0.70, 0.46), HORIZONTAL_ALIGNMENT_LEFT)
	right.add_child(ticket_subtitle)
	_add_recipe_ticket(right, "onigiri")
	_add_recipe_ticket(right, "salmon_nigiri")
	_add_recipe_ticket(right, "cucumber_roll")


func start_game() -> void:
	_clear_play_nodes()
	state = GameState.PLAYING
	score = 0
	served_orders = 0
	missed_orders = 0
	shift_time = SHIFT_LENGTH
	order_spawn_timer = 0.5
	next_order_id = 1
	orders.clear()
	model_load_count = 0
	model_fallback_count = 0
	model_fallback_paths.clear()
	held_item = ""
	assembly_ingredients.clear()
	processing = false
	forced_animation = ""
	current_animation = ""
	nearest_station = {}
	highlighted_station = {}

	_build_world()
	_build_hud()
	_spawn_order()
	_update_hud()


func _clear_play_nodes() -> void:
	for child in get_children():
		if _is_persistent_audio_node(child):
			continue
		remove_child(child)
		child.free()
	world = null
	ui_layer = null
	overlay_layer = null
	player = null
	player_visual = null
	hold_socket = null
	held_visual = null
	animation_player = null
	hud_message_panel = null
	hud_message_label = null
	stations.clear()
	collision_blockers.clear()


func _is_persistent_audio_node(child: Node) -> bool:
	return child == music_player or child == success_player or child == error_player or child == action_player or child == pickup_player or child == chop_player or child == assemble_player or child == drop_player


func _build_world() -> void:
	world = Node3D.new()
	world.name = "GameWorld"
	add_child(world)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.26, 0.17, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.98, 0.70, 0.48)
	env.ambient_light_energy = 0.16
	environment.environment = env
	world.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.name = "WarmKeyLight"
	sun.light_color = Color(1.0, 0.76, 0.48)
	sun.light_energy = 0.55
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-38, -24, 0)
	world.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "CounterFillLight"
	fill.position = Vector3(0, 3.4, 0.4)
	fill.light_color = Color(1.0, 0.48, 0.26)
	fill.light_energy = 0.18
	fill.omni_range = 9.0
	world.add_child(fill)

	for x in [-5.9, 5.9]:
		var lantern_light := OmniLight3D.new()
		lantern_light.name = "LanternGlow"
		lantern_light.position = Vector3(x, 2.35, -3.7)
		lantern_light.light_color = Color(1.0, 0.54, 0.24)
		lantern_light.light_energy = 0.48
		lantern_light.omni_range = 3.4
		world.add_child(lantern_light)

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 6.9, 11.3)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 36.0
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.88, -1.05), Vector3.UP)

	_build_level_geometry()
	_build_player()
	_build_stations()
	_build_global_collision_blockers()


func _build_level_geometry() -> void:
	_add_box("Foundation", Vector3(0, -0.08, 0.02), Vector3(15.2, 0.12, 8.6), Color(0.28, 0.16, 0.09))
	_add_model("KitchenFloor", ASSET_ROOT + "/Environment/glTF/Floor_Kitchen1.gltf", Vector3(0, 0.0, -1.25), Vector3(5.65, 1.0, 2.72), 0.0)
	_add_model("DiningFloor", ASSET_ROOT + "/Environment/glTF/Floor_Wood.gltf", Vector3(0, 0.0, 2.35), Vector3(5.65, 1.0, 1.62), 0.0)

	_add_box("BackWallWarmth", Vector3(0, 1.32, -4.18), Vector3(14.8, 2.64, 0.18), Color(0.48, 0.26, 0.14))
	_add_box("LeftWallWarmth", Vector3(-7.18, 1.20, -0.45), Vector3(0.18, 2.40, 7.5), Color(0.38, 0.20, 0.12))
	_add_box("RightWallWarmth", Vector3(7.18, 1.20, -0.45), Vector3(0.18, 2.40, 7.5), Color(0.38, 0.20, 0.12))
	_add_box("BackShadowStrip", Vector3(0, 2.72, -4.0), Vector3(14.5, 0.22, 0.28), Color(0.20, 0.10, 0.055))

	for x in [-6.0, -3.6, -1.2, 1.2, 3.6, 6.0]:
		_add_model("ShojiBackWall", ASSET_ROOT + "/Environment/glTF/Wall_Shoji_Interior.gltf", Vector3(x, 0, -4.08), Vector3(0.88, 0.88, 0.88), 0.0)

	for x in [-4.7, -2.5, 2.5, 4.7]:
		_add_model("BackCabinet", ASSET_ROOT + "/Environment/glTF/Environment_Cabinet_Shelves.gltf", Vector3(x, 0, -3.42), Vector3(0.54, 0.54, 0.54), 0.0)

	for x in [-5.25, -3.15, -1.05, 1.05, 3.15, 5.25]:
		_add_model("ServingBar", ASSET_ROOT + "/Environment/glTF/Environment_Counter_Straight.gltf", Vector3(x, 0, 0.92), Vector3(0.88, 0.55, 0.64), 0.0)

	for x in [-4.15, -2.05, 0.0, 2.05, 4.15]:
		_add_model("GuestStool", ASSET_ROOT + "/Environment/glTF/Environment_Stool.gltf", Vector3(x, 0, 2.62), Vector3(0.52, 0.52, 0.52), 0.0)

	for x in [-4.15, 0.0, 4.15]:
		_add_model("GuestCarpet", ASSET_ROOT + "/Decoration/glTF/Decoration_Carpet.gltf", Vector3(x, 0.015, 2.42), Vector3(0.72, 0.72, 0.72), 0.0)

	_add_character("GuestRabbitPink", ASSET_ROOT + "/Characters/Normal/glTF/Rabbit_Pink.gltf", Vector3(-4.15, 0.40, 2.68), Vector3(0.50, 0.50, 0.50), PI, "Sitting_Idle")
	_add_character("GuestRabbitBlond", ASSET_ROOT + "/Characters/Normal/glTF/Rabbit_Blond.gltf", Vector3(0.0, 0.40, 2.68), Vector3(0.50, 0.50, 0.50), PI, "Sitting_Eating")
	_add_character("GuestRabbitGrey", ASSET_ROOT + "/Characters/Normal/glTF/Rabbit_Grey.gltf", Vector3(4.15, 0.40, 2.68), Vector3(0.50, 0.50, 0.50), PI, "Sitting_Idle")

	_add_model("LanternLeft", ASSET_ROOT + "/Decoration/glTF/Decoration_Light.gltf", Vector3(-6.25, 2.42, -3.82), Vector3(0.76, 0.76, 0.76), 0.0)
	_add_model("LanternRight", ASSET_ROOT + "/Decoration/glTF/Decoration_Light.gltf", Vector3(6.25, 2.42, -3.82), Vector3(0.76, 0.76, 0.76), 0.0)
	_add_model("WallFish", ASSET_ROOT + "/Decoration/glTF/Decoration_Fish.gltf", Vector3(0.05, 1.85, -3.78), Vector3(0.78, 0.78, 0.78), 0.0)
	_add_model("PaintedMenu", ASSET_ROOT + "/Decoration/glTF/Decoration_Painting.gltf", Vector3(-3.0, 1.72, -3.78), Vector3(0.76, 0.76, 0.76), 0.0)
	_add_model("SushiSign", ASSET_ROOT + "/Decoration/glTF/Decoration_Sign_2.gltf", Vector3(3.15, 1.78, -3.78), Vector3(0.78, 0.78, 0.78), 0.0)
	_add_model("BambooPlanter", ASSET_ROOT + "/Decoration/glTF/Decoration_Bamboo.gltf", Vector3(6.45, 0, -0.45), Vector3(0.70, 0.70, 0.70), 0.0)
	_add_model("PlantLeft", ASSET_ROOT + "/Decoration/glTF/Decoration_Plant1.gltf", Vector3(-6.45, 0, -0.45), Vector3(0.70, 0.70, 0.70), 0.0)
	_add_model("SakuraAccent", ASSET_ROOT + "/Decoration/glTF/Decoration_SakuraFlower.gltf", Vector3(5.55, 0.72, 1.25), Vector3(0.62, 0.62, 0.62), 0.0)

	_add_counter_display("DisplayOnigiri", ASSET_ROOT + "/Food/glTF/Food_Onigiri.gltf", Vector3(-4.05, 1.02, 0.48), Vector3(0.72, 0.72, 0.72))
	_add_counter_display("DisplayNigiri", ASSET_ROOT + "/Food/glTF/Food_SalmonNigiri.gltf", Vector3(-2.75, 1.02, 0.48), Vector3(0.72, 0.72, 0.72))
	_add_counter_display("DisplayRoll", ASSET_ROOT + "/Food/glTF/Food_Roll.gltf", Vector3(-1.45, 1.02, 0.48), Vector3(0.72, 0.72, 0.72))
	_add_counter_display("DisplayDango", ASSET_ROOT + "/Food/glTF/Food_Dango.gltf", Vector3(1.20, 1.02, 0.48), Vector3(0.64, 0.64, 0.64))
	_add_counter_display("DisplayRamen", ASSET_ROOT + "/Food/glTF/Food_Ramen.gltf", Vector3(2.50, 1.02, 0.48), Vector3(0.64, 0.64, 0.64))
	_add_counter_display("DisplayTamago", ASSET_ROOT + "/Food/glTF/Food_TamagoNigiri.gltf", Vector3(3.80, 1.02, 0.48), Vector3(0.74, 0.74, 0.74))


func _build_global_collision_blockers() -> void:
	_add_world_blocker("BackWallBlocker", Vector3(0.0, 0.75, -3.72), Vector3(14.0, 1.5, 0.55))
	_add_world_blocker("LeftWallBlocker", Vector3(-7.25, 0.75, -0.85), Vector3(0.55, 1.5, 6.2))
	_add_world_blocker("RightWallBlocker", Vector3(7.25, 0.75, -0.85), Vector3(0.55, 1.5, 6.2))
	_add_world_blocker("ServingBarBlocker", Vector3(0.0, 0.72, 0.98), Vector3(13.7, 1.35, 0.58))
	_add_world_blocker("DiningAreaBlocker", Vector3(0.0, 0.72, 2.45), Vector3(13.6, 1.35, 1.7))
	_add_world_blocker("FridgeBlocker", Vector3(-6.55, 0.70, -3.58), Vector3(1.12, 1.40, 0.90))
	_add_world_blocker("CanFridgeBlocker", Vector3(4.20, 0.66, -3.32), Vector3(0.98, 1.32, 0.72))
	_add_world_blocker("OvenBlocker", Vector3(5.95, 0.72, -3.43), Vector3(1.20, 1.44, 0.98))
	_add_world_blocker("LeftPlantBlocker", Vector3(-6.45, 0.45, -0.45), Vector3(0.68, 0.90, 0.68))
	_add_world_blocker("BambooBlocker", Vector3(6.45, 0.50, -0.45), Vector3(0.68, 1.00, 0.68))


func _add_counter_display(name: String, food_path: String, position: Vector3, scale: Vector3) -> void:
	var plate := _add_model(name + "Plate", ASSET_ROOT + "/Environment/glTF/Environment_Plate.gltf", position + Vector3(0, -0.05, 0), Vector3(0.88, 0.88, 0.88), 0.0)
	var food := _add_model_to(plate, food_path, Vector3(0, 0.27, 0), scale, 0.0)
	food.name = name + "Food"


func _add_character(name: String, path: String, position: Vector3, scale: Vector3, rotation_y: float, animation_name: String) -> Node3D:
	var character := _add_model(name, path, position, scale, rotation_y)
	var anim_players := character.find_children("*", "AnimationPlayer", true, false)
	if anim_players.size() > 0:
		var anim := anim_players[0] as AnimationPlayer
		if anim.has_animation(animation_name):
			var animation := anim.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			anim.play(animation_name)
	return character


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(-4.35, 0.75, -0.60)
	world.add_child(player)

	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.35
	var collision := CollisionShape3D.new()
	collision.shape = shape
	player.add_child(collision)

	player_visual = Node3D.new()
	player_visual.name = "PlayerVisual"
	player.add_child(player_visual)
	_add_model_to(player_visual, ASSET_ROOT + "/Characters/With Knife and Pan/glTF/Panda.gltf", Vector3(0, -0.75, 0), Vector3(0.85, 0.85, 0.85), 0.0)

	var anim_players := player_visual.find_children("*", "AnimationPlayer", true, false)
	if anim_players.size() > 0:
		animation_player = anim_players[0] as AnimationPlayer
		_configure_player_animation_loops()

	hold_socket = Node3D.new()
	hold_socket.name = "HoldSocket"
	hold_socket.position = Vector3(0, 0.48, 0.70)
	hold_socket.rotation_degrees = Vector3(-10, 0, 0)
	player_visual.add_child(hold_socket)


func _configure_player_animation_loops() -> void:
	if animation_player == null:
		return
	for animation_name in ["Idle", "Idle_Holding", "Walk", "Walk_Holding", "Chop_Loop", "Assembly_Loop"]:
		if animation_player.has_animation(animation_name):
			var animation := animation_player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR


func _build_stations() -> void:
	_add_station("rice_bin", "ingredient", "Rice", Vector3(-4.95, 0.15, PREP_ROW_Z), "rice", ASSET_ROOT + "/Environment/glTF/Environment_Counter_Drawers.gltf", ASSET_ROOT + "/Environment/glTF/Environment_Bowl.gltf")
	_add_station("salmon_bin", "ingredient", "Salmon", Vector3(-3.15, 0.15, PREP_ROW_Z), "salmon", ASSET_ROOT + "/Environment/glTF/Environment_Counter_Straight_2.gltf", ASSET_ROOT + "/Environment/glTF/Environment_Plate.gltf")
	_add_station("nori_bin", "ingredient", "Nori", Vector3(-1.35, 0.15, PREP_ROW_Z), "nori", ASSET_ROOT + "/Environment/glTF/Environment_Counter_Straight_2.gltf", ASSET_ROOT + "/Environment/glTF/Environment_Plate.gltf")
	_add_station("cucumber_bin", "ingredient", "Cucumber", Vector3(0.45, 0.15, PREP_ROW_Z), "cucumber", ASSET_ROOT + "/Environment/glTF/Environment_Counter_Straight_2.gltf", ASSET_ROOT + "/Environment/glTF/Environment_Bowl.gltf")

	_add_station("cutting", "cutting", "Cut", Vector3(2.25, 0.15, PREP_ROW_Z), "", ASSET_ROOT + "/Environment/glTF/Environment_CuttingTable.gltf", ASSET_ROOT + "/Environment/glTF/Environment_KitchenKnives.gltf")
	_add_station("assembly", "assembly", "Assemble", Vector3(4.05, 0.15, PREP_ROW_Z), "", ASSET_ROOT + "/Environment/glTF/Environment_Counter_Drawers.gltf", ASSET_ROOT + "/Environment/glTF/Environment_Plate.gltf")
	var serving_station := _add_station("serving", "serving", "Serve", Vector3(3.75, 0.15, 0.72), "", ASSET_ROOT + "/Environment/glTF/Environment_Counter_Straight.gltf", ASSET_ROOT + "/Environment/glTF/Environment_Plate.gltf")
	serving_station.scale = Vector3(0.84, 1.0, 0.84)
	var serving_roll := _add_model_to(serving_station, ASSET_ROOT + "/Food/glTF/Food_Roll.gltf", Vector3(-0.16, 1.22, -0.22), Vector3(0.52, 0.52, 0.52), 0.0)
	serving_roll.name = "serving_ready_roll"
	var serving_nigiri := _add_model_to(serving_station, ASSET_ROOT + "/Food/glTF/Food_SalmonNigiri.gltf", Vector3(0.18, 1.22, -0.22), Vector3(0.50, 0.50, 0.50), 0.0)
	serving_nigiri.name = "serving_ready_nigiri"

	_add_model("Fridge", ASSET_ROOT + "/Environment/glTF/Environment_Fridge.gltf", Vector3(-6.55, 0, -3.58), Vector3(0.60, 0.60, 0.60), deg_to_rad(-8))
	_add_model("CanFridge", ASSET_ROOT + "/Environment/glTF/Environment_CanFridge.gltf", Vector3(4.20, 0, -3.32), Vector3(0.55, 0.55, 0.55), 0.0)
	_add_model("Oven", ASSET_ROOT + "/Environment/glTF/Environment_Oven.gltf", Vector3(5.95, 0, -3.43), Vector3(0.72, 0.72, 0.72), 0.0)
	_add_model("Pots", ASSET_ROOT + "/Environment/glTF/Environment_Pot_1_Filled.gltf", Vector3(5.65, 0.82, -1.48), Vector3(0.56, 0.56, 0.56), 0.0)
	_add_model("Bottles", ASSET_ROOT + "/Environment/glTF/Environment_Bottles.gltf", Vector3(-0.2, 1.02, -2.70), Vector3(0.58, 0.58, 0.58), 0.0)


func _add_station(id: String, station_type: String, display_name: String, position: Vector3, item_id: String, station_model_path: String, prop_model_path := "") -> Node3D:
	var node := Node3D.new()
	node.name = id
	node.position = position
	world.add_child(node)

	var counter_model := _add_model_to(node, station_model_path, Vector3.ZERO, Vector3(0.86, 0.78, 0.86), 0.0)
	counter_model.name = id + "_counter_model"
	_add_blocker_to(node, id + "_blocker", Vector3(0.0, 0.64, -0.02), Vector3(1.36, 1.28, 1.02))
	_add_station_label(node, display_name, station_type)

	if prop_model_path != "":
		var prop_model := _add_model_to(node, prop_model_path, Vector3(0, 0.98, -0.22), Vector3(0.92, 0.92, 0.92), 0.0)
		prop_model.name = id + "_prop_model"

	if item_id != "":
		var item_model := _add_model_to(node, items[item_id]["model"], Vector3(0, 1.42, -0.22), Vector3(1.42, 1.42, 1.42), 0.0)
		item_model.name = id + "_item_model"

	var ring := MeshInstance3D.new()
	ring.name = "HighlightRing"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.62
	ring_mesh.bottom_radius = 0.62
	ring_mesh.height = 0.025
	ring_mesh.radial_segments = 40
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.05, 0)
	ring.material_override = _make_material(Color(1.0, 0.78, 0.25, 0.36), true)
	ring.visible = false
	node.add_child(ring)

	stations.append({
		"id": id,
		"type": station_type,
		"display": display_name,
		"item": item_id,
		"node": node,
		"ring": ring,
	})

	return node


func _add_station_label(parent: Node3D, display_name: String, station_type: String) -> void:
	var label := Label3D.new()
	label.name = "StationLabel"
	label.text = display_name
	if station_type == "assembly":
		label.text = "Assemble"
	elif station_type == "serving":
		label.text = "Serve Here"
	label.position = Vector3(0.0, 2.25, -0.18)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = 46
	label.outline_size = 8
	label.modulate = Color(1.0, 0.88, 0.54)
	label.outline_modulate = Color(0.13, 0.045, 0.025, 0.92)
	parent.add_child(label)


func _add_world_blocker(name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	return _add_blocker_to(world, name, position, size)


func _add_blocker_to(parent: Node3D, name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("player_blocker")
	body.set_meta("blocker_size", size)
	parent.add_child(body)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	collision_blockers.append(body)
	return body


func _build_hud() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "HUD"
	add_child(ui_layer)

	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)

	var status_panel := PanelContainer.new()
	status_panel.name = "StatusPanel"
	status_panel.position = Vector2(18, 14)
	status_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.045, 0.035, 0.84), Color(1.0, 0.58, 0.22, 0.78), 8, 1, 12))
	root.add_child(status_panel)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	status_panel.add_child(top_bar)

	hud_time_label = _make_hud_label("Time 3:00")
	top_bar.add_child(hud_time_label)

	hud_score_label = _make_hud_label("Score 0")
	top_bar.add_child(hud_score_label)

	hud_held_label = _make_hud_label("Holding: Empty")
	top_bar.add_child(hud_held_label)

	var orders_panel := PanelContainer.new()
	orders_panel.name = "OrdersPanel"
	orders_panel.position = Vector2(360, 14)
	orders_panel.custom_minimum_size = Vector2(790, 78)
	orders_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.045, 0.035, 0.70), Color(1.0, 0.58, 0.22, 0.62), 8, 1, 8))
	root.add_child(orders_panel)

	orders_container = HBoxContainer.new()
	orders_container.name = "OrdersStrip"
	orders_container.custom_minimum_size = Vector2(774, 62)
	orders_container.add_theme_constant_override("separation", 8)
	orders_container.alignment = BoxContainer.ALIGNMENT_CENTER
	orders_panel.add_child(orders_container)

	var guide_panel := PanelContainer.new()
	guide_panel.name = "GuidePanel"
	guide_panel.position = Vector2(360, 100)
	guide_panel.custom_minimum_size = Vector2(520, 86)
	guide_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.13, 0.06, 0.035, 0.76), Color(1.0, 0.58, 0.22, 0.58), 8, 1, 8))
	root.add_child(guide_panel)

	var guide_box := VBoxContainer.new()
	guide_box.add_theme_constant_override("separation", 3)
	guide_panel.add_child(guide_box)

	hud_guide_title_label = _make_ui_label("Chef Brief", 16, Color(1.0, 0.88, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
	hud_guide_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	guide_box.add_child(hud_guide_title_label)

	hud_guide_steps_label = _make_ui_label("Read the ticket, gather ingredients, assemble, then serve at the red counter.", 14, Color(0.96, 0.73, 0.46), HORIZONTAL_ALIGNMENT_LEFT)
	hud_guide_steps_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_box.add_child(hud_guide_steps_label)

	var prompt_panel := PanelContainer.new()
	prompt_panel.name = "PromptPanel"
	prompt_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.045, 0.035, 0.86), Color(1.0, 0.58, 0.22, 0.78), 8, 1, 12))
	prompt_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_panel.offset_left = 430
	prompt_panel.offset_right = -430
	prompt_panel.offset_top = -80
	prompt_panel.offset_bottom = -42
	root.add_child(prompt_panel)

	hud_prompt_label = _make_hud_label("")
	hud_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(hud_prompt_label)

	hud_progress_bar = ProgressBar.new()
	hud_progress_bar.visible = false
	hud_progress_bar.min_value = 0
	hud_progress_bar.max_value = 1
	hud_progress_bar.value = 0
	hud_progress_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hud_progress_bar.offset_left = 470
	hud_progress_bar.offset_right = -470
	hud_progress_bar.offset_top = -38
	hud_progress_bar.offset_bottom = -24
	hud_progress_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.12, 0.07, 0.04, 0.78), 6))
	hud_progress_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.98, 0.55, 0.22, 0.96), 6))
	root.add_child(hud_progress_bar)

	var message_panel := PanelContainer.new()
	message_panel.name = "MessagePanel"
	message_panel.visible = false
	message_panel.modulate = Color(1, 1, 1, 0)
	message_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(1.0, 0.84, 0.54, 0.92), Color(0.58, 0.10, 0.055, 0.62), 8, 1, 10))
	message_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_panel.offset_left = -260
	message_panel.offset_right = 260
	message_panel.offset_top = 70
	message_panel.offset_bottom = 116
	root.add_child(message_panel)
	hud_message_panel = message_panel

	hud_message_label = _make_hud_label("")
	hud_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_panel.add_child(hud_message_label)


func _make_hud_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.89, 0.66))
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _make_ui_label(text: String, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _add_divider(parent: Control, color: Color, height: int) -> void:
	var divider := ColorRect.new()
	divider.color = color
	divider.custom_minimum_size = Vector2(0, height)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(divider)


func _add_menu_badge(parent: Control, text: String) -> void:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(132, 34)
	badge.add_theme_stylebox_override("panel", _make_panel_style(Color(0.56, 0.08, 0.04, 0.72), Color(1.0, 0.67, 0.25, 0.62), 8, 1, 10))
	parent.add_child(badge)

	var label := _make_ui_label(text, 14, Color(1.0, 0.88, 0.62), HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.add_child(label)


func _add_key_hint(parent: Control, key_text: String, action_text: String) -> void:
	var hint := PanelContainer.new()
	hint.custom_minimum_size = Vector2(108, 46)
	hint.add_theme_stylebox_override("panel", _make_panel_style(Color(0.19, 0.08, 0.045, 0.82), Color(1.0, 0.58, 0.22, 0.46), 8, 1, 7))
	parent.add_child(hint)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	hint.add_child(box)

	var key := _make_ui_label(key_text, 16, Color(1.0, 0.90, 0.66), HORIZONTAL_ALIGNMENT_CENTER)
	key.autowrap_mode = TextServer.AUTOWRAP_OFF
	key.add_theme_constant_override("outline_size", 1)
	key.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 0.85))
	box.add_child(key)

	var action := _make_ui_label(action_text, 12, Color(0.96, 0.70, 0.43), HORIZONTAL_ALIGNMENT_CENTER)
	action.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(action)


func _add_recipe_ticket(parent: Control, recipe_id: String) -> void:
	if not recipes.has(recipe_id):
		return
	var recipe = recipes[recipe_id]
	var ticket := PanelContainer.new()
	ticket.custom_minimum_size = Vector2(0, 72)
	ticket.add_theme_stylebox_override("panel", _make_panel_style(Color(1.0, 0.84, 0.55, 0.92), Color(0.60, 0.11, 0.06, 0.70), 8, 1, 10))
	parent.add_child(ticket)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	ticket.add_child(box)

	var name := _make_ui_label(String(recipe["display"]), 17, Color(0.22, 0.07, 0.035), HORIZONTAL_ALIGNMENT_LEFT)
	name.add_theme_color_override("font_shadow_color", Color(1.0, 0.90, 0.70, 0.50))
	box.add_child(name)

	var ingredients := _make_ui_label(_ingredient_summary(recipe["ingredients"]), 13, Color(0.44, 0.18, 0.08), HORIZONTAL_ALIGNMENT_LEFT)
	ingredients.add_theme_color_override("font_shadow_color", Color(1.0, 0.90, 0.70, 0.36))
	box.add_child(ingredients)

	var reward := _make_ui_label(str(recipe["score"]) + " pts", 12, Color(0.58, 0.10, 0.055), HORIZONTAL_ALIGNMENT_LEFT)
	reward.add_theme_color_override("font_shadow_color", Color(1.0, 0.90, 0.70, 0.30))
	box.add_child(reward)


func _make_panel_style(bg: Color, border: Color, radius: int, border_width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


func _make_bar_style(bg: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _style_button(button: Button, primary := false) -> void:
	button.add_theme_font_size_override("font_size", 20 if primary else 18)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62) if primary else Color(1.0, 0.82, 0.52))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.72))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.45))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.72))
	if primary:
		button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.66, 0.08, 0.045, 0.98), Color(1.0, 0.67, 0.25, 0.95), 8, 2, 10))
		button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.78, 0.11, 0.055, 1.0), Color(1.0, 0.78, 0.35, 1.0), 8, 2, 10))
		button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.44, 0.055, 0.035, 1.0), Color(1.0, 0.52, 0.20, 1.0), 8, 2, 10))
		button.add_theme_stylebox_override("focus", _make_panel_style(Color(0.78, 0.11, 0.055, 1.0), Color(1.0, 0.88, 0.46, 1.0), 8, 2, 10))
	else:
		button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.18, 0.08, 0.045, 0.96), Color(0.96, 0.55, 0.22, 0.76), 8, 1, 8))
		button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.28, 0.10, 0.055, 0.98), Color(1.0, 0.67, 0.25, 0.92), 8, 1, 8))
		button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.12, 0.055, 0.035, 1.0), Color(0.88, 0.38, 0.16, 0.9), 8, 1, 8))
		button.add_theme_stylebox_override("focus", _make_panel_style(Color(0.28, 0.10, 0.055, 0.98), Color(1.0, 0.86, 0.43, 0.96), 8, 1, 8))


func _update_player(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input.x, 0, input.y)
	if direction.length() > 1.0:
		direction = direction.normalized()

	player.velocity = direction * PLAYER_SPEED
	player.move_and_slide()
	player.position.x = clamp(player.position.x, WALK_MIN_X, WALK_MAX_X)
	player.position.z = clamp(player.position.z, WALK_MIN_Z, WALK_MAX_Z)

	if direction.length() > 0.05:
		player_visual.rotation.y = atan2(direction.x, direction.z)
		if held_item == "":
			_play_character_animation("Walk")
		else:
			_play_character_animation("Walk_Holding")
	else:
		if forced_animation != "":
			_play_character_animation(forced_animation)
		elif held_item == "":
			_play_character_animation("Idle")
		else:
			_play_character_animation("Idle_Holding")


func _play_character_animation(animation_name: String) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		return
	if current_animation == animation_name and animation_player.is_playing():
		return
	current_animation = animation_name
	animation_player.play(animation_name)


func _update_nearest_station() -> void:
	var closest: Dictionary = {}
	var closest_distance := INF
	for station in stations:
		var station_node := station["node"] as Node3D
		var distance := player.global_position.distance_to(station_node.global_position)
		if distance < closest_distance:
			closest = station
			closest_distance = distance

	nearest_station = {}
	if closest_distance <= INTERACT_DISTANCE:
		nearest_station = closest

	if highlighted_station != nearest_station:
		if highlighted_station.has("ring"):
			highlighted_station["ring"].visible = false
		if nearest_station.has("ring"):
			nearest_station["ring"].visible = true
		highlighted_station = nearest_station


func interact() -> void:
	if processing:
		_show_message("Busy...", Color(0.16, 0.1, 0.08))
		return
	if nearest_station.is_empty():
		_show_message("Move closer to a station", Color(0.16, 0.1, 0.08))
		error_player.play()
		return

	match nearest_station["type"]:
		"ingredient":
			_use_ingredient_station(nearest_station)
		"cutting":
			_use_cutting_station()
		"assembly":
			_use_assembly_station()
		"serving":
			_use_serving_station()


func _use_ingredient_station(station: Dictionary) -> void:
	if held_item != "":
		_show_message("Hands full", Color(0.16, 0.1, 0.08))
		error_player.play()
		return
	set_held_item(station["item"])
	_show_message("Picked up " + items[held_item]["display"], Color(0.05, 0.26, 0.12))
	pickup_player.play()


func _use_cutting_station() -> void:
	if held_item != "cucumber":
		_show_message("Cutting board needs cucumber", Color(0.38, 0.08, 0.05))
		error_player.play()
		return
	set_held_item("")
	_start_processing("cutting", "sliced_cucumber", 1.25, "Chopping cucumber", "Chop_Loop")


func _use_assembly_station() -> void:
	if held_item == "":
		if assembly_ingredients.is_empty():
			_show_message("Bring ingredients here", Color(0.16, 0.1, 0.08))
			return
		var current_match := _find_matching_recipe(assembly_ingredients)
		if current_match != "":
			var recipe = recipes[current_match]
			assembly_ingredients.clear()
			_start_processing("assembly", recipe["output"], 1.5, "Assembling " + recipe["display"], "Assembly_Loop")
			return
		else:
			_show_message("Assembly: " + _ingredient_summary(assembly_ingredients), Color(0.16, 0.1, 0.08))
			return

	if not items.has(held_item):
		return
	if items[held_item]["type"] == "dish":
		_show_message("Serve dishes at the counter", Color(0.16, 0.1, 0.08))
		error_player.play()
		return

	var deposited := held_item
	assembly_ingredients.append(deposited)
	set_held_item("")
	action_player.play()

	if not _is_valid_recipe_prefix(assembly_ingredients):
		assembly_ingredients.clear()
		_show_message("Those ingredients do not make a dish", Color(0.38, 0.08, 0.05))
		error_player.play()
	else:
		var message: String = "Added " + String(items[deposited]["display"])
		if _find_matching_recipe(assembly_ingredients) != "":
			message += " - press E to assemble"
		_show_message(message, Color(0.05, 0.18, 0.28))


func _use_serving_station() -> void:
	if held_item == "":
		_show_message("Bring a finished dish", Color(0.16, 0.1, 0.08))
		return
	if items[held_item]["type"] != "dish":
		_show_message("That is not ready to serve", Color(0.38, 0.08, 0.05))
		error_player.play()
		return

	var match_index := -1
	for i in range(orders.size()):
		var recipe = recipes[orders[i]["recipe"]]
		if recipe["output"] == held_item:
			match_index = i
			break

	if match_index == -1:
		_show_message("No one ordered " + items[held_item]["display"], Color(0.38, 0.08, 0.05))
		error_player.play()
		return

	var order = orders[match_index]
	var recipe = recipes[order["recipe"]]
	var patience_bonus := int(max(0.0, order["time_left"]) * 2.0)
	var gained := int(recipe["score"]) + patience_bonus
	score += gained
	served_orders += 1
	orders.remove_at(match_index)
	set_held_item("")
	_show_message("Served " + recipe["display"] + "  +" + str(gained), Color(0.05, 0.28, 0.12))
	success_player.play()


func _start_processing(station_id: String, output_item: String, duration: float, label: String, animation_name: String) -> void:
	processing = true
	process_station_id = station_id
	process_output_item = output_item
	process_duration = duration
	process_timer = duration
	process_label = label
	forced_animation = animation_name
	if station_id == "cutting":
		chop_player.play()
	elif station_id == "assembly":
		assemble_player.play()
	else:
		action_player.play()
	_show_message(label, Color(0.05, 0.18, 0.28))


func _update_processing(delta: float) -> void:
	if not processing:
		hud_progress_bar.visible = false
		forced_animation = ""
		return

	process_timer -= delta
	hud_progress_bar.visible = true
	hud_progress_bar.value = 1.0 - clamp(process_timer / process_duration, 0.0, 1.0)

	if process_timer <= 0.0:
		processing = false
		forced_animation = ""
		hud_progress_bar.visible = false
		set_held_item(process_output_item)
		_show_message("Made " + items[process_output_item]["display"], Color(0.05, 0.28, 0.12))
		assemble_player.play()


func set_held_item(item_id: String) -> void:
	held_item = item_id
	if held_visual != null:
		if held_visual.get_parent() != null:
			held_visual.get_parent().remove_child(held_visual)
		held_visual.free()
		held_visual = null
	if item_id == "":
		return

	held_visual = Node3D.new()
	held_visual.name = "HeldItem"
	hold_socket.add_child(held_visual)
	_add_model_to(held_visual, items[item_id]["model"], Vector3.ZERO, Vector3(0.56, 0.56, 0.56), 0.0)


func drop_held_item() -> void:
	if held_item == "":
		return
	_show_message("Dropped " + items[held_item]["display"], Color(0.16, 0.1, 0.08))
	set_held_item("")
	drop_player.play()


func _update_orders(delta: float) -> void:
	shift_time -= delta
	if shift_time <= 0.0:
		shift_time = 0.0
		show_game_over()
		return

	order_spawn_timer -= delta
	if order_spawn_timer <= 0.0 and orders.size() < 4:
		_spawn_order()
		order_spawn_timer = rng.randf_range(ORDER_SPAWN_MIN, ORDER_SPAWN_MAX)

	var still_active: Array = []
	for order in orders:
		order["time_left"] -= delta
		if order["time_left"] <= 0.0:
			missed_orders += 1
			score = max(0, score - 50)
			_show_message("Missed " + recipes[order["recipe"]]["display"] + "  -50", Color(0.38, 0.08, 0.05))
			error_player.play()
		else:
			still_active.append(order)
	orders = still_active


func _spawn_order() -> void:
	var recipe_id: String
	if served_orders == 0 and missed_orders == 0 and orders.is_empty():
		recipe_id = "onigiri"
	else:
		recipe_id = recipe_order[rng.randi_range(0, recipe_order.size() - 1)]
	var recipe = recipes[recipe_id]
	orders.append({
		"id": next_order_id,
		"recipe": recipe_id,
		"time_left": float(recipe["patience"]),
		"max_time": float(recipe["patience"]),
	})
	next_order_id += 1


func _update_hud() -> void:
	if hud_time_label == null:
		return
	hud_time_label.text = "Time " + _format_time(shift_time)
	hud_score_label.text = "Score " + str(score)
	hud_held_label.text = "Holding: " + ("Empty" if held_item == "" else items[held_item]["display"])

	if nearest_station.is_empty():
		hud_prompt_label.text = "Move to a station"
	else:
		hud_prompt_label.text = "E: " + _prompt_for_station(nearest_station) + "     Q: Drop"
	_update_guide_panel()

	for child in orders_container.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Orders"
	title.add_theme_font_size_override("font_size", 20)
	title.custom_minimum_size = Vector2(70, 40)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	orders_container.add_child(title)

	for order in orders:
		orders_container.add_child(_make_order_card(order))


func _make_order_card(order: Dictionary) -> Control:
	var recipe = recipes[order["recipe"]]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(158, 62)
	var ratio: float = clamp(float(order["time_left"]) / float(order["max_time"]), 0.0, 1.0)
	var bg := Color(1.0, 0.84, 0.55, 0.92)
	var border := Color(0.58, 0.10, 0.055, 0.76)
	var text_color := Color(0.24, 0.075, 0.035)
	if ratio < 0.28:
		bg = Color(0.66, 0.09, 0.045, 0.94)
		border = Color(1.0, 0.68, 0.34, 0.95)
		text_color = Color(1.0, 0.88, 0.62)
	panel.add_theme_stylebox_override("panel", _make_panel_style(bg, border, 8, 2, 8))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	var label := Label.new()
	label.text = recipe["display"]
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_shadow_color", Color(1.0, 0.90, 0.70, 0.42) if ratio >= 0.28 else Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(label)

	var ingredients := Label.new()
	ingredients.text = _recipe_short_steps(String(order["recipe"]))
	ingredients.clip_text = true
	ingredients.add_theme_font_size_override("font_size", 11)
	ingredients.add_theme_color_override("font_color", Color(0.45, 0.16, 0.07) if ratio >= 0.28 else Color(1.0, 0.80, 0.48))
	box.add_child(ingredients)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = ratio
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.28, 0.08, 0.035, 0.52), 5))
	bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.92, 0.32, 0.12, 0.96) if ratio >= 0.28 else Color(1.0, 0.78, 0.34, 0.96), 5))
	box.add_child(bar)

	return panel


func _update_guide_panel() -> void:
	if hud_guide_title_label == null or hud_guide_steps_label == null:
		return
	if orders.is_empty():
		hud_guide_title_label.text = "No tickets"
		hud_guide_steps_label.text = "Keep the counter clear. New customers will order soon."
		return

	var recipe_id := String(orders[0]["recipe"])
	var recipe = recipes[recipe_id]
	hud_guide_title_label.text = "Make " + String(recipe["display"])

	if held_item != "":
		if items[held_item]["type"] == "dish":
			hud_guide_steps_label.text = "Finished dish in hand. Walk to Serve Here and press E."
			return
		if held_item == "cucumber":
			hud_guide_steps_label.text = "Cucumber in hand. Use Cut first for rolls, or drop it if the ticket does not need it."
			return
		hud_guide_steps_label.text = String(items[held_item]["display"]) + " in hand. Walk to Assemble and press E."
		return

	if not assembly_ingredients.is_empty():
		var match := _find_matching_recipe(assembly_ingredients)
		if match != "":
			hud_guide_steps_label.text = "Assembly has " + _ingredient_summary(assembly_ingredients) + ". Press E at Assemble to make the dish."
		else:
			hud_guide_steps_label.text = "Assembly has " + _ingredient_summary(assembly_ingredients) + ". Add the remaining ticket ingredients."
		return

	hud_guide_steps_label.text = _recipe_long_steps(recipe_id)


func _recipe_short_steps(recipe_id: String) -> String:
	match recipe_id:
		"onigiri":
			return "Rice > Assemble"
		"salmon_nigiri":
			return "Rice + Salmon"
		"cucumber_roll":
			return "Cut Cucumber + Rice + Nori"
	return _ingredient_summary(recipes[recipe_id]["ingredients"])


func _recipe_long_steps(recipe_id: String) -> String:
	match recipe_id:
		"onigiri":
			return "Pick up Rice, use Assemble, press E again to finish, then Serve Here."
		"salmon_nigiri":
			return "Add Rice and Salmon to Assemble, press E again to finish, then Serve Here."
		"cucumber_roll":
			return "Cut Cucumber first, then add Sliced Cucumber, Rice, and Nori to Assemble. Serve the roll."
	return "Gather ingredients, use Assemble, then deliver at Serve Here."


func _prompt_for_station(station: Dictionary) -> String:
	match station["type"]:
		"ingredient":
			return "Pick up " + station["display"]
		"cutting":
			return "Cut cucumber into sliced cucumber"
		"assembly":
			if held_item == "":
				if assembly_ingredients.is_empty():
					return "Bring ticket ingredients here"
				return "Assemble " + _ingredient_summary(assembly_ingredients)
			return "Add " + String(items[held_item]["display"]) + " to recipe"
		"serving":
			if held_item != "" and items[held_item]["type"] == "dish":
				return "Deliver " + String(items[held_item]["display"])
			return "Bring finished dish here"
	return "Interact"


func _format_time(seconds: float) -> String:
	var total := int(ceil(seconds))
	var mins := total / 60
	var secs := total % 60
	return "%d:%02d" % [mins, secs]


func _show_message(message: String, color: Color) -> void:
	if hud_message_label == null:
		return
	if hud_message_panel != null:
		hud_message_panel.visible = true
		hud_message_panel.modulate = Color(1, 1, 1, 1)
	hud_message_label.text = message
	hud_message_label.add_theme_color_override("font_color", color)
	var tween := create_tween()
	hud_message_label.modulate = Color(1, 1, 1, 1)
	tween.tween_interval(1.05)
	if hud_message_panel != null:
		tween.tween_property(hud_message_panel, "modulate:a", 0.0, 0.35)
		tween.tween_callback(func() -> void:
			if hud_message_panel != null:
				hud_message_panel.visible = false
		)
	else:
		tween.tween_property(hud_message_label, "modulate:a", 0.0, 0.35)


func show_pause_menu() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	get_tree().paused = true
	overlay_layer = _build_overlay("Shift Paused", "Orders are holding. Jump back in when ready.", "pause")
	_add_overlay_note(overlay_layer, "Flow stays intact", "Resume keeps your held item, active orders, and station progress.")
	_add_overlay_button(overlay_layer, "Resume", resume_game, true)
	_add_overlay_button(overlay_layer, "Restart", restart_game)
	_add_overlay_button(overlay_layer, "Main Menu", _go_to_main_menu_from_pause)


func resume_game() -> void:
	if overlay_layer != null:
		overlay_layer.queue_free()
		overlay_layer = null
	get_tree().paused = false
	state = GameState.PLAYING


func restart_game() -> void:
	get_tree().paused = false
	start_game()


func _go_to_main_menu_from_pause() -> void:
	get_tree().paused = false
	show_main_menu()


func show_game_over() -> void:
	if state == GameState.GAME_OVER:
		return
	state = GameState.GAME_OVER
	if ui_layer != null:
		ui_layer.queue_free()
		ui_layer = null
	overlay_layer = _build_overlay("Shift Complete", "Final counter tally", "game_over")
	_add_overlay_stats(overlay_layer)
	_add_overlay_button(overlay_layer, "Restart", restart_game, true)
	_add_overlay_button(overlay_layer, "Main Menu", show_main_menu)


func _build_overlay(title_text: String, subtitle_text: String, overlay_kind: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.04, 0.025, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)

	var red_band := ColorRect.new()
	red_band.color = Color(0.56, 0.055, 0.035, 0.58)
	red_band.anchor_left = 0.0
	red_band.anchor_right = 1.0
	red_band.anchor_top = 0.5
	red_band.anchor_bottom = 0.5
	red_band.offset_top = -38
	red_band.offset_bottom = 38
	layer.add_child(red_band)

	var panel := PanelContainer.new()
	panel.name = "OverlayPanel"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.custom_minimum_size = Vector2(560, 420)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280, -210)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.13, 0.065, 0.04, 0.96), Color(1.0, 0.67, 0.25, 0.96), 8, 2, 24))
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "OverlayBox"
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var ribbon := _make_ui_label("SUSHI SHIFT" if overlay_kind == "pause" else "SERVICE REPORT", 13, Color(1.0, 0.67, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	ribbon.process_mode = Node.PROCESS_MODE_ALWAYS
	box.add_child(ribbon)

	var title := Label.new()
	title.name = "OverlayTitle"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.89, 0.65))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "OverlaySubtitle"
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.96, 0.78, 0.52))
	box.add_child(subtitle)

	_add_divider(box, Color(1.0, 0.67, 0.25, 0.42), 2)

	return layer


func _overlay_box(layer: CanvasLayer) -> VBoxContainer:
	return layer.get_node("OverlayPanel/OverlayBox") as VBoxContainer


func _add_overlay_note(layer: CanvasLayer, title_text: String, body_text: String) -> void:
	var box := _overlay_box(layer)
	var note := PanelContainer.new()
	note.name = "OverlayNote"
	note.process_mode = Node.PROCESS_MODE_ALWAYS
	note.custom_minimum_size = Vector2(0, 78)
	note.add_theme_stylebox_override("panel", _make_panel_style(Color(1.0, 0.84, 0.55, 0.90), Color(0.58, 0.10, 0.055, 0.62), 8, 1, 10))
	box.add_child(note)

	var note_box := VBoxContainer.new()
	note_box.process_mode = Node.PROCESS_MODE_ALWAYS
	note_box.add_theme_constant_override("separation", 3)
	note.add_child(note_box)

	var title := _make_ui_label(title_text, 16, Color(0.24, 0.075, 0.035), HORIZONTAL_ALIGNMENT_CENTER)
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	note_box.add_child(title)

	var body := _make_ui_label(body_text, 13, Color(0.44, 0.18, 0.08), HORIZONTAL_ALIGNMENT_CENTER)
	body.process_mode = Node.PROCESS_MODE_ALWAYS
	note_box.add_child(body)


func _add_overlay_stats(layer: CanvasLayer) -> void:
	var box := _overlay_box(layer)
	var stats := HBoxContainer.new()
	stats.name = "OverlayStats"
	stats.process_mode = Node.PROCESS_MODE_ALWAYS
	stats.add_theme_constant_override("separation", 10)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(stats)
	_add_overlay_stat_chip(stats, "Score", str(score))
	_add_overlay_stat_chip(stats, "Served", str(served_orders))
	_add_overlay_stat_chip(stats, "Missed", str(missed_orders))


func _add_overlay_stat_chip(parent: Control, title_text: String, value_text: String) -> void:
	var chip := PanelContainer.new()
	chip.process_mode = Node.PROCESS_MODE_ALWAYS
	chip.custom_minimum_size = Vector2(128, 74)
	chip.add_theme_stylebox_override("panel", _make_panel_style(Color(1.0, 0.84, 0.55, 0.92), Color(0.58, 0.10, 0.055, 0.70), 8, 1, 8))
	parent.add_child(chip)

	var box := VBoxContainer.new()
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	chip.add_child(box)

	var value := _make_ui_label(value_text, 24, Color(0.24, 0.075, 0.035), HORIZONTAL_ALIGNMENT_CENTER)
	value.process_mode = Node.PROCESS_MODE_ALWAYS
	box.add_child(value)

	var title := _make_ui_label(title_text, 13, Color(0.58, 0.10, 0.055), HORIZONTAL_ALIGNMENT_CENTER)
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	box.add_child(title)


func _add_overlay_button(layer: CanvasLayer, text: String, callback: Callable, primary := false) -> void:
	var box := _overlay_box(layer)
	var button := Button.new()
	button.name = "OverlayButton" + text.replace(" ", "")
	button.text = text
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(300, 52 if primary else 48)
	_style_button(button, primary)
	button.pressed.connect(callback)
	box.add_child(button)


func _find_matching_recipe(ingredients: Array) -> String:
	var sorted_given := ingredients.duplicate()
	sorted_given.sort()
	for recipe_id in recipe_order:
		var needed: Array = recipes[recipe_id]["ingredients"].duplicate()
		needed.sort()
		if sorted_given == needed:
			return recipe_id
	return ""


func _is_valid_recipe_prefix(ingredients: Array) -> bool:
	var counts := {}
	for ingredient in ingredients:
		counts[ingredient] = counts.get(ingredient, 0) + 1
	for recipe_id in recipe_order:
		var needed_counts := {}
		for ingredient in recipes[recipe_id]["ingredients"]:
			needed_counts[ingredient] = needed_counts.get(ingredient, 0) + 1
		var possible := true
		for ingredient in counts.keys():
			if counts[ingredient] > needed_counts.get(ingredient, 0):
				possible = false
				break
		if possible:
			return true
	return false


func _ingredient_summary(ingredient_ids: Array) -> String:
	var names: Array = []
	for ingredient in ingredient_ids:
		names.append(items[ingredient]["display"])
	return ", ".join(names)


func _add_model(name: String, path: String, position: Vector3, scale: Vector3, rotation_y: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = name
	holder.position = position
	holder.scale = scale
	holder.rotation.y = rotation_y
	world.add_child(holder)
	_add_model_to(holder, path, Vector3.ZERO, Vector3.ONE, 0.0)
	return holder


func _add_model_to(parent: Node, path: String, position: Vector3, scale: Vector3, rotation_y: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	holder.position = position
	holder.scale = scale
	holder.rotation.y = rotation_y
	parent.add_child(holder)

	var loaded := false
	var resource := ResourceLoader.load(path)
	if resource is PackedScene:
		holder.add_child((resource as PackedScene).instantiate())
		loaded = true
	elif not path.begins_with("res://") and path.get_extension().to_lower() in ["gltf", "glb"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(path, state)
		if error == OK:
			var scene := document.generate_scene(state)
			if scene != null:
				holder.add_child(scene)
				loaded = true

	if not loaded:
		model_fallback_count += 1
		model_fallback_paths.append(path)
		var fallback := MeshInstance3D.new()
		fallback.mesh = BoxMesh.new()
		fallback.material_override = _make_material(Color(0.9, 0.2, 0.3))
		holder.add_child(fallback)
	else:
		model_load_count += 1
	return holder


func _add_box(name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = _make_material(color)
	world.add_child(mesh_instance)
	return mesh_instance


func _make_material(color: Color, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _blocker_global_size(body: StaticBody3D) -> Vector3:
	var size := Vector3.ONE
	if body.has_meta("blocker_size"):
		size = body.get_meta("blocker_size")
	var scale := body.global_transform.basis.get_scale()
	return Vector3(abs(size.x * scale.x), abs(size.y * scale.y), abs(size.z * scale.z))


func _blocker_rect_xz(body: StaticBody3D) -> Rect2:
	var size := _blocker_global_size(body)
	return Rect2(
		Vector2(body.global_position.x - size.x * 0.5, body.global_position.z - size.z * 0.5),
		Vector2(size.x, size.z)
	)


func _circle_rect_penetration_xz(center: Vector2, radius: float, rect: Rect2) -> float:
	var closest := Vector2(
		clamp(center.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(center.y, rect.position.y, rect.position.y + rect.size.y)
	)
	var distance := center.distance_to(closest)
	return max(0.0, radius - distance)


func debug_get_collision_snapshot() -> Dictionary:
	var blockers: Array = []
	for body in collision_blockers:
		if body == null:
			continue
		var rect := _blocker_rect_xz(body)
		blockers.append({
			"name": body.name,
			"center": body.global_position,
			"size": _blocker_global_size(body),
			"rect": rect,
		})
	return {
		"player_position": player.global_position if player != null else Vector3.ZERO,
		"player_radius": PLAYER_RADIUS,
		"walk_bounds": Rect2(Vector2(WALK_MIN_X, WALK_MIN_Z), Vector2(WALK_MAX_X - WALK_MIN_X, WALK_MAX_Z - WALK_MIN_Z)),
		"blockers": blockers,
		"overlaps": debug_get_player_blocker_overlaps(),
	}


func debug_get_player_blocker_overlaps() -> Array:
	var overlaps: Array = []
	if player == null:
		return overlaps
	var player_center := Vector2(player.global_position.x, player.global_position.z)
	for body in collision_blockers:
		if body == null:
			continue
		var penetration := _circle_rect_penetration_xz(player_center, PLAYER_RADIUS, _blocker_rect_xz(body))
		if penetration > 0.01:
			overlaps.append({
				"name": body.name,
				"penetration": penetration,
				"player": player.global_position,
				"rect": _blocker_rect_xz(body),
			})
	return overlaps


func debug_get_animation_status() -> Dictionary:
	if animation_player == null:
		return {}
	var loop_modes := {}
	for animation_name in ["Idle", "Idle_Holding", "Walk", "Walk_Holding", "Chop_Loop", "Assembly_Loop"]:
		if animation_player.has_animation(animation_name):
			var animation := animation_player.get_animation(animation_name)
			loop_modes[animation_name] = animation.loop_mode if animation != null else -1
	return {
		"current": current_animation,
		"is_playing": animation_player.is_playing(),
		"loop_modes": loop_modes,
	}


func get_debug_snapshot() -> Dictionary:
	return {
		"state": state,
		"score": score,
		"served_orders": served_orders,
		"missed_orders": missed_orders,
		"held_item": held_item,
		"orders": orders.size(),
		"stations": stations.size(),
		"collision_blockers": collision_blockers.size(),
		"shift_time": shift_time,
		"has_world": world != null,
		"has_player": player != null,
		"model_load_count": model_load_count,
		"model_fallback_count": model_fallback_count,
		"model_fallback_paths": model_fallback_paths.duplicate(),
		"music_loaded": music_player != null and music_player.stream != null,
	}


func debug_complete_recipe(recipe_id: String) -> bool:
	if not recipes.has(recipe_id):
		return false
	var output: String = recipes[recipe_id]["output"]
	set_held_item(output)
	var before := score
	_use_serving_station()
	return score > before
