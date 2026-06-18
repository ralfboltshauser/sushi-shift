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
	_assert(main.state == main.GameState.PLAYING, "game starts")
	_assert(main.orders.size() == 1, "initial order exists")
	_assert(main.orders[0]["recipe"] == "onigiri", "initial order is onigiri")

	await _make_onigiri()
	_assert(main.served_orders == 1, "served onigiri")
	_assert(main.score > 0, "score increased after onigiri")

	_force_next_order("salmon_nigiri")
	await _make_salmon_nigiri()
	_assert(main.served_orders == 2, "served salmon nigiri")

	_force_next_order("cucumber_roll")
	await _make_cucumber_roll()
	_assert(main.served_orders == 3, "served cucumber roll")

	_force_next_order("onigiri")
	main.orders[main.orders.size() - 1]["time_left"] = 0.05
	await create_timer(0.15).timeout
	_assert(main.missed_orders == 1, "order can expire")

	main.show_pause_menu()
	await process_frame
	_assert(main.state == main.GameState.PAUSED, "pause opens")
	main.resume_game()
	await process_frame
	_assert(main.state == main.GameState.PLAYING, "resume works")

	main.shift_time = 0.05
	await create_timer(0.15).timeout
	_assert(main.state == main.GameState.GAME_OVER, "shift reaches game over")

	main.restart_game()
	await process_frame
	_assert(main.state == main.GameState.PLAYING, "restart from game over works")
	_assert(main.score == 0, "restart resets score")

	print("Sushi Shift playthrough test passed")
	quit(0)


func _make_onigiri() -> void:
	await _pickup("rice_bin", "rice")
	await _use_station("assembly")
	await _use_station("assembly")
	await _wait_for_item("onigiri")
	await _use_station("serving")


func _make_salmon_nigiri() -> void:
	await _pickup("rice_bin", "rice")
	await _use_station("assembly")
	await _pickup("salmon_bin", "salmon")
	await _use_station("assembly")
	await _use_station("assembly")
	await _wait_for_item("salmon_nigiri")
	await _use_station("serving")


func _make_cucumber_roll() -> void:
	await _pickup("cucumber_bin", "cucumber")
	await _use_station("cutting")
	await _wait_for_item("sliced_cucumber")
	await _use_station("assembly")
	await _pickup("rice_bin", "rice")
	await _use_station("assembly")
	await _pickup("nori_bin", "nori")
	await _use_station("assembly")
	await _use_station("assembly")
	await _wait_for_item("cucumber_roll")
	await _use_station("serving")


func _pickup(station_id: String, expected_item: String) -> void:
	await _use_station(station_id)
	_assert(main.held_item == expected_item, "picked up " + expected_item)


func _use_station(station_id: String) -> void:
	var station := _station(station_id)
	_assert(not station.is_empty(), "station exists: " + station_id)
	main.player.position = (station["node"] as Node3D).position
	main._update_nearest_station()
	main.interact()
	await process_frame


func _wait_for_item(item_id: String) -> void:
	var deadline := 4.0
	while deadline > 0.0 and main.held_item != item_id:
		await create_timer(0.1).timeout
		deadline -= 0.1
	_assert(main.held_item == item_id, "waited for " + item_id)


func _force_next_order(recipe_id: String) -> void:
	main.orders.clear()
	main._spawn_order()
	var order = main.orders[main.orders.size() - 1]
	order["recipe"] = recipe_id
	order["time_left"] = main.recipes[recipe_id]["patience"]
	order["max_time"] = main.recipes[recipe_id]["patience"]


func _station(station_id: String) -> Dictionary:
	for station in main.stations:
		if station["id"] == station_id:
			return station
	return {}


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Assertion failed: " + message)
	quit(1)
