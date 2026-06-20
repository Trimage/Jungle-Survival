extends CharacterBody3D
## 맹수 적 (M5)
## - 데이터(ItemDB.enemies)로 능력치/외형 구성
## - AI: 배회(WANDER) → 감지 시 추격(CHASE) → 사거리 내 공격(ATTACK)
## - 피격 시 넉백+플래시, hp 0 시 사망. 넉백은 _knock_time 동안 대시 속도 유지.

enum State { WANDER, CHASE, ATTACK, DEAD }

const ProjectileScene := preload("res://scenes/projectile.tscn")

## 적 종류(데이터 키). 인스턴스 전에 지정.
@export var enemy_type: String = "boar"

var _def: Dictionary = {}
var _hp: float = 10.0
var _max_hp: float = 10.0
var _tame_hinted: bool = false
var _speed: float = 3.0
var _damage: float = 5.0
var _attack_range: float = 1.8
var _detect_range: float = 12.0
var _attack_cd: float = 1.0
var _knockback: float = 3.0
var _ranged: bool = false
var _proj_speed: float = 12.0
var _windup: float = 0.0
const WINDUP_TIME := 0.3

var _state: int = State.WANDER
var _player: Node3D = null
var _attack_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _knock_time: float = 0.0
var _knock_vel: Vector3 = Vector3.ZERO
var _slow_factor: float = 1.0   # 마름쇠 등 감속(1=정상)
var _slow_time: float = 0.0


## 감속 적용(마름쇠 함정 등)
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = clampf(factor, 0.1, 1.0)
	_slow_time = maxf(_slow_time, duration)

var _mesh: Node3D
var _mat: StandardMaterial3D
var _base_color: Color = Color.WHITE
var _anim: AnimationPlayer = null
var _walk_anim: String = ""
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("enemy")
	_def = ItemDB.enemy_def(enemy_type)
	_hp = float(_def.get("hp", 10))
	_speed = float(_def.get("speed", 3.0))
	_damage = float(_def.get("damage", 5))
	_attack_range = float(_def.get("attack_range", 1.8))
	_detect_range = float(_def.get("detect_range", 12.0))
	_attack_cd = float(_def.get("attack_cd", 1.0))
	_knockback = float(_def.get("knockback", 3.0))
	_ranged = bool(_def.get("ranged", false))
	_proj_speed = float(_def.get("projectile_speed", 12.0))
	# 난이도 곡선: 날짜가 갈수록 체력·공격력 상승(최대 ~2배)
	var dn := get_tree().get_first_node_in_group("day_night")
	var day: int = dn.day if dn else 1
	var scale: float = 1.0 + mini(day - 1, 9) * 0.12
	_hp *= scale
	_damage *= scale
	_max_hp = _hp
	_build_visual()
	_player = get_tree().get_first_node_in_group("player")
	_pick_wander_target()


func _build_visual() -> void:
	var size_arr: Array = _def.get("size", [1.0, 1.0, 1.0])
	var sz := Vector3(size_arr[0], size_arr[1], size_arr[2])
	_base_color = Color.html(_def.get("color", "#888888"))

	# model(.glb) 경로가 있으면 외부 모델, 없으면 기본 박스
	var model_path: String = _def.get("model", "")
	var built: Node3D = LowpolyFactory.build(sz, _base_color, model_path, false, _def.get("shape", "box"))
	_mat = LowpolyFactory.last_material  # 본체 머티리얼(모델이면 null)
	if model_path != "" and ResourceLoader.exists(model_path):
		# 모델을 래퍼로 감싸 _face 회전과 분리(모델 정면 +Z, 추가 회전 불필요)
		var wrapper := Node3D.new()
		wrapper.add_child(built)
		_mesh = wrapper
	else:
		_mesh = built
	add_child(_mesh)
	add_child(LowpolyFactory.make_blob_shadow(maxf(sz.x, sz.z) * 0.55))  # 발밑 그림자
	_anim = LowpolyFactory.find_anim_player(built)
	_walk_anim = LowpolyFactory.pick_locomotion(_anim)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	cs.shape = box
	cs.position.y = sz.y * 0.5
	add_child(cs)

	# 적=레이어4, 지형/건물(레이어1)과만 충돌
	collision_layer = 4
	collision_mask = 1


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	# 감속 타이머 감쇠
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
	LowpolyFactory.update_locomotion(_anim, _walk_anim, Vector2(velocity.x, velocity.z).length())

	# 중력
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(0.0, velocity.y)

	if _state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# 넉백 중에는 대시 속도 유지(점차 감쇠)
	if _knock_time > 0.0:
		_knock_time -= delta
		velocity.x = _knock_vel.x
		velocity.z = _knock_vel.z
		_knock_vel = _knock_vel.lerp(Vector3.ZERO, clampf(8.0 * delta, 0.0, 1.0))
		move_and_slide()
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# 표적: 플레이어와 건물 중 가장 가까운 것(거점 공성)
	var target := _get_target()
	var to_target := Vector3.ZERO
	var dist := INF
	if target:
		to_target = target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()

	# 상태 전이
	if dist <= _attack_range:
		_state = State.ATTACK
	elif dist <= _detect_range:
		_state = State.CHASE
	else:
		_state = State.WANDER
	if _state != State.ATTACK and _windup > 0.0:
		_windup = 0.0
		if _mesh:
			_mesh.scale = Vector3.ONE

	var move_dir := Vector3.ZERO
	if _ranged:
		move_dir = _ranged_behavior(delta, target, to_target, dist)
	else:
		match _state:
			State.WANDER:
				move_dir = _wander_step(delta)
			State.CHASE:
				move_dir = to_target.normalized()
			State.ATTACK:
				move_dir = Vector3.ZERO
				_face(to_target)
				if _windup > 0.0:
					_windup -= delta
					if _windup <= 0.0:
						_mesh.scale = Vector3.ONE
						if target and target.has_method("take_damage"):
							if target.is_in_group("building"):
								target.take_damage(_damage, self)
							else:
								target.take_damage(_damage, global_position)
				elif _attack_timer <= 0.0:
					_windup = WINDUP_TIME
					_attack_timer = _attack_cd
					var s := create_tween()
					s.tween_property(_mesh, "scale", Vector3(1.25, 1.25, 1.25), WINDUP_TIME * 0.8)

	velocity.x = move_dir.x * _speed * _slow_factor
	velocity.z = move_dir.z * _speed * _slow_factor
	move_and_slide()

	if move_dir.length() > 0.05:
		_face(move_dir)


