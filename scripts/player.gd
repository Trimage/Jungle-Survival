extends CharacterBody3D
## 플레이어 컨트롤러 (M1~M5)
## - 가상 조이스틱 이동(카메라 기준) + 메시 회전 + 중력 (M1)
## - 행동 버튼: 근처 자원이 있으면 채집, 없으면 근접 공격 (M3/M5)
## - 회피(대시+무적), 피격(넉백+무적), 사망/리스폰 (M5)

## 이동 속도(m/s)
@export var move_speed: float = 5.0
## 회전 보간 속도
@export var turn_speed: float = 12.0
## 카메라 리그의 Y축 회전(요). main.tscn CameraRig 와 일치.
@export var camera_yaw_deg: float = 45.0

@export_group("전투")
## 근접 공격 데미지
@export var attack_damage: float = 12.0
## 공격이 닿는 거리
@export var attack_reach: float = 2.4
## 공격 쿨다운(초)
@export var attack_cooldown: float = 0.5
## 회피 대시 속도
@export var dodge_speed: float = 13.0
## 회피 지속(초)
@export var dodge_time: float = 0.22
## 회피 쿨다운(초)
@export var dodge_cooldown: float = 0.9
## 피격 후 무적 시간(초)
@export var hurt_invuln: float = 0.6

const PlayerArrowScene := preload("res://scenes/player_arrow.tscn")
const ExplosiveScene := preload("res://scenes/explosive.tscn")
const BaitScene := preload("res://scenes/bait.tscn")
const TrapScene := preload("res://scenes/trap.tscn")
const PetScene := preload("res://scenes/pet.tscn")
const MAX_PETS := 3
## 플레이어 캐릭터 모델(.glb). 없으면 기본 캡슐 사용.
const PLAYER_MODEL := "res://assets/models/kaykit/Knight.glb"

signal harvested(node_name: String, yields: Dictionary)
signal player_died
signal player_respawned
signal villager_recruited(count: int)
signal villager_job_changed(job_name: String)
signal request_merchant

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _joystick: Node = null

@onready var _mesh_pivot: Node3D = $MeshPivot
@onready var _inventory: Inventory = $Inventory
@onready var _interact_area: Area3D = $InteractArea
@onready var _stats: Node = $Stats

# 전투/상태
var _attack_cd_timer: float = 0.0
var _dodge_cd_timer: float = 0.0
var _dash_time: float = 0.0          # 대시/넉백 동안 입력 대신 적용
var _dash_vel: Vector3 = Vector3.ZERO
var _invuln_time: float = 0.0
var _last_dir: Vector3 = Vector3(0, 0, 1)
var _dead: bool = false
var _spawn_pos: Vector3 = Vector3.ZERO

# 장비
var _weapon_bonus: float = 0.0
var _equipped_weapon: String = ""
var _weapon_def: Dictionary = {}     # 장착 무기 정의(원거리/탄약 판정용)
var _torch_light: OmniLight3D = null
var _armor_reduction: float = 0.0

# 일시 버프(전투 물약)
var _buff_atk: float = 0.0
var _buff_atk_t: float = 0.0
var _buff_speed: float = 0.0
var _buff_speed_t: float = 0.0
var _shield_t: float = 0.0           # >0 동안 피해 무효(철갑 물약)


var _walk_t: float = 0.0
var _anim: AnimationPlayer = null
var _walk_anim: String = ""


func _ready() -> void:
	_joystick = get_tree().get_first_node_in_group("joystick")
	_spawn_pos = global_position
	_stats.died.connect(_on_stats_died)
	collision_mask = 1 | 16  # 지형(1) + 건물(16) 과 충돌 (벽은 막힘)
	# 카툰 외곽선: 몸통/코 머티리얼에 외곽선 패스 추가
	for part in ["Body", "Nose"]:
		var mi: MeshInstance3D = _mesh_pivot.get_node_or_null(part)
		if mi:
			var m: Material = mi.get_surface_override_material(0)
			if m and m.next_pass == null:
				m.next_pass = LowpolyFactory.make_outline()
	add_child(LowpolyFactory.make_blob_shadow(0.5))  # 발밑 그림자
	_apply_character_model()


