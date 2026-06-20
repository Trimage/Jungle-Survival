extends Node
## 스폰/웨이브 매니저 (M5)
## - 게임 시작 시 낮 배회 적 몇 마리 스폰
## - 낮→밤 전환 시 맵 가장자리에서 웨이브 습격(날짜에 비례해 증가)
## - 적은 플레이어를 추격

## 적이 포함된 웨이브가 시작됨 (마리 수)
signal wave_spawned(count: int)

@export var enemy_scene: PackedScene
## 떠돌이 부락민 씬
@export var villager_scene: PackedScene
## 보스 씬
@export var boss_scene: PackedScene
## 이 날짜(이상) 밤에 보스 등장
@export var boss_day: int = 3
## 낮에 배회하는 기본 적 수
@export var day_wander_count: int = 2
## 시작 시 맵에 배치할 떠돌이 생존자 수
@export var wanderer_count: int = 3
## 밤 웨이브 기본 마리 수(여기에 (날짜-1) 추가)
@export var base_wave: int = 3
## 스폰 반경(맵 가장자리)
@export var spawn_radius: float = 26.0

@export_group("인구")
## 기본 부락민 정원
@export var base_pop_cap: int = 3
## 오두막 1채당 정원 증가
@export var pop_per_hut: int = 2
## 떠돌이 재충원 간격(초)
@export var repop_interval: float = 12.0

## 보스 등장 일정: {날짜: 보스타입}
const BOSS_SCHEDULE := {3: "boa", 5: "thorn_king", 7: "treant"}
const ChestScene := preload("res://scenes/chest.tscn")
const MerchantScene := preload("res://scenes/merchant.tscn")

## 시작 시 맵에 배치할 보물 상자 수
@export var start_chests: int = 3
## 밤마다 보물 상자가 추가로 등장할 확률
@export var night_chest_chance: float = 0.6
## 낮이 시작될 때 떠돌이 상인이 올 확률
@export var merchant_chance: float = 0.5

var _daynight: Node = null
var _connected: bool = false
var _types: Array = []
var _boss_types: Array = []
var _bosses_spawned: Dictionary = {}
var _repop_timer: float = 12.0


## 현재 부락민 정원 = 기본 + 오두막 수 * 채당
func get_pop_cap() -> int:
	return base_pop_cap + _hut_count() * pop_per_hut


func _hut_count() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("building"):
		if b.build_type == "hut":
			n += 1
	return n


func _ready() -> void:
	add_to_group("spawn_manager")
	# 보스(boss=true)는 일반 웨이브 풀에서 제외, 보스는 반복 풀로 수집
	_types = []
	for t in ItemDB.enemies:
		if ItemDB.enemies[t].get("boss", false):
			_boss_types.append(t)
		else:
			_types.append(t)


func _process(delta: float) -> void:
	if not _connected:
		if _daynight == null:
			_daynight = get_tree().get_first_node_in_group("day_night")
			if _daynight:
				_daynight.phase_changed.connect(_on_phase_changed)
				_connected = true
				# 시작 시 낮 배회 적 + 떠돌이 생존자 + 보물 상자
				_spawn_wave(day_wander_count, false)
				_spawn_villagers(wanderer_count)
				for _i in start_chests:
					spawn_chest("common", _spawn_pos(false))
		return
	# 오두막 정원만큼 떠돌이 재충원(부락 성장)
	_repop_timer -= delta
	if _repop_timer <= 0.0:
		_repop_timer = repop_interval
		_try_repopulate()


func _try_repopulate() -> void:
	if villager_scene == null:
		return
	if get_tree().get_nodes_in_group("villager").size() >= get_pop_cap():
		return
	# 오두막이 있으면 그 근처에, 없으면 맵 외곽에 떠돌이 등장
	var huts: Array = []
	for b in get_tree().get_nodes_in_group("building"):
		if b.build_type == "hut":
			huts.append(b)
	var v: Node3D = villager_scene.instantiate()
	v.recruited = false
	v.job = _random_job()
	_get_world().add_child(v)
	if huts.size() > 0:
		var h: Node3D = huts[randi() % huts.size()]
		var ang := randf() * TAU
		v.global_position = h.global_position + Vector3(cos(ang) * 2.5, 1.0, sin(ang) * 2.5)
	else:
		v.global_position = _spawn_pos(false)


