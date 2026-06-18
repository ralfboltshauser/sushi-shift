extends SceneTree

const OUTPUT_PATH := "res://screenshots/collision_audit.txt"

var main
var report_lines: Array[String] = []


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

	report_lines.append("COLLISION_BLOCKERS")
	_append_blocker_report()

	await _drive_case("bottom_counter", Vector3(0.0, 0.75, -0.45), "move_down", 1.8)
	await _drive_case("prep_station_row", Vector3(-3.15, 0.75, -0.72), "move_up", 1.8)
	await _drive_case("left_wall", Vector3(-6.15, 0.75, -0.80), "move_left", 1.4)
	await _drive_case("right_wall", Vector3(6.15, 0.75, -0.80), "move_right", 1.4)

	var file_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write collision audit")
		quit(1)
		return
	for line in report_lines:
		file.store_line(line)
		print(line)
	file.close()
	main.queue_free()
	await process_frame
	print("Sushi Shift collision audit passed")
	quit(0)


func _append_blocker_report() -> void:
	var snapshot: Dictionary = main.debug_get_collision_snapshot()
	for blocker in snapshot["blockers"]:
		var rect: Rect2 = blocker["rect"]
		var center: Vector3 = blocker["center"]
		var size: Vector3 = blocker["size"]
		report_lines.append("%s center=(%.2f,%.2f,%.2f) size=(%.2f,%.2f,%.2f) rect_xz=(x=%.2f z=%.2f w=%.2f d=%.2f)" % [
			String(blocker["name"]),
			center.x,
			center.y,
			center.z,
			size.x,
			size.y,
			size.z,
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y,
		])


func _drive_case(case_name: String, start_position: Vector3, action_name: String, seconds: float) -> void:
	main.player.position = start_position
	main.player.velocity = Vector3.ZERO
	await physics_frame

	Input.action_press(action_name)
	var frames := int(ceil(seconds * 60.0))
	for _i in range(frames):
		await physics_frame
	Input.action_release(action_name)
	await physics_frame

	var snapshot: Dictionary = main.debug_get_collision_snapshot()
	var position: Vector3 = snapshot["player_position"]
	var overlaps: Array = snapshot["overlaps"]
	report_lines.append("")
	report_lines.append("CASE %s action=%s start=(%.2f,%.2f) final=(%.2f,%.2f) overlaps=%d" % [
		case_name,
		action_name,
		start_position.x,
		start_position.z,
		position.x,
		position.z,
		overlaps.size(),
	])
	for overlap in overlaps:
		var rect: Rect2 = overlap["rect"]
		report_lines.append("OVERLAP %s penetration=%.3f rect=(x=%.2f z=%.2f w=%.2f d=%.2f)" % [
			String(overlap["name"]),
			float(overlap["penetration"]),
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y,
		])

	_assert(overlaps.is_empty(), case_name + " has no blocker overlap")
	_assert(position.x >= main.WALK_MIN_X - 0.01 and position.x <= main.WALK_MAX_X + 0.01, case_name + " stays inside x walk bounds")
	_assert(position.z >= main.WALK_MIN_Z - 0.01 and position.z <= main.WALK_MAX_Z + 0.01, case_name + " stays inside z walk bounds")

	if case_name == "bottom_counter":
		_assert(position.z <= main.WALK_MAX_Z + 0.01, "bottom movement is clamped before dining/bar area")
	if case_name == "prep_station_row":
		_assert(position.z > -1.45, "prep station row blocks forward movement before counter overlap")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Assertion failed: " + message)
	quit(1)