## 기본 캡슐 대신 .glb 캐릭터 모델 적용(있으면)
func _apply_character_model() -> void:
	if not ResourceLoader.exists(PLAYER_MODEL):
		return
	for part in ["Body", "Nose"]:
		var mi: Node = _mesh_pivot.get_node_or_null(part)
		if mi:
			mi.visible = false
	var vis: Node3D = LowpolyFactory.build(Vector3(0.8, 1.7, 0.8), Color.WHITE, PLAYER_MODEL, false)
	LowpolyFactory.outline_model(vis)  # 카툰 외곽선(다른 토온 오브젝트와 일관)
	_mesh_pivot.add_child(vis)  # 모델 정면이 +Z라 추가 회전 불필요
	_anim = LowpolyFactory.find_anim_player(vis)
	_walk_anim = LowpolyFactory.pick_locomotion(_anim)


func _physics_process(delta: float) -> void:
	# 타이머 감쇠
	_attack_cd_timer = maxf(0.0, _attack_cd_timer - delta)
	_dodge_cd_timer = maxf(0.0, _dodge_cd_timer - delta)
	_invuln_time = maxf(0.0, _invuln_time - delta)
	# 버프 타이머 감쇠
	if _buff_atk_t > 0.0:
		_buff_atk_t -= delta
		if _buff_atk_t <= 0.0:
			_buff_atk = 0.0
	if _buff_speed_t > 0.0:
		_buff_speed_t -= delta
		if _buff_speed_t <= 0.0:
			_buff_speed = 0.0
	_shield_t = maxf(0.0, _shield_t - delta)
	if _dash_time > 0.0:
		_dash_time -= delta

	# 중력
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	# 사망 상태: 움직임 정지(중력만)
	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if _joystick == null:
		_joystick = get_tree().get_first_node_in_group("joystick")

	# 입력 → 카메라 기준 방향
	var input := Vector2.ZERO
	if _joystick and _joystick.has_method("get_output"):
		input = _joystick.get_output()
	var dir := Vector3.ZERO
	if input.length() > 0.01:
		var yaw := deg_to_rad(camera_yaw_deg)
		var planar := Vector2(input.x, input.y).rotated(-yaw)
		dir = Vector3(planar.x, 0.0, planar.y)
		_last_dir = dir.normalized()

	# 대시/넉백 중이면 그 속도 사용, 아니면 입력 이동
	if _dash_time > 0.0:
		velocity.x = _dash_vel.x
		velocity.z = _dash_vel.z
		_dash_vel = _dash_vel.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	else:
		var spd: float = move_speed + GameState.perk_sum("speed") + _buff_speed
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd

	# 재생 퍽: 체력 자동 회복
	var regen: float = GameState.perk_sum("regen")
	if regen > 0.0:
		_stats.modify("health", regen * delta)

	move_and_slide()

	# 이동 방향으로 메시 회전
	if dir.length() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		_mesh_pivot.rotation.y = lerp_angle(_mesh_pivot.rotation.y, target_yaw, turn_speed * delta)
	# 이동 모션: 모델 애니(있으면 걷기/달리기) 또는 캡슐 폴백 바운스
	if _anim != null:
		LowpolyFactory.update_locomotion(_anim, _walk_anim, Vector2(velocity.x, velocity.z).length())
	elif dir.length() > 0.01:
		_walk_t += delta * 12.0
		_mesh_pivot.position.y = absf(sin(_walk_t)) * 0.08
	else:
		_mesh_pivot.position.y = lerpf(_mesh_pivot.position.y, 0.0, clampf(10.0 * delta, 0.0, 1.0))


## === 행동 버튼: 영입 > 채집 > 공격 ===
func action() -> void:
	if _dead:
		return
	if _try_recruit():
		return
	if _try_open_chest():
		return
	if _try_toggle_gate():
		return
	if _try_talk_merchant():
		return
	if _try_harvest():
		return
	if _try_tame():
		return
	attack()


