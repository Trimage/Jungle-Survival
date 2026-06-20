extends CharacterBody3D
## 부락민 NPC (M6 + 직업 확장)
## - 영입 전: 회색 배회(recruitable). 플레이어가 행동으로 recruit() → 직업색, 자동 임무.
## - 직업(데이터 주도):
##     채집꾼(gatherer): 아무 노드나 자동 채집 → 공유 인벤토리
##     정비공(mechanic): 고철/발굴 노드 우선 채집(빠른 간격)
##     사냥꾼(hunter):  주변 적을 추격·공격(거점 방어)
## - 영입된 부락민에게 다시 행동 → cycle_job() 으로 직업 순환

enum State { WANDER, MOVE_TO_NODE, GATHER, HUNT }

const JOBS := ["gatherer", "hunter", "mechanic", "herbalist", "cook", "miner"]

@export var job: String = "gatherer"
@export var recruited: bool = false

var _def: Dictionary = {}
var _speed: float = 3.0
var _gather_interval: float = 1.5
# 사냥꾼 전투 스탯
var _atk_damage: float = 8.0
var _atk_range: float = 2.0
var _atk_cd: float = 0.8
var _detect: float = 14.0
var _atk_timer: float = 0.0
# 약초사/요리사
var _heal: float = 6.0
var _heal_range: float = 6.0
var _heal_interval: float = 2.0
var _heal_timer: float = 0.0
var _cook_interval: float = 3.0
var _cook_timer: float = 0.0

var _state: int = State.WANDER
var _player: Node3D = null
var _inventory: Node = null
var _target_node: Node = null
var _gather_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0

var _pivot: Node3D
var _mat: StandardMaterial3D
var _anim: AnimationPlayer = null
var _walk_anim: String = ""
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _hp: float = 40.0
var _max_hp: float = 40.0
var _dead: bool = false
var _hpbar_bg: MeshInstance3D
var _hpbar_fill: MeshInstance3D

const WANDER_COLOR := Color(0.7, 0.7, 0.72)


func _ready() -> void:
	add_to_group("villager")
	_load_job_stats()
	_max_hp = float(_def.get("hp", 40))
	_hp = _max_hp
	_build_visual()
	collision_layer = 8
	collision_mask = 1
	_player = get_tree().get_first_node_in_group("player")
	if recruited:
		_become_recruited()
	else:
		add_to_group("recruitable")
	_pick_wander_target()


func _load_job_stats() -> void:
	_def = ItemDB.villager_def(job)
	_speed = float(_def.get("speed", 3.0))
	_gather_interval = float(_def.get("gather_interval", 1.5))
	_atk_damage = float(_def.get("attack_damage", 8.0))
	_atk_range = float(_def.get("attack_range", 2.0))
	_atk_cd = float(_def.get("attack_cd", 0.8))
	_detect = float(_def.get("detect_range", 14.0))
	_heal = float(_def.get("heal", 6.0))
	_heal_range = float(_def.get("heal_range", 6.0))
	_heal_interval = float(_def.get("heal_interval", 2.0))
	_cook_interval = float(_def.get("cook_interval", 3.0))


func _build_visual() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	var model_path: String = _def.get("model", "")
	if model_path != "" and ResourceLoader.exists(model_path):
		# 외부 .glb 모델 사용(슬롯 크기에 자동 맞춤). _mat 없음 → 직업 색/플래시는 생략.
		var vis: Node3D = LowpolyFactory.build(Vector3(0.8, 1.6, 0.8), WANDER_COLOR, model_path, false)
		_pivot.add_child(vis)  # 모델 정면이 +Z라 추가 회전 불필요
		_mat = null
		_anim = LowpolyFactory.find_anim_player(vis)
		_walk_anim = LowpolyFactory.pick_locomotion(_anim)
	else:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.5
		body.mesh = cap
		body.position.y = 0.75
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = WANDER_COLOR
		_mat.roughness = 1.0
		LowpolyFactory.apply_outline(_mat)
		body.material_override = _mat
		_pivot.add_child(body)

		var nose := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 0.2, 0.25)
		nose.mesh = bm
		nose.position = Vector3(0, 0.9, 0.4)
		var nose_mat := StandardMaterial3D.new()
		nose_mat.albedo_color = Color(0.95, 0.85, 0.4)
		LowpolyFactory.apply_outline(nose_mat)
		nose.material_override = nose_mat
		_pivot.add_child(nose)

	add_child(LowpolyFactory.make_blob_shadow(0.45))  # 발밑 그림자

	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.5
	cs.shape = shape
	cs.position.y = 0.75
	add_child(cs)

	# 머리 위 소형 체력바(피해 입었을 때만 표시)
	_hpbar_bg = _make_bar(Color(0.1, 0.1, 0.12))
	add_child(_hpbar_bg)
	_hpbar_fill = _make_bar(Color(0.45, 0.85, 0.4))
	add_child(_hpbar_fill)
	_hpbar_bg.visible = false
	_hpbar_fill.visible = false


