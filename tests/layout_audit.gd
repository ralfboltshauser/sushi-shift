extends SceneTree

const OUTPUT_PATH := "res://screenshots/layout_audit.txt"
const VIEWPORT_SIZE := Vector2(1280, 720)
const WORLD_NAMES := [
	"Player",
	"GuestRabbitPink",
	"GuestRabbitBlond",
	"GuestRabbitGrey",
	"Fridge",
	"Oven",
	"CanFridge",
	"Pots",
	"Bottles",
	"BambooPlanter",
		"PlantLeft",
		"SakuraAccent",
		"DisplayOnigiriPlate",
		"DisplayNigiriPlate",
		"DisplayRollPlate",
		"DisplayDangoPlate",
		"DisplayRamenPlate",
		"DisplayTamagoPlate",
		"rice_bin",
		"salmon_bin",
		"nori_bin",
		"cucumber_bin",
	"cutting",
	"assembly",
	"serving",
]

var report_lines: Array[String] = []
var main
var camera: Camera3D


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	var scene := load("res://scenes/Main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.start_game()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout

	camera = main.world.get_node("Camera") as Camera3D
	_report_world_projection()
	_report_size_balance()
	_report_ui_size_balance()
	_report_edge_clipping()
	_report_ui_projection_overlap()
	_report_station_spacing()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file == null:
		push_error("Could not write layout audit")
		quit(1)
		return
	for line in report_lines:
		file.store_line(line)
		print(line)
	file.close()
	quit(0)


func _report_world_projection() -> void:
	report_lines.append("WORLD_SCREEN_BOUNDS")
	for name in WORLD_NAMES:
		var node := _find_world_node(name)
		if node == null:
			report_lines.append("MISSING " + name)
			continue
		var rect := _projected_rect(node)
		var aabb := _global_aabb(node)
		report_lines.append("%s pos=(%.2f,%.2f,%.2f) aabb=%s screen=%s" % [
			name,
			node.global_position.x,
			node.global_position.y,
			node.global_position.z,
			_format_aabb(aabb),
			_format_rect(rect),
			])


func _report_size_balance() -> void:
	report_lines.append("")
	report_lines.append("SIZE_BALANCE")
	var outliers: Array[String] = []
	for name in WORLD_NAMES:
		var node := _find_world_node(name)
		if node == null:
			continue
		var rules := _size_rules_for_world(name)
		if rules.is_empty():
			continue
		var rect := _projected_rect(node)
		if rect.size == Vector2.ZERO:
			outliers.append(name + " has no projected size")
			continue
		var flags := _size_flags(rect, rules)
		var status := "OK" if flags.is_empty() else "OUTLIER " + ", ".join(flags)
		var line := "%s group=%s screen=%s area=%.0f target=(w %.0f-%.0f h %.0f-%.0f) %s" % [
			name,
			String(rules["group"]),
			_format_rect(rect),
			rect.size.x * rect.size.y,
			float(rules["min_w"]),
			float(rules["max_w"]),
			float(rules["min_h"]),
			float(rules["max_h"]),
			status,
		]
		report_lines.append(line)
		if not flags.is_empty():
			outliers.append(line)

	report_lines.append("")
	report_lines.append("SIZE_OUTLIERS")
	if outliers.is_empty():
		report_lines.append("none")
	else:
		for line in outliers:
			report_lines.append(line)


func _report_ui_size_balance() -> void:
	report_lines.append("")
	report_lines.append("UI_SIZE_BALANCE")
	var rects := _collect_ui_rects()
	var outliers: Array[String] = []
	for ui_name in rects.keys():
		var rules := _size_rules_for_ui(String(ui_name))
		if rules.is_empty():
			continue
		var rect: Rect2 = rects[ui_name]
		var flags := _size_flags(rect, rules)
		var status := "OK" if flags.is_empty() else "OUTLIER " + ", ".join(flags)
		var line := "%s group=%s screen=%s target=(w %.0f-%.0f h %.0f-%.0f) %s" % [
			String(ui_name),
			String(rules["group"]),
			_format_rect(rect),
			float(rules["min_w"]),
			float(rules["max_w"]),
			float(rules["min_h"]),
			float(rules["max_h"]),
			status,
		]
		report_lines.append(line)
		if not flags.is_empty():
			outliers.append(line)

	report_lines.append("")
	report_lines.append("UI_SIZE_OUTLIERS")
	if outliers.is_empty():
		report_lines.append("none")
	else:
		for line in outliers:
			report_lines.append(line)


func _size_rules_for_world(name: String) -> Dictionary:
	if name == "Player":
		return {"group": "player", "min_w": 340.0, "max_w": 530.0, "min_h": 260.0, "max_h": 340.0}
	if name.begins_with("GuestRabbit"):
		return {"group": "guest", "min_w": 240.0, "max_w": 390.0, "min_h": 220.0, "max_h": 290.0}
	if name.begins_with("Display"):
		return {"group": "counter_food", "min_w": 86.0, "max_w": 145.0, "min_h": 70.0, "max_h": 108.0}
	if name in ["rice_bin", "salmon_bin", "nori_bin", "cucumber_bin", "cutting", "assembly"]:
		return {"group": "prep_station", "min_w": 150.0, "max_w": 380.0, "min_h": 125.0, "max_h": 245.0}
	if name == "serving":
		return {"group": "serve_station", "min_w": 150.0, "max_w": 330.0, "min_h": 100.0, "max_h": 245.0}
	if name in ["Fridge", "Oven", "CanFridge"]:
		return {"group": "appliance", "min_w": 120.0, "max_w": 330.0, "min_h": 140.0, "max_h": 330.0}
	if name == "BambooPlanter":
		return {"group": "background_large_prop", "min_w": 80.0, "max_w": 150.0, "min_h": 120.0, "max_h": 220.0}
	if name in ["Pots", "Bottles", "PlantLeft", "SakuraAccent"]:
		return {"group": "background_small_prop", "min_w": 36.0, "max_w": 125.0, "min_h": 45.0, "max_h": 110.0}
	return {}


func _size_rules_for_ui(name: String) -> Dictionary:
	match name:
		"StatusPanel":
			return {"group": "hud_status", "min_w": 270.0, "max_w": 380.0, "min_h": 42.0, "max_h": 64.0}
		"OrdersPanel":
			return {"group": "hud_orders", "min_w": 760.0, "max_w": 830.0, "min_h": 72.0, "max_h": 92.0}
		"OrdersStrip":
			return {"group": "hud_orders_strip", "min_w": 740.0, "max_w": 810.0, "min_h": 58.0, "max_h": 76.0}
		"GuidePanel":
			return {"group": "hud_guide", "min_w": 500.0, "max_w": 560.0, "min_h": 78.0, "max_h": 100.0}
		"PromptPanel":
			return {"group": "hud_prompt", "min_w": 380.0, "max_w": 520.0, "min_h": 36.0, "max_h": 52.0}
		"MessagePanel":
			return {"group": "hud_message", "min_w": 500.0, "max_w": 560.0, "min_h": 42.0, "max_h": 56.0}
	return {}


func _size_flags(rect: Rect2, rules: Dictionary) -> Array[String]:
	var flags: Array[String] = []
	if rect.size.x < float(rules["min_w"]):
		flags.append("w too small")
	if rect.size.x > float(rules["max_w"]):
		flags.append("w too large")
	if rect.size.y < float(rules["min_h"]):
		flags.append("h too small")
	if rect.size.y > float(rules["max_h"]):
		flags.append("h too large")
	return flags


func _report_ui_projection_overlap() -> void:
	report_lines.append("")
	report_lines.append("UI_WORLD_OVERLAP")
	var ui_rects := _collect_ui_rects()
	for ui_name in ui_rects.keys():
		var ui_rect: Rect2 = ui_rects[ui_name]
		for world_name in WORLD_NAMES:
			var node: Node3D = _find_world_node(world_name)
			if node == null:
				continue
			var world_rect := _projected_rect(node)
			if world_rect.size == Vector2.ZERO:
				continue
			var overlap: float = _rect_overlap_area(ui_rect, world_rect)
			if overlap <= 1.0:
				continue
			var ratio: float = overlap / max(1.0, world_rect.size.x * world_rect.size.y)
			if ratio >= 0.08:
				report_lines.append("%s overlaps %s area=%.0f world_ratio=%.2f ui=%s world=%s" % [
					ui_name,
					world_name,
					overlap,
					ratio,
					_format_rect(ui_rect),
					_format_rect(world_rect),
				])


func _report_edge_clipping() -> void:
	report_lines.append("")
	report_lines.append("SCREEN_EDGE_CLIPPING")
	for world_name in WORLD_NAMES:
		var node: Node3D = _find_world_node(world_name)
		if node == null:
			continue
		var rect := _projected_rect(node)
		if rect.size == Vector2.ZERO:
			continue
		var left_clip: float = max(0.0, -rect.position.x)
		var top_clip: float = max(0.0, -rect.position.y)
		var right_clip: float = max(0.0, rect.position.x + rect.size.x - VIEWPORT_SIZE.x)
		var bottom_clip: float = max(0.0, rect.position.y + rect.size.y - VIEWPORT_SIZE.y)
		if left_clip + top_clip + right_clip + bottom_clip > 8.0:
			report_lines.append("%s clip=(l=%.1f t=%.1f r=%.1f b=%.1f) screen=%s" % [
				world_name,
				left_clip,
				top_clip,
				right_clip,
				bottom_clip,
				_format_rect(rect),
			])


func _report_station_spacing() -> void:
	report_lines.append("")
	report_lines.append("STATION_SPACING")
	var station_nodes: Array[Node3D] = []
	for station in main.stations:
		station_nodes.append(station["node"] as Node3D)

	for i in range(station_nodes.size()):
		for j in range(i + 1, station_nodes.size()):
			var a: Node3D = station_nodes[i]
			var b: Node3D = station_nodes[j]
			var distance: float = Vector2(a.global_position.x, a.global_position.z).distance_to(Vector2(b.global_position.x, b.global_position.z))
			if distance < 1.55:
				report_lines.append("CLOSE %s <-> %s distance=%.2f" % [a.name, b.name, distance])


func _collect_ui_rects() -> Dictionary:
	var rects := {}
	if main.ui_layer == null:
		return rects
	var root_control := main.ui_layer.get_node("HUDRoot") as Control
	_collect_control_rects(root_control, rects)
	return rects


func _collect_control_rects(control: Control, rects: Dictionary) -> void:
	if control.name != "HUDRoot" and control.visible and control.get_global_rect().size.length() > 0.0:
		rects[control.name] = control.get_global_rect()
	for child in control.get_children():
		if child is Control:
			_collect_control_rects(child as Control, rects)


func _find_world_node(name: String) -> Node3D:
	if main.world == null:
		return null
	var matches: Array[Node] = main.world.find_children(name, "Node3D", true, false)
	for node in matches:
		if node.name == name:
			return node as Node3D
	return null


func _projected_rect(node: Node3D) -> Rect2:
	var aabb: AABB = _global_aabb(node)
	if aabb.size == Vector3.ZERO:
		return Rect2()

	var points: Array[Vector3] = _aabb_points(aabb)
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	var visible_count := 0
	for point in points:
		if camera.is_position_behind(point):
			continue
		var screen_point: Vector2 = camera.unproject_position(point)
		min_point = min_point.min(screen_point)
		max_point = max_point.max(screen_point)
		visible_count += 1

	if visible_count == 0:
		return Rect2()
	return Rect2(min_point, max_point - min_point)


func _global_aabb(node: Node3D) -> AABB:
	var found := false
	var merged := AABB()
	var geometries: Array[Node] = node.find_children("*", "GeometryInstance3D", true, false)
	for geometry in geometries:
		if geometry is MeshInstance3D:
			var mesh_instance := geometry as MeshInstance3D
			var mesh_aabb: AABB = mesh_instance.get_aabb()
			if mesh_aabb.size == Vector3.ZERO:
				continue
			var global_aabb: AABB = mesh_instance.global_transform * mesh_aabb
			if not found:
				merged = global_aabb
				found = true
			else:
				merged = merged.merge(global_aabb)
	if not found:
		return AABB()
	return merged


func _aabb_points(aabb: AABB) -> Array[Vector3]:
	var p: Vector3 = aabb.position
	var s: Vector3 = aabb.size
	return [
		p,
		p + Vector3(s.x, 0, 0),
		p + Vector3(0, s.y, 0),
		p + Vector3(0, 0, s.z),
		p + Vector3(s.x, s.y, 0),
		p + Vector3(s.x, 0, s.z),
		p + Vector3(0, s.y, s.z),
		p + s,
	]


func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var x1: float = max(a.position.x, b.position.x)
	var y1: float = max(a.position.y, b.position.y)
	var x2: float = min(a.position.x + a.size.x, b.position.x + b.size.x)
	var y2: float = min(a.position.y + a.size.y, b.position.y + b.size.y)
	if x2 <= x1 or y2 <= y1:
		return 0.0
	return (x2 - x1) * (y2 - y1)


func _format_rect(rect: Rect2) -> String:
	return "(x=%.1f y=%.1f w=%.1f h=%.1f)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _format_aabb(aabb: AABB) -> String:
	return "(x=%.2f y=%.2f z=%.2f sx=%.2f sy=%.2f sz=%.2f)" % [
		aabb.position.x,
		aabb.position.y,
		aabb.position.z,
		aabb.size.x,
		aabb.size.y,
		aabb.size.z,
	]