## 행동 버튼이 지금 수행할 행동 미리보기 라벨(우선순위는 action()과 동일)
func peek_action() -> String:
	if _dead:
		return ""
	var rec := _nearest_recruitable()
	if rec:
		return "영입: " + ItemDB.villager_def(rec.job).get("name", "부락민")
	if _nearest_in_group("chest", 2.8):
		return "상자 열기"
	for b in get_tree().get_nodes_in_group("building"):
		if b.has_method("is_gate") and b.is_gate() and global_position.distance_to(b.global_position) < 2.8:
			return "성문 여닫기"
	if _nearest_in_group("merchant", 3.2):
		return "거래"
	for area in _interact_area.get_overlapping_areas():
		if area.is_in_group("resource_node") and area.has_method("is_available") and area.is_available():
			return "채집"
	if get_tree().get_nodes_in_group("pet").size() < MAX_PETS:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.has_method("is_tameable") and e.is_tameable() and global_position.distance_to(e.global_position) < 2.8:
				return "길들이기"
	return "공격"


func _nearest_recruitable() -> Node:
	var best: Node = null
	var bd: float = INF
	for body in _interact_area.get_overlapping_bodies():
		if body.is_in_group("recruitable"):
			var d: float = global_position.distance_to(body.global_position)
			if d < bd:
				bd = d
				best = body
	return best


func _nearest_in_group(g: String, dist: float) -> Node:
	for n in get_tree().get_nodes_in_group(g):
		if global_position.distance_to(n.global_position) < dist:
			return n
	return null


## 근처 떠돌이 상인과 대화(거래 패널 열기). 성공 시 true.
func _try_talk_merchant() -> bool:
	for m in get_tree().get_nodes_in_group("merchant"):
		if global_position.distance_to(m.global_position) < 3.2:
			request_merchant.emit()
			return true
	return false


## 근처 약해진 맹수를 길들여 동료 펫으로. 성공 시 true.
func _try_tame() -> bool:
	if get_tree().get_nodes_in_group("pet").size() >= MAX_PETS:
		return false
	var best: Node = null
	var best_dist: float = 2.8
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("is_tameable") and e.is_tameable():
			var d: float = global_position.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best = e
	if best == null:
		return false
	var t: String = best.enemy_type
	var pos: Vector3 = best.global_position
	var parent: Node = best.get_parent()
	best.consume_for_tame()
	var pet: Node3D = PetScene.instantiate()
	pet.pet_type = t
	parent.add_child(pet)
	pet.global_position = pos
	AudioManager.play("recruit")
	GameState.spawn_text(pos, "길들임! 🐾", Color(0.4, 0.95, 0.5), 1.3)
	GameState.vibrate(80)
	return true


## 근처 성문 열기/닫기. 성공 시 true.
func _try_toggle_gate() -> bool:
	var best: Node = null
	var best_dist: float = 2.8
	for b in get_tree().get_nodes_in_group("building"):
		if b.has_method("is_gate") and b.is_gate():
			var d: float = global_position.distance_to(b.global_position)
			if d < best_dist:
				best_dist = d
				best = b
	if best:
		AudioManager.play("recruit")
		return best.toggle_gate()
	return false


## 근처 보물 상자 열기 시도. 성공 시 true.
func _try_open_chest() -> bool:
	var best: Node = null
	var best_dist: float = 2.8
	for c in get_tree().get_nodes_in_group("chest"):
		var d: float = global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			best = c
	if best and best.has_method("open"):
		return best.open(_inventory)
	return false


## 근처 떠돌이 생존자 영입 시도. 성공 시 true.
func _try_recruit() -> bool:
	var best: Node = null
	var best_dist: float = INF
	for body in _interact_area.get_overlapping_bodies():
		if body.is_in_group("recruitable") and body.has_method("recruit"):
			var d: float = global_position.distance_to(body.global_position)
			if d < best_dist:
				best_dist = d
				best = body
	if best:
		best.recruit()
		AudioManager.play("recruit")
		GameState.note_recruit()
		villager_recruited.emit(get_tree().get_nodes_in_group("recruited").size())
		return true
	return false


