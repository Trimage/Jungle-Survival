extends Node
## 건설 매니저 (M4)
## - 건설 모드 진입 시 플레이어 전방에 반투명 고스트를 띄워 위치 미리보기
## - 확정 시 자원 소모 후 실제 건물 설치, 취소 시 고스트 제거
## - 그리드(1m) 스냅으로 배치를 깔끔하게

signal build_mode_changed(active: bool)

## 건물 씬(고스트/실물 공용)
@export var building_scene: PackedScene
## 플레이어로부터 배치 거리
@export var place_distance: float = 3.0

var _active: bool = false
var _build_type: String = ""
var _ghost: Node3D = null

var _player: Node = null
var _inventory: Node = null

# 연속(드래그) 건설: 켜면 플레이어가 지나온 그리드 칸마다 자동 설치
var _continuous: bool = false
var _cur_cell: Vector3 = Vector3.ZERO
var _has_cur_cell: bool = false

# 건물 이동(무료 재배치): 켜면 확정 시 비용 없이 설치, 취소 시 원위치 복구
var _move_mode: bool = false
var _move_orig: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("build_manager")


func _process(_delta: float) -> void:
	if not (_active and _resolve_player()):
		return
	# 플레이어 전방 place_distance 지점, 그리드 스냅(미리보기 고스트)
	if _ghost:
		var pos: Vector3 = _player.global_position + _player.get_facing() * place_distance
		pos.x = roundf(pos.x)
		pos.z = roundf(pos.z)
		pos.y = 0.0
		_ghost.global_position = pos

	# 연속 모드: 플레이어가 새 칸으로 이동하면 직전(방금 떠난) 칸에 자동 설치
	if _continuous:
		var cell := Vector3(roundf(_player.global_position.x), 0.0, roundf(_player.global_position.z))
		if not _has_cur_cell:
			_cur_cell = cell
			_has_cur_cell = true
		elif cell != _cur_cell:
			if not _cell_occupied(_cur_cell):
				_place_building(_cur_cell)  # 자원 부족이면 조용히 건너뜀
			_cur_cell = cell


func is_active() -> bool:
	return _active


## 특정 건물 건설 모드 시작
func start_build(build_type: String) -> void:
	if _active:
		cancel()
	if not _resolve_player() or building_scene == null:
		return
	_build_type = build_type
	_continuous = false
	_has_cur_cell = false
	_ghost = building_scene.instantiate()
	_ghost.build_type = build_type
	_ghost.is_ghost = true
	_get_world().add_child(_ghost)
	_active = true
	build_mode_changed.emit(true)


## 연속(드래그) 건설 모드 토글. 켜면 현재 칸을 시작점으로 기록.
func set_continuous(on: bool) -> void:
	_continuous = on
	_has_cur_cell = false
	if on and _resolve_player():
		_cur_cell = Vector3(roundf(_player.global_position.x), 0.0, roundf(_player.global_position.z))
		_has_cur_cell = true


## 지정 위치에 건물 설치. free=true 면 자원 소모/건설 집계 없이 설치(이동용).
func _place_building(pos: Vector3, free: bool = false) -> bool:
	var def: Dictionary = ItemDB.building_def(_build_type)
	var cost: Dictionary = def.get("cost", {})
	if not free:
		if not _inventory.can_afford(cost):
			return false
		_inventory.spend(cost)
	var b: Node3D = building_scene.instantiate()
	b.build_type = _build_type
	b.is_ghost = false
	_get_world().add_child(b)
	b.global_position = pos
	AudioManager.play("build")
	if not free:
		GameState.note_build()
	return true


## 플레이어 근처(3.5m) 최근접 건물
func _nearest_building() -> Node:
	if not _resolve_player():
		return null
	var best: Node = null
	var best_d: float = 3.5
	for b in get_tree().get_nodes_in_group("building"):
		var d: float = _player.global_position.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	return best


## 근처 건물을 집어 이동 모드 시작(무료 재배치). 근처에 없으면 false.
func start_move() -> bool:
	if not _resolve_player():
		return false
	var b := _nearest_building()
	if b == null:
		return false
	if _active:
		cancel()
	_build_type = b.build_type
	_move_orig = b.global_position
	_move_mode = true
	_continuous = false
	_has_cur_cell = false
	b.queue_free()
	_ghost = building_scene.instantiate()
	_ghost.build_type = _build_type
	_ghost.is_ghost = true
	_get_world().add_child(_ghost)
	_active = true
	build_mode_changed.emit(true)
	return true


## 근처 건물 회수: 제거하고 자원 전액 환급. 근처에 없으면 false.
func store_building() -> bool:
	if _active or not _resolve_player():
		return false
	var b := _nearest_building()
	if b == null:
		return false
	var cost: Dictionary = ItemDB.building_def(b.build_type).get("cost", {})
	for id in cost:
		_inventory.add_item(id, int(cost[id]))
	b.queue_free()
	AudioManager.play("build")
	return true


## 그리드 칸에 이미 건물이 있는지(중복 설치 방지)
func _cell_occupied(pos: Vector3) -> bool:
	for b in get_tree().get_nodes_in_group("building"):
		if absf(b.global_position.x - pos.x) < 0.5 and absf(b.global_position.z - pos.z) < 0.5:
			return true
	return false


## 배치 확정(단일). 자원 부족이면 false 반환(설치 안 함).
func confirm() -> bool:
	if not _active or _ghost == null:
		return false
	# 이동 모드: 비용 없이 새 위치에 설치
	if _move_mode:
		_place_building(_ghost.global_position, true)
		_end()
		return true
	var ok: bool = _place_building(_ghost.global_position)
	# 연속 모드가 아니면 한 번 설치 후 종료
	if ok and not _continuous:
		_end()
	return ok


func cancel() -> void:
	# 이동 모드 취소: 원위치로 되돌림(무료)
	if _move_mode:
		_place_building(_move_orig, true)
	_end()


func _end() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_active = false
	_continuous = false
	_has_cur_cell = false
	_move_mode = false
	build_mode_changed.emit(false)


func _resolve_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player:
			_inventory = get_tree().get_first_node_in_group("inventory")
	return _player != null and _inventory != null


## 설치 건물의 부모(World). 없으면 Main 자신.
func _get_world() -> Node:
	var w: Node = get_parent().get_node_or_null("World")
	return w if w else get_parent()