func _make_bar(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.09, 0.02)
	mi.mesh = bm
	mi.position = Vector3(0, 1.85, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mi.material_override = mat
	return mi


func _update_hpbar() -> void:
	var ratio: float = clampf(_hp / _max_hp, 0.0, 1.0)
	var show_bar: bool = ratio < 0.999 and not _dead
	_hpbar_bg.visible = show_bar
	_hpbar_fill.visible = show_bar
	if show_bar:
		_hpbar_fill.scale.x = ratio
		_hpbar_fill.position.x = -0.3 * (1.0 - ratio)


func recruit() -> void:
	if recruited:
		return
	recruited = true
	remove_from_group("recruitable")
	_become_recruited()


func _become_recruited() -> void:
	add_to_group("recruited")
	_apply_job_color()
	if _player and _player.has_method("get_inventory"):
		_inventory = _player.get_inventory()
	_target_node = null


func _apply_job_color() -> void:
	if _mat:
		_mat.albedo_color = Color.html(_def.get("color", "#3aa0b0"))


## 영입된 부락민의 직업 순환(플레이어가 다시 행동 시)
func cycle_job() -> String:
	var idx: int = JOBS.find(job)
	job = JOBS[(idx + 1) % JOBS.size()]
	_load_job_stats()
	_max_hp = float(_def.get("hp", 40))
	_hp = minf(_hp, _max_hp)
	_apply_job_color()
	_target_node = null
	return _def.get("name", job)


## 적 공격에 피격
func take_damage(dmg: float, _from_pos: Vector3) -> void:
	if _dead:
		return
	_hp -= dmg
	_flash()
	GameState.spawn_text(global_position, str(int(dmg)), Color(1, 0.55, 0.55))
	if _hp <= 0.0:
		_die()


## 치유(토템/의무막사). 최대치까지 회복.
func heal(amount: float) -> void:
	if _dead:
		return
	_hp = minf(_max_hp, _hp + amount)
	_update_hpbar()


func _flash() -> void:
	if _mat == null:
		return
	var base: Color = _mat.albedo_color
	_mat.albedo_color = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color", base, 0.25)


func _die() -> void:
	_dead = true
	remove_from_group("villager")
	remove_from_group("recruited")
	remove_from_group("recruitable")
	GameState.spawn_puff(global_position, _mat.albedo_color if _mat else WANDER_COLOR)
	GameState.report_villager_died(get_job_name())
	queue_free()


func get_job_name() -> String:
	return _def.get("name", job)


func is_recruited() -> bool:
	return recruited


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_atk_timer = maxf(0.0, _atk_timer - delta)
	_update_hpbar()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var move_dir := Vector3.ZERO
	if not recruited:
		move_dir = _do_wander(delta)
	elif GameState.rally_active:
		move_dir = _do_rally(delta)
	elif job == "hunter":
		move_dir = _do_hunt(delta)
	elif job == "mechanic":
		move_dir = _do_mechanic(delta)
	elif job == "herbalist":
		move_dir = _do_herbalist(delta)
	elif job == "cook":
		move_dir = _do_cook(delta)
	else:
		move_dir = _do_gather(delta)

	velocity.x = move_dir.x * _speed
	velocity.z = move_dir.z * _speed
	move_and_slide()

	if move_dir.length() > 0.05:
		var target_yaw := atan2(move_dir.x, move_dir.z)
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, target_yaw, 0.25)
	LowpolyFactory.update_locomotion(_anim, _walk_anim, Vector2(velocity.x, velocity.z).length())


func _do_wander(delta: float) -> Vector3:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 1.0:
		_pick_wander_target()
	var d := _wander_target - global_position
	d.y = 0.0
	return d.normalized() * 0.5


