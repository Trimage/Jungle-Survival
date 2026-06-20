extends Node
## 저장/불러오기 (M7, 오토로드 "SaveManager")
## - 게임 상태(시간/플레이어/스탯/인벤토리/건물/부락민)를 user://save.json 으로 저장·복원
## - 적은 저장하지 않음(밤마다 재생성)

const BuildingScene := preload("res://scenes/building.tscn")
const VillagerScene := preload("res://scenes/villager.tscn")

## 슬롯 수(수동 저장). slot<0 은 자동 저장 파일.
const SLOT_COUNT := 3


## 슬롯 경로. slot<0 → 자동저장.
func slot_path(slot: int) -> String:
	if slot < 0:
		return "user://autosave.json"
	return "user://save_%d.json" % slot


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## 가장 최근 저장 슬롯(없으면 -999). 자동저장 포함.
func latest_slot() -> int:
	var best := -999
	var best_t := -1
	for s in range(-1, SLOT_COUNT):
		var p := slot_path(s)
		if FileAccess.file_exists(p):
			var t := int(FileAccess.get_modified_time(p))
			if t > best_t:
				best_t = t
				best = s
	return best


func save_game(slot: int = 0) -> bool:
	var data: Dictionary = {}

	var dn := _group("day_night")
	if dn:
		data["day"] = dn.day
		data["time"] = dn.time_of_day

	var player := _group("player")
	if player:
		var p: Vector3 = player.global_position
		data["player"] = {"x": p.x, "y": p.y, "z": p.z}
		var stats: Node = player.get_node("Stats")
		var sv: Dictionary = {}
		for key in SurvivalStats.STAT_DEFS:
			sv[key] = stats.get_value(key)
		data["stats"] = sv
		data["inventory"] = player.get_inventory().get_slots()

	var blds: Array = []
	for b in get_tree().get_nodes_in_group("building"):
		blds.append({"type": b.build_type, "x": b.global_position.x, "z": b.global_position.z})
	data["buildings"] = blds

	var vils: Array = []
	for v in get_tree().get_nodes_in_group("villager"):
		vils.append({"job": v.job, "recruited": v.recruited, "x": v.global_position.x, "z": v.global_position.z})
	data["villagers"] = vils

	# 성장(레벨/경험치/퍽)
	data["progress"] = GameState.export_progress()

	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true


func load_game(slot: int = 0) -> bool:
	if not has_save(slot):
		return false
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	var world := _world()

	# 시간/날짜
	var dn := _group("day_night")
	if dn and data.has("day"):
		dn.day = int(data["day"])
		dn.time_of_day = float(data["time"])

	# 플레이어 위치/스탯/인벤토리
	var player := _group("player")
	if player and data.has("player"):
		var pp: Dictionary = data["player"]
		player.global_position = Vector3(pp["x"], pp["y"], pp["z"])
		var stats: Node = player.get_node("Stats")
		if data.has("stats"):
			for key in data["stats"]:
				stats.set_value(key, float(data["stats"][key]))
			stats.force_alive()
		if player.has_method("set_alive"):
			player.set_alive()
		if data.has("inventory"):
			player.get_inventory().load_slots(data["inventory"])

	# 건물 재구성
	for b in get_tree().get_nodes_in_group("building"):
		b.queue_free()
	for bd in data.get("buildings", []):
		var b: Node3D = BuildingScene.instantiate()
		b.build_type = bd["type"]
		b.is_ghost = false
		world.add_child(b)
		b.global_position = Vector3(bd["x"], 0.0, bd["z"])

	# 부락민 재구성
	for v in get_tree().get_nodes_in_group("villager"):
		v.queue_free()
	for vd in data.get("villagers", []):
		var v: Node3D = VillagerScene.instantiate()
		v.job = vd["job"]
		v.recruited = bool(vd["recruited"])
		world.add_child(v)
		v.global_position = Vector3(vd["x"], 1.0, vd["z"])

	# 적 제거(밤에 다시 등장)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

	# 성장 복원(최대 체력 퍽이 스탯 상한에 다시 반영됨)
	if data.has("progress"):
		GameState.import_progress(data["progress"])

	return true


func _group(name: String) -> Node:
	return get_tree().get_first_node_in_group(name)


func _world() -> Node:
	var main := get_tree().current_scene
	var w: Node = main.get_node_or_null("World") if main else null
	return w if w else main
