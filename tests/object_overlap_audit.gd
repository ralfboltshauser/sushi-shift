extends SceneTree

const OUTPUT_PATH := "res://screenshots/object_overlap_audit.txt"
const DEBUG_SCREENSHOT_PATH := "res://screenshots/object_overlap_audit.png"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const MIN_BAD_OVERLAP_AREA := 0.035

const OBJECT_GROUPS := {
	"rice_bin": "station",
	"salmon_bin": "station",
	"nori_bin": "station",
	"cucumber_bin": "station",
	"cutting": "station",
	"assembly": "station",
	"serving": "station",
	"Fridge": "appliance",
	"Oven": "appliance",
	"CanFridge": "appliance",
	"BambooPlanter": "decor",
	"PlantLeft": "decor",
	"SakuraAccent": "decor",
	"Pots": "small_prop",
	"Bottles": "small_prop",
}

var main
var report_lines: Array[String] = []


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
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
	await process_frame

	var objects := _collect_objects()
	report_lines.append("OBJECT_FOOTPRINTS")
	for object in objects:
		var rect: Rect2 = object["rect"]
		var aabb: AABB = object["aabb"]
		report_lines.append("%s group=%s aabb=(x=%.2f z=%.2f sx=%.2f sz=%.2f) rect=(x=%.2f z=%.2f w=%.2f d=%.2f)" % [
			String(object["name"]),
			String(object["group"]),
			aabb.position.x,
			aabb.position.z,
			aabb.size.x,
			aabb.size.z,
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y,
		])

	report_lines.append("")
	report_lines.append("OBJECT_OVERLAPS")
	var bad_overlaps: Array[String] = []
	for i in range(objects.size()):
		for j in range(i + 1, objects.size()):
			var a: Dictionary = objects[i]
			var b: Dictionary = objects[j]
			var area: float = _rect_overlap_area(a["rect"], b["rect"])
			if area <= 0.001:
				continue
			var min_area: float = min(_rect_area(a["rect"]), _rect_area(b["rect"]))
			var ratio: float = area / max(0.001, min_area)
			var status := "allowed"
			if _is_bad_overlap(a, b, ratio):
				status = "BAD"
				bad_overlaps.append("%s overlaps %s ratio=%.2f area=%.2f" % [a["name"], b["name"], ratio, area])
				_add_bad_overlap_marker(_rect_overlap(a["rect"], b["rect"]), String(a["name"]) + "_vs_" + String(b["name"]))
			report_lines.append("%s %s <-> %s area=%.2f min_ratio=%.2f" % [
				status,
				String(a["name"]),
				String(b["name"]),
				area,
				ratio,
			])

	report_lines.append("")
	report_lines.append("BAD_OVERLAPS")
	if bad_overlaps.is_empty():
		report_lines.append("none")
	else:
		for overlap in bad_overlaps:
			report_lines.append(overlap)

	await _save_debug_screenshot()

	var file_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write object overlap audit")
		quit(1)
		return
	for line in report_lines:
		file.store_line(line)
		print(line)
	file.close()

	if not bad_overlaps.is_empty():
		push_error("Object overlap audit failed: " + str(bad_overlaps))
		quit(1)
		return

	print("Sushi Shift object overlap audit passed")
	quit(0)


func _collect_objects() -> Array:
	var objects: Array = []
	for object_name in OBJECT_GROUPS.keys():
		var node := _find_world_node(String(object_name))
		if node == null:
			report_lines.append("MISSING " + String(object_name))
			continue
		var aabb := _global_aabb(node)
		if aabb.size == Vector3.ZERO:
			continue
		objects.append({
			"name": String(object_name),
			"group": String(OBJECT_GROUPS[object_name]),
			"node": node,
			"aabb": aabb,
			"rect": Rect2(Vector2(aabb.position.x, aabb.position.z), Vector2(aabb.size.x, aabb.size.z)),
		})
	return objects


func _is_bad_overlap(a: Dictionary, b: Dictionary, ratio: float) -> bool:
	if ratio < MIN_BAD_OVERLAP_AREA:
		return false
	var groups := [String(a["group"]), String(b["group"])]
	if groups.has("appliance") and groups.has("station"):
		return true
	if groups[0] == "appliance" and groups[1] == "appliance":
		return true
	if groups.has("appliance") and groups.has("decor"):
		return true
	if groups.has("appliance") and groups.has("small_prop"):
		return true
	return false


func _find_world_node(name: String) -> Node3D:
	if main.world == null:
		return null
	var matches: Array[Node] = main.world.find_children(name, "Node3D", true, false)
	for node in matches:
		if node.name == name:
			return node as Node3D
	return null


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


func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	return _rect_area(_rect_overlap(a, b))


func _rect_overlap(a: Rect2, b: Rect2) -> Rect2:
	var x1: float = max(a.position.x, b.position.x)
	var y1: float = max(a.position.y, b.position.y)
	var x2: float = min(a.position.x + a.size.x, b.position.x + b.size.x)
	var y2: float = min(a.position.y + a.size.y, b.position.y + b.size.y)
	if x2 <= x1 or y2 <= y1:
		return Rect2()
	return Rect2(Vector2(x1, y1), Vector2(x2 - x1, y2 - y1))


func _rect_area(rect: Rect2) -> float:
	return rect.size.x * rect.size.y


func _add_bad_overlap_marker(rect: Rect2, marker_name: String) -> void:
	if rect.size == Vector2.ZERO or main.world == null:
		return
	var marker := MeshInstance3D.new()
	marker.name = "BadOverlap_" + marker_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x, 0.055, rect.size.y)
	marker.mesh = mesh
	marker.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.08, rect.position.y + rect.size.y * 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.0, 0.62)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.05, 0.02)
	material.emission_energy_multiplier = 0.35
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	marker.material_override = material
	main.world.add_child(marker)


func _save_debug_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		report_lines.append("")
		report_lines.append("DEBUG_SCREENSHOT skipped: headless display")
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		report_lines.append("")
		report_lines.append("DEBUG_SCREENSHOT skipped: no rendered image")
		return
	var screenshot_path := ProjectSettings.globalize_path(DEBUG_SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(screenshot_path.get_base_dir())
	var error := image.save_png(screenshot_path)
	report_lines.append("")
	if error == OK:
		report_lines.append("DEBUG_SCREENSHOT " + screenshot_path)
	else:
		report_lines.append("DEBUG_SCREENSHOT failed error=" + str(error))