## 채집꾼/정비공/약초사: 노드로 이동 후 간격마다 채집(직업별 선호 노드)
func _do_gather(delta: float) -> Vector3:
	if _target_node == null or not is_instance_valid(_target_node) or not _target_node.is_available():
		_target_node = _find_nearest_node(_def.get("prefer", []))
	if _target_node == null:
		return _do_wander(delta)

	var to: Vector3 = _target_node.global_position - global_position
	to.y = 0.0
	if to.length() > 1.8:
		return to.normalized()
	else:
		_gather_timer -= delta
		if _gather_timer <= 0.0:
			_gather_timer = _gather_interval
			if _inventory:
				_target_node.harvest(_inventory)
		return Vector3.ZERO


## 사냥꾼: 가장 가까운 적을 추격·공격, 없으면 배회
func _do_hunt(delta: float) -> Vector3:
	var target: Node3D = _find_nearest_enemy()
	if target == null:
		return _do_wander(delta)
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	if to.length() > _atk_range:
		return to.normalized()
	else:
		if _atk_timer <= 0.0 and target.has_method("take_damage"):
			target.take_damage(_atk_damage * (1.0 + GameState.perk_sum("villager_dmg")), global_position)
			_atk_timer = _atk_cd
			AudioManager.play("attack")
		return Vector3.ZERO


## prefer 가 비어있으면 아무 노드나, 있으면 해당 타입 우선(없으면 아무거나 폴백)
func _find_nearest_node(prefer: Array) -> Node:
	var best: Node = null
	var best_d: float = INF
	for n in get_tree().get_nodes_in_group("resource_node"):
		if not (n.has_method("is_available") and n.is_available()):
			continue
		if prefer.size() > 0 and not (n.node_type in prefer):
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best == null and prefer.size() > 0:
		return _find_nearest_node([])
	return best


## 약초사(의무병): 플레이어를 따라다니며 지속 치유
func _do_herbalist(delta: float) -> Vector3:
	var p: Node3D = get_tree().get_first_node_in_group("player")
	if p == null:
		return _do_wander(delta)
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var d: float = to.length()
	_heal_timer -= delta
	if _heal_timer <= 0.0 and d <= _heal_range:
		_heal_timer = _heal_interval
		var st: Node = p.get_node_or_null("Stats")
		if st:
			st.modify("health", _heal)
	# 치유 범위를 유지하도록 플레이어를 따라다님
	if d > 3.0:
		return to.normalized()
	return Vector3.ZERO


## 요리사: 공유 인벤토리의 식량을 구운식량으로 가공
func _do_cook(delta: float) -> Vector3:
	_cook_timer -= delta
	if _cook_timer <= 0.0 and _inventory:
		_cook_timer = _cook_interval
		if _inventory.count_of("food") > 0:
			_inventory.remove_item("food", 1)
			_inventory.add_item("cooked_food", 1)
	return _do_wander(delta)


## 집결: 플레이어 주위로 모여 방어(사냥꾼은 근처 적 공격)
func _do_rally(delta: float) -> Vector3:
	var p: Node3D = get_tree().get_first_node_in_group("player")
	if p == null:
		return _do_wander(delta)
	if job == "hunter":
		var e: Node3D = _find_nearest_enemy()
		if e and global_position.distance_to(e.global_position) <= _atk_range:
			if _atk_timer <= 0.0 and e.has_method("take_damage"):
				e.take_damage(_atk_damage * (1.0 + GameState.perk_sum("villager_dmg")), global_position)
				_atk_timer = _atk_cd
				AudioManager.play("attack")
			return Vector3.ZERO
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	if to.length() > 2.5:
		return to.normalized()
	return Vector3.ZERO


## 정비공: 손상된 건물 수리 우선, 없으면 고철 채집
func _do_mechanic(delta: float) -> Vector3:
	var b: Node = _find_damaged_building()
	if b == null:
		return _do_gather(delta)
	var to: Vector3 = b.global_position - global_position
	to.y = 0.0
	if to.length() > 2.2:
		return to.normalized()
	else:
		_gather_timer -= delta
		if _gather_timer <= 0.0:
			_gather_timer = _gather_interval
			b.repair(10.0)
		return Vector3.ZERO


func _find_damaged_building() -> Node:
	var best: Node = null
	var best_d: float = INF
	for b in get_tree().get_nodes_in_group("building"):
		if b.has_method("needs_repair") and b.needs_repair():
			var d: float = global_position.distance_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
	return best


func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d: float = _detect
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _pick_wander_target() -> void:
	_wander_timer = randf_range(2.0, 4.0)
	var ang := randf() * TAU
	var r := randf_range(3.0, 8.0)
	_wander_target = global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
