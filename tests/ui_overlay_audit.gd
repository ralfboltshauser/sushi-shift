extends SceneTree

const VIEWPORT_SIZE := Vector2(1280, 720)
const OUTPUT_PATH := "res://screenshots/ui_overlay_audit.txt"

var report_lines: Array[String] = []


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	var scene := load("res://scenes/Main.tscn")
	if scene == null:
		push_error("Main scene did not load")
		quit(1)
		return

	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	_audit_main_menu(main)

	main.start_game()
	await process_frame
	await process_frame
	main.show_pause_menu()
	await process_frame
	_audit_pause(main)

	main.resume_game()
	await process_frame
	main.score = 450
	main.served_orders = 3
	main.missed_orders = 1
	main.show_game_over()
	await process_frame
	_audit_game_over(main)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file == null:
		push_error("Could not write UI overlay audit")
		quit(1)
		return
	for line in report_lines:
		file.store_line(line)
		print(line)
	file.close()

	var failures := []
	for line in report_lines:
		if line.begins_with("FAIL"):
			failures.append(line)
	if not failures.is_empty():
		push_error("UI overlay audit failed")
		quit(1)
		return

	quit(0)


func _audit_main_menu(main) -> void:
	report_lines.append("MAIN_MENU")
	_assert_control(main.overlay_layer, "MainMenuPanel", Vector2(860, 500))
	_assert_control(main.overlay_layer, "MainMenuStartButton", Vector2(300, 50))
	_assert_control(main.overlay_layer, "MainMenuQuitButton", Vector2(300, 44))
	_assert_control(main.overlay_layer, "MainMenuControls", Vector2(440, 44))
	_assert_control(main.overlay_layer, "MainMenuRecipeList", Vector2(280, 250))


func _audit_pause(main) -> void:
	report_lines.append("")
	report_lines.append("PAUSE_OVERLAY")
	_assert_control(main.overlay_layer, "OverlayPanel", Vector2(540, 390))
	_assert_control(main.overlay_layer, "OverlayNote", Vector2(480, 70))
	_assert_control(main.overlay_layer, "OverlayButtonResume", Vector2(290, 48))
	_assert_control(main.overlay_layer, "OverlayButtonRestart", Vector2(290, 44))
	_assert_control(main.overlay_layer, "OverlayButtonMainMenu", Vector2(290, 44))


func _audit_game_over(main) -> void:
	report_lines.append("")
	report_lines.append("GAME_OVER_OVERLAY")
	_assert_control(main.overlay_layer, "OverlayPanel", Vector2(540, 360))
	_assert_control(main.overlay_layer, "OverlayStats", Vector2(390, 70))
	_assert_control(main.overlay_layer, "OverlayButtonRestart", Vector2(290, 48))
	_assert_control(main.overlay_layer, "OverlayButtonMainMenu", Vector2(290, 44))


func _assert_control(layer: CanvasLayer, name: String, min_size: Vector2) -> void:
	var control := _find_control(layer, name)
	if control == null:
		report_lines.append("FAIL missing " + name)
		return

	var rect := control.get_global_rect()
	var flags := []
	if rect.size.x < min_size.x:
		flags.append("w too small")
	if rect.size.y < min_size.y:
		flags.append("h too small")
	if rect.position.x < -1.0 or rect.position.y < -1.0:
		flags.append("off top/left")
	if rect.position.x + rect.size.x > VIEWPORT_SIZE.x + 1.0 or rect.position.y + rect.size.y > VIEWPORT_SIZE.y + 1.0:
		flags.append("off bottom/right")

	var status := "OK" if flags.is_empty() else "FAIL " + ", ".join(flags)
	report_lines.append("%s %s rect=%s min=%s" % [status, name, _format_rect(rect), _format_vec2(min_size)])


func _find_control(layer: CanvasLayer, name: String) -> Control:
	if layer == null:
		return null
	var matches := layer.find_children(name, "Control", true, false)
	for node in matches:
		if node.name == name and node is Control:
			return node as Control
	return null


func _format_rect(rect: Rect2) -> String:
	return "(x=%.1f y=%.1f w=%.1f h=%.1f)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _format_vec2(value: Vector2) -> String:
	return "(w=%.1f h=%.1f)" % [value.x, value.y]