## 영입된 부락민 근처면 직업 순환. 성공 시 true.
func _try_assign_job() -> bool:
	var best: Node = null
	var best_dist: float = INF
	for body in _interact_area.get_overlapping_bodies():
		if body.is_in_group("recruited") and body.has_method("cycle_job"):
			var d: float = global_position.distance_to(body.global_position)
			if d < best_dist:
				best_dist = d
				best = body
	if best:
		var job_name: String = best.cycle_job()
		AudioManager.play("recruit")
		villager_job_changed.emit(job_name)
		return true
	return false


## 근처 자원 채집 시도. 성공 시 true.
func _try_harvest() -> bool:
	var best: Node = null
	var best_dist: float = INF
	for area in _interact_area.get_overlapping_areas():
		if area.is_in_group("resource_node") and area.has_method("is_available") and area.is_available():
			var d: float = global_position.distance_to(area.global_position)
			if d < best_dist:
				best_dist = d
				best = area
	if best:
		var yields: Dictionary = best.harvest(_inventory)
		if not yields.is_empty():
			AudioManager.play("harvest")
			harvested.emit(best.display_name(), yields)
		return true
	return false


## === 근접 공격 ===
func attack() -> void:
	if _dead or _attack_cd_timer > 0.0:
		return
	# 공격속도 퍽: 쿨다운 단축(최대 70%)
	_attack_cd_timer = attack_cooldown * (1.0 - clampf(GameState.perk_sum("atk_speed"), 0.0, 0.7))

	# 원거리 무기 장착 + 탄약 보유 시: 화살 발사
	if _weapon_def.get("ranged", false):
		var ammo: String = _weapon_def.get("ammo", "arrow")
		if _inventory.count_of(ammo) > 0:
			_inventory.remove_item(ammo, 1)
			_fire_arrow()
			AudioManager.play("attack")
			return
		# 탄약 없으면 약한 근접으로 폴백

	_swing()
	GameState.spawn_slash(global_position + get_facing() * 1.0)
	AudioManager.play("attack")
	var fwd := get_facing()
	var is_crit := randf() < _crit_chance()
	var dmg := (attack_damage + _weapon_bonus + GameState.perk_sum("atk") + _buff_atk) * (2.0 if is_crit else 1.0)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.has_method("take_damage"):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() <= attack_reach and fwd.dot(to.normalized()) > 0.25:
			e.take_damage(dmg, global_position, is_crit)
			hit_any = true
	# 적중 후 처리: 치명타 타격감 + 흡혈 퍽
	if hit_any:
		if is_crit:
			GameState.hitstop(0.06)
			GameState.shake(0.28)
			GameState.vibrate(40)
		var ls: float = GameState.perk_sum("lifesteal")
		if ls > 0.0:
			_stats.modify("health", ls)


## 치명타 확률(기본 8% + 예리한 눈 퍽, 최대 75%)
func _crit_chance() -> float:
	return clampf(0.08 + GameState.perk_sum("crit"), 0.0, 0.75)


## 화살 발사: 조준 방향(근처 적 우선)으로 투사체 생성
func _fire_arrow() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dir := _aim_dir()
	var arrow: Node3D = PlayerArrowScene.instantiate()
	var is_crit := randf() < _crit_chance()
	var dmg: float = (float(_weapon_def.get("projectile_damage", 12)) + GameState.perk_sum("atk") + _buff_atk) * (2.0 if is_crit else 1.0)
	arrow.setup(dir, 22.0, dmg, is_crit)
	if is_crit:
		GameState.hitstop(0.05)
		GameState.shake(0.2)
	scene.add_child(arrow)
	arrow.global_position = global_position + Vector3(0, 1.0, 0) + dir * 1.0
	if dir.length() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		_mesh_pivot.rotation.y = target_yaw


## 조준 방향: 사거리 내 최근접 적, 없으면 바라보는 방향
func _aim_dir() -> Vector3:
	var best: Node3D = null
	var best_d: float = 22.0
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		var to: Vector3 = best.global_position - global_position
		to.y = 0.0
		if to.length() > 0.01:
			return to.normalized()
	return get_facing()


