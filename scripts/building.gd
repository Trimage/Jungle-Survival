extends StaticBody3D
## 건물 (M4 + 거점 방어 확장)
## - 데이터(ItemDB.buildings)로 메시/충돌/조명 구성
## - HP 보유, 적의 공격으로 파괴. 가시 방벽(thorns)은 공격자에게 반사 피해.
## - 모닥불(aura)은 주변 적에게 지속 피해(안전지대). 정비공이 repair() 로 수리.

const TurretArrowScene := preload("res://scenes/player_arrow.tscn")

@export var build_type: String = "campfire"
@export var is_ghost: bool = false

var _def: Dictionary = {}
var _hp: float = 50.0
var _max_hp: float = 50.0
var _thorns: float = 0.0
var _aura: bool = false
var _aura_timer: float = 0.0
var _aura_radius: float = 5.0
var _aura_damage: float = 5.0
var _produce_item: String = ""
var _produce_interval: float = 8.0
var _produce_timer: float = 8.0
var _mat: StandardMaterial3D
var _mesh: Node3D

# 자동 방어/지원 확장
var _turret: bool = false
var _turret_range: float = 13.0
var _turret_damage: float = 12.0
var _turret_cd: float = 1.3
var _turret_timer: float = 0.0
var _buff_aura: bool = false
var _buff_radius: float = 8.0
var _buff_atk: float = 8.0
var _buff_speed: float = 1.0
var _buff_heal: float = 4.0
var _support_timer: float = 0.0
var _heal_aura: bool = false
var _heal_radius: float = 7.0
var _heal_amount: float = 4.0
var _is_gate: bool = false
var _gate_open: bool = false
var _storage_cap: int = 0
var _is_bed: bool = false

const AURA_INTERVAL := 0.5
const SUPPORT_INTERVAL := 1.0


func _ready() -> void:
	_def = ItemDB.building_def(build_type)
	if not is_ghost:
		add_to_group("building")
	_hp = float(_def.get("hp", 50))
	_max_hp = _hp
	_thorns = float(_def.get("thorns", 0))
	_aura = bool(_def.get("aura", false))
	_aura_radius = float(_def.get("aura_radius", 5.0))
	_aura_damage = float(_def.get("aura_damage", 5.0))
	_produce_item = _def.get("produce_item", "")
	_produce_interval = float(_def.get("produce_interval", 8.0))
	_produce_timer = _produce_interval
	# 자동 방어/지원 정의
	_turret = bool(_def.get("turret", false))
	_turret_range = float(_def.get("turret_range", 13.0))
	_turret_damage = float(_def.get("turret_damage", 12.0))
	_turret_cd = float(_def.get("turret_cd", 1.3))
	_buff_aura = bool(_def.get("buff_aura", false))
	_buff_radius = float(_def.get("buff_radius", 8.0))
	_buff_atk = float(_def.get("buff_atk", 8.0))
	_buff_speed = float(_def.get("buff_speed", 1.0))
	_buff_heal = float(_def.get("buff_heal", 4.0))
	_heal_aura = bool(_def.get("heal_aura", false))
	_heal_radius = float(_def.get("heal_radius", 7.0))
	_heal_amount = float(_def.get("heal_amount", 4.0))
	_is_gate = bool(_def.get("gate", false))
	_storage_cap = int(_def.get("storage", 0))
	_is_bed = bool(_def.get("bed", false))
	_build()
	if not is_ghost:
		# 위치는 add_child 이후에 설정되므로(스포너/빌드매니저) 한 프레임 뒤 적용
		_apply_install_effects.call_deferred()


func _build() -> void:
	var size_arr: Array = _def.get("size", [1.0, 1.0, 1.0])
	var sz := Vector3(size_arr[0], size_arr[1], size_arr[2])
	var col := Color.html(_def.get("color", "#888888"))

	_mesh = LowpolyFactory.build(sz, col, _def.get("model", ""), is_ghost, _def.get("shape", "box"))
	add_child(_mesh)
	_mat = LowpolyFactory.last_material

	if is_ghost:
		collision_layer = 0
		collision_mask = 0
	else:
		# 건물 전용 레이어(5번=16). 지형(1)과 분리해 부락민/펫은 통과, 플레이어/적만 막힘
		collision_layer = 16
		collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = sz
		cs.shape = box
		cs.position.y = sz.y * 0.5
		add_child(cs)
		if _def.get("light", false):
			var light := OmniLight3D.new()
			light.position.y = 1.0
			light.light_color = Color(1.0, 0.7, 0.4)
			light.light_energy = float(_def.get("light_energy", 3.0))
			light.omni_range = float(_def.get("light_range", 8.0))
			add_child(light)


## 설치 즉시 효과: 창고(인벤 칸 증가), 침상(재생 지점 지정)
func _apply_install_effects() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if _storage_cap > 0 and p.has_method("get_inventory"):
		var inv: Node = p.get_inventory()
		inv.max_slots += _storage_cap
	if _is_bed and p.has_method("set_respawn_point"):
		p.set_respawn_point(global_position)


