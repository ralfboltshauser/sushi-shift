extends SceneTree


func _initialize() -> void:
	var scene := load("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.start_game()
	await process_frame
	main.set_held_item("rice")
	main.player_visual.rotation.y = 0.0
	await process_frame
	await create_timer(0.25).timeout

	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Screenshot image is empty")
		quit(1)
		return

	var output_path := "res://screenshots/held_item.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save screenshot: " + str(error))
		quit(1)
		return

	print("Saved screenshot to " + ProjectSettings.globalize_path(output_path))
	quit(0)
