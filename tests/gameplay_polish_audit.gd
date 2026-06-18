extends SceneTree


var main


func _initialize() -> void:
	var scene := load("res://scenes/Main.tscn")
	if scene == null:
		push_error("Main scene did not load")
		quit(1)
		return

	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.start_game()
	await process_frame
	await physics_frame

	_assert(ResourceLoader.exists("res://assets/audio/sushi_shift_theme.mp3"), "music asset imported")
	_assert(ResourceLoader.exists("res://assets/audio/sfx_pickup.mp3"), "pickup sfx imported")
	_assert(ResourceLoader.exists("res://assets/audio/sfx_chop.mp3"), "chop sfx imported")
	_assert(ResourceLoader.exists("res://assets/audio/sfx_assemble.mp3"), "assemble sfx imported")
	_assert(ResourceLoader.exists("res://assets/audio/sfx_serve_success.mp3"), "serve sfx imported")
	_assert(ResourceLoader.exists("res://assets/audio/sfx_error.mp3"), "error sfx imported")
	_assert(ResourceLoader.exists("res://assets/audio/sfx_drop.mp3"), "drop sfx imported")
	_assert(main.music_player != null and main.music_player.stream != null, "music player has stream")
	_assert(main.music_player.volume_db <= -14.0, "music is not too loud")

	_assert(main.hud_guide_title_label.text.contains("Make Onigiri"), "guide starts with first recipe")
	_assert(main.hud_guide_steps_label.text.contains("Rice"), "guide explains rice")
	_assert(main.hud_guide_steps_label.text.contains("Serve"), "guide explains delivery")
	_assert(_station_label_count() >= 7, "station labels exist")

	main.player_visual.rotation.y = 0.0
	main.set_held_item("rice")
	await process_frame
	var front: Vector3 = main.player_visual.global_transform.basis.z.normalized()
	var to_item: Vector3 = main.held_visual.global_position - main.player_visual.global_position
	_assert(main.hold_socket.position.z > 0.45, "hold socket is on local front side")
	_assert(to_item.dot(front) > 0.25, "held item is in front of character")

	main._update_hud()
	_assert(main.hud_guide_steps_label.text.contains("Assemble"), "guide updates after pickup")

	Input.action_press("move_down")
	for _i in range(100):
		await physics_frame
	var status: Dictionary = main.debug_get_animation_status()
	Input.action_release("move_down")
	_assert(status["current"] == "Walk_Holding", "held walk animation is active")
	_assert(status["is_playing"], "walk animation keeps playing")
	var loop_modes: Dictionary = status["loop_modes"]
	_assert(int(loop_modes["Walk"]) == Animation.LOOP_LINEAR, "walk loops")
	_assert(int(loop_modes["Walk_Holding"]) == Animation.LOOP_LINEAR, "held walk loops")
	_assert(int(loop_modes["Idle"]) == Animation.LOOP_LINEAR, "idle loops")

	print("Sushi Shift gameplay polish audit passed")
	quit(0)


func _station_label_count() -> int:
	var labels: Array = main.world.find_children("StationLabel", "Label3D", true, false)
	return labels.size()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Assertion failed: " + message)
	quit(1)
