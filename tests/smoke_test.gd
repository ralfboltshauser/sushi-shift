extends SceneTree


func _initialize() -> void:
	var scene := load("res://scenes/Main.tscn")
	if scene == null:
		push_error("Main scene did not load")
		quit(1)
		return

	var main = scene.instantiate()
	root.add_child(main)
	await process_frame

	main.start_game()
	await process_frame
	await process_frame

	var snapshot: Dictionary = main.get_debug_snapshot()
	_assert(snapshot["has_world"], "world exists")
	_assert(snapshot["has_player"], "player exists")
	_assert(snapshot["stations"] >= 7, "stations created")
	_assert(snapshot["orders"] >= 1, "initial order spawned")
	_assert(snapshot["model_load_count"] >= 30, "Quaternius models loaded")
	_assert(snapshot["model_fallback_count"] == 0, "no model fallbacks: " + str(snapshot["model_fallback_paths"]))

	_assert(main.debug_complete_recipe("onigiri"), "onigiri can be served")
	main._spawn_order()
	main.orders[main.orders.size() - 1]["recipe"] = "salmon_nigiri"
	main.orders[main.orders.size() - 1]["time_left"] = 30.0
	main.orders[main.orders.size() - 1]["max_time"] = 30.0
	_assert(main.debug_complete_recipe("salmon_nigiri"), "salmon nigiri can be served")
	main._spawn_order()
	main.orders[main.orders.size() - 1]["recipe"] = "cucumber_roll"
	main.orders[main.orders.size() - 1]["time_left"] = 30.0
	main.orders[main.orders.size() - 1]["max_time"] = 30.0
	_assert(main.debug_complete_recipe("cucumber_roll"), "cucumber roll can be served")

	main.show_pause_menu()
	await process_frame
	_assert(main.state == main.GameState.PAUSED, "pause opens")
	main.resume_game()
	await process_frame
	_assert(main.state == main.GameState.PLAYING, "resume returns to play")

	main.show_game_over()
	await process_frame
	_assert(main.state == main.GameState.GAME_OVER, "game over opens")

	main.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout

	print("Sushi Shift smoke test passed")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Assertion failed: " + message)
	quit(1)