func _exit_tree() -> void:
	# 창고 파괴 시 인벤 칸 보너스 회수
	if _storage_cap > 0 and not is_ghost:
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("get_inventory"):
			p.get_inventory().max_slots = maxi(1, p.get_inventory().max_slots - _storage_cap)


func _process(delta: float) -> void:
	if is_ghost:
		return
	# 생산 건물(텃밭/우물/벌목장 등): 일정 간격으로 자원을 부락 인벤토리에 추가
	if _produce_item != "":
		_produce_timer -= delta
		if _produce_timer <= 0.0:
			_produce_timer = _produce_interval
			var p := get_tree().get_first_node_in_group("player")
			if p and p.has_method("get_inventory"):
				p.get_inventory().add_item(_produce_item, 1)

	# 화살탑: 사거리 내 최근접 적에게 자동 사격
	if _turret:
		_turret_timer -= delta
		if _turret_timer <= 0.0:
			_fire_turret()

	# 전쟁 토템 / 의무막사: 주변 아군 지원(버프·치유)
	if _buff_aura or _heal_aura:
		_support_timer -= delta
		if _support_timer <= 0.0:
			_support_timer = SUPPORT_INTERVAL
			_do_support()

	if not _aura:
		return
	# 모닥불 안전지대: 주변 적에게 주기적 피해(불이 맹수를 쫓음)
	_aura_timer -= delta
	if _aura_timer <= 0.0:
		_aura_timer = AURA_INTERVAL
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.is_in_group("boss"):
				continue
			if global_position.distance_to(e.global_position) <= _aura_radius and e.has_method("take_damage"):
				e.take_damage(_aura_damage, global_position)


## 화살탑 발사
func _fire_turret() -> void:
	var best: Node3D = null
	var best_d: float = _turret_range
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	_turret_timer = _turret_cd
	var dir: Vector3 = best.global_position - global_position
	dir.y = 0.0
	var arrow: Node3D = TurretArrowScene.instantiate()
	arrow.setup(dir.normalized(), 24.0, _turret_damage, false)
	get_parent().add_child(arrow)
	arrow.global_position = global_position + Vector3(0, 1.4, 0) + dir.normalized() * 0.8
	AudioManager.play("attack")


## 토템/의무막사: 주변 플레이어 버프 + 아군 치유
func _do_support() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and global_position.distance_to(p.global_position) <= (_buff_radius if _buff_aura else _heal_radius):
		if _buff_aura and p.has_method("apply_buff"):
			# 지속시간을 간격보다 길게 줘 범위 안에 있는 동안 유지(연출 없이 갱신)
			p.apply_buff({"stat": "atk", "amount": _buff_atk, "duration": SUPPORT_INTERVAL + 0.6}, false)
			if _buff_speed > 0.0:
				p.apply_buff({"stat": "speed", "amount": _buff_speed, "duration": SUPPORT_INTERVAL + 0.6}, false)
		if _heal_aura:
			var st: Node = p.get_node_or_null("Stats")
			if st:
				st.modify("health", _heal_amount)
	# 아군(부락민) 치유
	var heal_r: float = _buff_heal if _buff_aura else _heal_amount
	var radius: float = _buff_radius if _buff_aura else _heal_radius
	if heal_r > 0.0:
		for v in get_tree().get_nodes_in_group("recruited"):
			if global_position.distance_to(v.global_position) <= radius and v.has_method("heal"):
				v.heal(heal_r)


## 성문: 열기/닫기 토글(열면 통과 가능). player._try_toggle_gate 가 호출.
func toggle_gate() -> bool:
	if not _is_gate or is_ghost:
		return false
	_gate_open = not _gate_open
	collision_layer = 0 if _gate_open else 16
	# 시각: 열리면 옆으로 슬라이드 + 반투명
	var tw := create_tween()
	if _gate_open:
		tw.tween_property(_mesh, "position:x", _def.get("size", [1.7])[0] * 0.9, 0.25)
	else:
		tw.tween_property(_mesh, "position:x", 0.0, 0.25)
	return true


func is_gate() -> bool:
	return _is_gate


## 적 공격에 피격. attacker 가 있으면 가시 반사 피해.
func take_damage(dmg: float, attacker: Node = null) -> void:
	if is_ghost:
		return
	_hp -= dmg
	_flash()
	if _thorns > 0.0 and attacker and is_instance_valid(attacker) and attacker.has_method("take_damage"):
		attacker.take_damage(_thorns, global_position)
	if _hp <= 0.0:
		queue_free()


## 정비공 수리
func repair(amount: float) -> void:
	_hp = minf(_max_hp, _hp + amount)


func get_health() -> float: return _hp
func get_max_health() -> float: return _max_hp
func needs_repair() -> bool: return _hp < _max_hp


func _flash() -> void:
	if _mat == null:
		return
	var base: Color = _mat.albedo_color
	_mat.albedo_color = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color", base, 0.2)