## 투척 아이템 사용(폭탄/화염병/미끼). throw_def 의 type 에 따라 동작.
func throw_item(_id: String, throw_def: Dictionary) -> void:
	if _dead:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dir := get_facing()
	var rng: float = float(throw_def.get("range", 6.0))
	var ttype: String = throw_def.get("type", "explosive")
	if ttype == "bait":
		var b: Node3D = BaitScene.instantiate()
		b.setup(float(throw_def.get("hp", 60.0)), float(throw_def.get("duration", 8.0)))
		scene.add_child(b)
		b.global_position = global_position + dir * minf(rng, 4.0)
		AudioManager.play("harvest")
	elif ttype == "trap":
		var tr: Node3D = TrapScene.instantiate()
		tr.setup(throw_def)
		scene.add_child(tr)
		tr.global_position = global_position + dir * rng
		AudioManager.play("harvest")
	else:
		var target := global_position + dir * rng
		var ex: Node3D = ExplosiveScene.instantiate()
		ex.setup(target, float(throw_def.get("damage", 40.0)), float(throw_def.get("radius", 3.0)),
			float(throw_def.get("fire_damage", 0.0)), float(throw_def.get("fire_duration", 0.0)))
		scene.add_child(ex)
		ex.global_position = global_position + Vector3(0, 1.0, 0) + dir * 1.0
		AudioManager.play("attack")


## 전투 물약/토템 버프 적용. buff_def: {stat: atk|speed|shield, amount, duration}
## announce=false 면 연출 생략(토템처럼 매초 갱신할 때).
func apply_buff(buff_def: Dictionary, announce: bool = true) -> void:
	var stat: String = buff_def.get("stat", "")
	var amount: float = float(buff_def.get("amount", 0.0))
	var dur: float = float(buff_def.get("duration", 10.0))
	match stat:
		"atk":
			_buff_atk = amount
			_buff_atk_t = dur
		"speed":
			_buff_speed = amount
			_buff_speed_t = dur
		"shield":
			_shield_t = dur
	if announce:
		GameState.spawn_text(global_position, "버프!", Color(0.6, 0.9, 1.0))
		_hurt_flash()


## 재생 지점 지정(침상 건설 시)
func set_respawn_point(pos: Vector3) -> void:
	_spawn_pos = pos


## 위치 초기화: 시작 지점(또는 침상)으로 복귀. 끼임/길잃음 해소용.
func reset_position() -> void:
	global_position = _spawn_pos
	velocity = Vector3.ZERO
	_dash_time = 0.0
	_dash_vel = Vector3.ZERO


## 공격 스윙 연출(앞으로 살짝 찌르기)
func _swing() -> void:
	var tw := create_tween()
	tw.tween_property(_mesh_pivot, "position:z", 0.35, 0.06)
	tw.tween_property(_mesh_pivot, "position:z", 0.0, 0.12)


## === 회피(대시 + 무적) ===
func dodge() -> void:
	if _dead or _dodge_cd_timer > 0.0:
		return
	# 아드레날린 퍽: 회피 쿨다운 단축(최대 60%)
	_dodge_cd_timer = dodge_cooldown * (1.0 - clampf(GameState.perk_sum("dodge_cd"), 0.0, 0.6))
	_dash_vel = _last_dir * dodge_speed
	_dash_time = dodge_time
	_invuln_time = dodge_time + 0.05


## === 피격 ===
func take_damage(dmg: float, from_pos: Vector3) -> void:
	if _dead or _invuln_time > 0.0:
		return
	# 철갑 물약: 지속시간 동안 피해 무효
	if _shield_t > 0.0:
		GameState.spawn_text(global_position, "무적", Color(0.6, 0.9, 1.0))
		return
	# 방어구 + 두꺼운가죽 퍽 피해 감소(최대 85%)
	var reduction: float = clampf(_armor_reduction + GameState.perk_sum("armor"), 0.0, 0.85)
	var taken: float = dmg * (1.0 - reduction)
	_stats.modify("health", -taken)
	AudioManager.play("player_hurt")
	GameState.spawn_text(global_position, str(int(taken)), Color(1, 0.4, 0.4))
	GameState.shake(0.18)
	GameState.vibrate(60)
	_invuln_time = hurt_invuln
	# 넉백
	var dir := global_position - from_pos
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	_dash_vel = dir.normalized() * 6.0
	_dash_time = 0.15
	_hurt_flash()


