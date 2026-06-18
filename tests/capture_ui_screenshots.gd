extends SceneTree

const VIEWPORT_SIZE := Vector2(1280, 720)
const OUTPUT_DIR := "res://screenshots"


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
	await create_timer(0.15).timeout
	if not _save_screenshot("menu.png"):
		quit(1)
		return

	main.start_game()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	main.show_pause_menu()
	await process_frame
	if not _save_screenshot("pause.png"):
		quit(1)
		return

	main.resume_game()
	await process_frame
	main.score = 450
	main.served_orders = 3
	main.missed_orders = 1
	main.show_game_over()
	await process_frame
	if not _save_screenshot("game_over.png"):
		quit(1)
		return

	print("Saved UI screenshots")
	quit(0)


func _save_screenshot(file_name: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Screenshot image is empty: " + file_name)
		return false

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := OUTPUT_DIR + "/" + file_name
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save screenshot " + file_name + ": " + str(error))
		return false

	print("Saved screenshot to " + ProjectSettings.globalize_path(output_path))
	return true