## 원거리 적: 사거리를 유지하며 플레이어에게 투사체 발사
func _ranged_behavior(delta: float, target: Node3D, to_target: Vector3, dist: float) -> Vector3:
	if target == null or dist > _detect_range:
		return _wander_step(delta)
	_face(to_target)
	# 사격 (플레이어만 표적)
	if dist <= _attack_range and _attack_timer <= 0.0 and target.is_in_group("player"):
		_shoot(to_target.normalized())
		_attack_timer = _attack_cd
	# 거리 유지: 너무 가까우면 후퇴, 너무 멀면 접근
	var ideal := _attack_range * 0.6
	if dist < ideal - 1.0:
		return -to_target.normalized()
	elif dist > _attack_range:
		return to_target.normalized()
	return Vector3.ZERO


func _shoot(dir: Vector3) -> void:
	var p: Node3D = ProjectileScene.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 1.0, 0) + dir * 1.0
	if p.has_method("setup"):
		p.setup(dir, _proj_speed, _damage)
	AudioManager.play("attack")


func _wander_step(delta: float) -> Vector3:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 1.0:
		_pick_wander_target()
	var d := _wander_target - global_position
	d.y = 0.0
	return d.normalized() * 0.5


## 플레이어와 건물 중 가장 가까운 표적
func _get_target() -> Node3D:
	# 미끼 최우선: 사거리(detect×1.6) 내 가장 가까운 미끼로 유인
	var best_bait: Node3D = null
	var bait_d: float = _detect_range * 1.6
	for b in get_tree().get_nodes_in_group("bait"):
		var db: float = global_position.distance_to(b.global_position)
		if db < bait_d:
			bait_d = db
			best_bait = b
	if best_bait:
		return best_bait

	var best: Node3D = null
	var best_d: float = INF
	if _player and is_instance_valid(_player):
		best = _player
		best_d = global_position.distance_to(_player.global_position)
	for b in get_tree().get_nodes_in_group("building"):
		var d: float = global_position.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	# 영입된 부락민도 공격 대상(거점 방어 긴장감)
	for v in get_tree().get_nodes_in_group("recruited"):
		var dv: float = global_position.distance_to(v.global_position)
		if dv < best_d:
			best_d = dv
			best = v
	# 동료 펫도 공격 대상
	for pet in get_tree().get_nodes_in_group("pet"):
		var dp: float = global_position.distance_to(pet.global_position)
		if dp < best_d:
			best_d = dp
			best = pet
	return best


## 길들이기 가능 여부(보스 제외, 체력 30% 이하)
func is_tameable() -> bool:
	return _state != State.DEAD and not is_in_group("boss") and _hp <= _max_hp * 0.3


## 길들이기로 소멸(드롭/경험치/콤보 없음 — 펫으로 전환됨)
func consume_for_tame() -> void:
	_state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	queue_free()


func _pick_wander_target() -> void:
	_wander_timer = randf_range(2.0, 4.0)
	var ang := randf() * TAU
	var r := randf_range(3.0, 8.0)
	_wander_target = global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)


func _face(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(dir.x, dir.z)
	_mesh.rotation.y = lerp_angle(_mesh.rotation.y, target_yaw, 0.3)


## 플레이어 공격에 피격
func take_damage(dmg: float, from_pos: Vector3, crit: bool = false) -> void:
	if _state == State.DEAD:
		return
	_hp -= dmg
	_flash()
	AudioManager.play("hit")
	if crit:
		GameState.spawn_text(global_position, "%d!" % int(dmg), Color(1.0, 0.85, 0.2), 1.7)
	else:
		GameState.spawn_text(global_position, str(int(dmg)), Color(1, 1, 1))
	# 체력이 낮아져 길들이기 가능해지면 1회 안내
	if not _tame_hinted and is_tameable():
		_tame_hinted = true
		GameState.spawn_text(global_position, "💗 길들이기 가능", Color(0.4, 0.95, 0.5))
	# 넉백: 가해자 반대 방향
	var dir := global_position - from_pos
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	_knock_vel = dir.normalized() * _knockback
	_knock_time = 0.18
	if _hp <= 0.0:
		_die()


func _flash() -> void:
	if _mat == null:
		return
	_mat.albedo_color = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color", _base_color, 0.25)


func _die() -> void:
	_state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	GameState.note_kill()
	# 경험치: 데이터에 xp 가 없으면 체력 기반으로 추정 + 콤보 배수
	var base_xp: float = float(_def.get("xp", maxi(2, int(float(_def.get("hp", 10)) / 6.0))))
	GameState.add_xp(base_xp * GameState.combo_xp_mult())
	GameState.spawn_drops(global_position, _def.get("drops", {}))
	GameState.spawn_puff(global_position, _base_color)
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1, 0.05, 1), 0.25)
	tw.tween_callback(queue_free)