func _hurt_flash() -> void:
	var tw := create_tween()
	tw.tween_property(_mesh_pivot, "scale", Vector3(1.2, 0.85, 1.2), 0.06)
	tw.tween_property(_mesh_pivot, "scale", Vector3.ONE, 0.12)


func _on_stats_died() -> void:
	_dead = true
	player_died.emit()


## 사망 후 부활: 위치/스탯 복구
func respawn() -> void:
	global_position = _spawn_pos
	velocity = Vector3.ZERO
	_dash_time = 0.0
	_invuln_time = 0.0
	_stats.revive()
	_dead = false
	player_respawned.emit()


# === 외부 접근 ===
func get_facing() -> Vector3:
	var y: float = _mesh_pivot.rotation.y
	return Vector3(sin(y), 0.0, cos(y))

func get_inventory() -> Inventory:
	return _inventory

func is_dead() -> bool:
	return _dead


## 불러오기 시 사망 상태 해제(스탯은 별도로 복원)
func set_alive() -> void:
	_dead = false


## 새 게임 시작 시 영구 메타 강화를 적용(MetaManager 구매분). 새 게임에서만 1회 호출.
func apply_meta_start() -> void:
	# 기본 능력치 보너스
	attack_damage += MetaManager.meta_sum("atk")
	move_speed += MetaManager.meta_sum("speed")
	var hp_bonus: float = MetaManager.meta_sum("max_hp")
	if hp_bonus > 0.0 and _stats.has_method("set_max_bonus"):
		_stats.set_max_bonus("health", hp_bonus, hp_bonus)  # 상한 ↑ + 그만큼 회복
	# 비축: 시작 자원 지급
	var stock: int = int(MetaManager.meta_sum("stockpile"))
	if stock > 0:
		for res in ["wood", "stone", "fiber", "food"]:
			_inventory.add_item(res, stock)
	# 무기고: 돌칼 지급 + 장착
	if MetaManager.level_of("armory") > 0:
		_inventory.add_item("stone_knife", 1)
		var eq: Dictionary = ItemDB.items.get("stone_knife", {}).get("equip", {})
		if not eq.is_empty():
			equip_item("stone_knife", eq)
	# 유산의 힘: 무작위 퍽 자동 획득
	var lp: int = MetaManager.level_of("legacy")
	for _i in lp:
		var picks: Array = GameState.roll_perk_choices(1)
		if not picks.is_empty():
			GameState.choose_perk(picks[0])


## 소비 아이템 사용: 스탯 효과 적용
func consume_item(_id: String, effects: Dictionary) -> void:
	for key in effects:
		_stats.modify(key, float(effects[key]))
	AudioManager.play("harvest")


## 장비 장착. 안내 문자열 반환.
func equip_item(id: String, equip_def: Dictionary) -> String:
	var slot: String = equip_def.get("slot", "")
	if slot == "weapon":
		_weapon_bonus = float(equip_def.get("attack_bonus", 0))
		_equipped_weapon = id
		_weapon_def = equip_def
		if equip_def.get("ranged", false):
			return "%s 장착 (원거리, 화살 필요)" % ItemDB.item_name(id)
		return "%s 장착 (공격력 +%d)" % [ItemDB.item_name(id), int(_weapon_bonus)]
	elif slot == "light":
		_toggle_torch()
		return "횃불 " + ("켬" if _torch_light else "끔")
	elif slot == "armor":
		_armor_reduction = float(equip_def.get("defense", 0.0))
		return "%s 장착 (피해 -%d%%)" % [ItemDB.item_name(id), int(_armor_reduction * 100)]
	return ""


func _toggle_torch() -> void:
	if _torch_light and is_instance_valid(_torch_light):
		_torch_light.queue_free()
		_torch_light = null
	else:
		_torch_light = OmniLight3D.new()
		_torch_light.position = Vector3(0, 1.4, 0)
		_torch_light.light_color = Color(1.0, 0.8, 0.5)
		_torch_light.light_energy = 2.5
		_torch_light.omni_range = 9.0
		add_child(_torch_light)