func _on_phase_changed(is_night: bool) -> void:
	if is_night:
		var day: int = _daynight.day if _daynight else 1
		var count: int = base_wave + maxi(0, day - 1)
		_spawn_wave(count, true)
		AudioManager.play("night")
		wave_spawned.emit(count)
		_maybe_spawn_boss(day)
		# 밤마다 보물 상자 등장(탐험 보상)
		if randf() < night_chest_chance:
			spawn_chest("common", _spawn_pos(false))
	else:
		# 낮 시작: 떠돌이 상인이 가끔 방문(이미 있으면 생략)
		if get_tree().get_nodes_in_group("merchant").is_empty() and randf() < merchant_chance:
			spawn_merchant()


## 일정에 따라 아직 등장 안 한 보스를 하나 소환(동시에 한 보스만)
func _maybe_spawn_boss(day: int) -> void:
	if boss_scene == null or not get_tree().get_nodes_in_group("boss").is_empty():
		return
	# 1) 예정 보스(각 1회): 3=보아뱀, 5=멧돼지왕, 7=정글왕
	var days: Array = BOSS_SCHEDULE.keys()
	days.sort()
	for d in days:
		var bt: String = BOSS_SCHEDULE[d]
		if day >= d and not _bosses_spawned.has(bt):
			spawn_boss(bt)
			_bosses_spawned[bt] = true
			return
	# 2) 무한 반복: 예정 보스를 모두 본 뒤, 홀수 날(9,11,13...)마다 랜덤 보스(골렘 포함) 재등장
	if day >= 9 and day % 2 == 1 and not _boss_types.is_empty():
		spawn_boss(_boss_types[randi() % _boss_types.size()])


## 보스 소환(맵 가장자리)
func spawn_boss(boss_type: String = "boa") -> void:
	if boss_scene == null:
		return
	var b: Node3D = boss_scene.instantiate()
	b.boss_type = boss_type
	_get_world().add_child(b)
	b.global_position = _spawn_pos(true)
	GameState.report_boss_incoming(ItemDB.enemy_def(boss_type).get("name", "보스"))


## 떠돌이 상인 생성(플레이어가 닿기 쉬운 중간 거리)
func spawn_merchant() -> void:
	var m: Node3D = MerchantScene.instantiate()
	_get_world().add_child(m)
	m.global_position = _spawn_pos(false)
	GameState.spawn_text(m.global_position, "🛒 상인이 도착했다!", Color(1.0, 0.9, 0.5), 1.2)


## 보물 상자 생성(맵 바닥). tier: "common"/"boss"
func spawn_chest(tier: String, pos: Vector3) -> void:
	var c: Node3D = ChestScene.instantiate()
	c.setup(tier)
	_get_world().add_child(c)
	c.global_position = Vector3(pos.x, 0.0, pos.z)


func _spawn_wave(count: int, from_edge: bool) -> void:
	if enemy_scene == null or _types.is_empty():
		return
	for i in count:
		var pos: Vector3 = _spawn_pos(from_edge)
		_spawn_enemy(_types[randi() % _types.size()], pos)


func _spawn_pos(from_edge: bool) -> Vector3:
	var ang := randf() * TAU
	var r: float = spawn_radius if from_edge else randf_range(8.0, 16.0)
	return Vector3(cos(ang) * r, 1.0, sin(ang) * r)


func _spawn_enemy(type: String, pos: Vector3) -> void:
	var e: Node3D = enemy_scene.instantiate()
	e.enemy_type = type
	_get_world().add_child(e)
	e.global_position = pos


func _spawn_villagers(count: int) -> void:
	if villager_scene == null:
		return
	for i in count:
		var v: Node3D = villager_scene.instantiate()
		v.recruited = false
		v.job = _random_job()
		_get_world().add_child(v)
		var ang := randf() * TAU
		var r := randf_range(6.0, 14.0)
		v.global_position = Vector3(cos(ang) * r, 1.0, sin(ang) * r)


## 떠돌이 부락민의 무작위 직업(데이터의 직업 중 하나)
func _random_job() -> String:
	var jobs: Array = ItemDB.villagers.keys()
	if jobs.is_empty():
		return "gatherer"
	return jobs[randi() % jobs.size()]


func _get_world() -> Node:
	var w: Node = get_parent().get_node_or_null("World")
	return w if w else get_parent()
