extends CharacterBody3D
## 보스: 거대 보아뱀 (M7 + 패턴 확장) — 패턴형
## - 접근(APPROACH) → 텔레그래프(예비동작) → 거리별 공격:
##     원거리 독액(SPIT) / 중거리 돌진(LUNGE) / 근거리 꼬리치기(SWEEP)
## - 일정 간격 졸개(뱀) 소환, 체력 40% 이하에서 광폭화(속도·공격력↑)
## - 그룹 "enemy"(플레이어 공격 대상) + "boss"(HUD 체력바, 그룹 폴링)

enum State { APPROACH, TELEGRAPH, LUNGE, SWEEP, SPIT, DEAD }

const ProjectileScene := preload("res://scenes/projectile.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")

@export var boss_type: String = "boa"

var _def: Dictionary = {}
var _name: String = "보스"
var _hp: float = 200.0
var _max_hp: float = 200.0
var _speed: float = 3.0
var _damage: float = 18.0
var _attack_range: float = 3.0
var _knockback: float = 6.0

var _state: int = State.APPROACH
var _player: Node3D = null
var _attack_cd: float = 0.0
var _tele_timer: float = 0.0
var _lunge_dir: Vector3 = Vector3.ZERO
var _lunge_time: float = 0.0
var _recover: float = 0.0
var _pending: String = "lunge"
var _hit_done: bool = false
var _summon_cd: float = 8.0
var _enraged: bool = false
var _summon_type: String = "snake"
var _can_spit: bool = true
var _final: bool = false
var _indicator: Node3D = null     # 공격 예고 바닥 마커

var _pivot: Node3D
var _mat: StandardMaterial3D
var _anim: AnimationPlayer = null
var _walk_anim: String = ""
var _base_color: Color = Color.WHITE
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@export var attack_cooldown: float = 2.2
@export var telegraph_time: float = 0.7
@export var lunge_duration: float = 0.45
@export var lunge_speed_mult: float = 3.5
@export var sweep_radius: float = 4.5
@export var summon_interval: float = 12.0
@export var enrage_ratio: float = 0.5


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_def = ItemDB.enemy_def(boss_type)
	_name = _def.get("name", "보스")
	_hp = float(_def.get("hp", 200))
	_max_hp = _hp
	_speed = float(_def.get("speed", 3.0))
	_damage = float(_def.get("damage", 18))
	_attack_range = float(_def.get("attack_range", 3.0))
	_knockback = float(_def.get("knockback", 6.0))
	attack_cooldown = float(_def.get("attack_cd", 2.2))
	_summon_type = _def.get("summon_type", "snake")
	_can_spit = bool(_def.get("can_spit", true))
	_final = bool(_def.get("final_boss", false))
	# 난이도 곡선: 날짜가 갈수록 보스도 강해짐(반복 등장 대비, 최대 ~2배)
	var dn := get_tree().get_first_node_in_group("day_night")
	var day: int = dn.day if dn else 1
	var scale: float = 1.0 + mini(day - 1, 14) * 0.07
	_hp *= scale
	_max_hp = _hp
	_damage *= scale
	_build_visual()
	collision_layer = 4
	collision_mask = 1
	_player = get_tree().get_first_node_in_group("player")
	_summon_cd = summon_interval


func _build_visual() -> void:
	var size_arr: Array = _def.get("size", [1.8, 1.6, 6.0])
	var sz := Vector3(size_arr[0], size_arr[1], size_arr[2])
	_base_color = Color.html(_def.get("color", "#4a6e34"))
	_pivot = Node3D.new()
	add_child(_pivot)
	var model_path: String = _def.get("model", "")
	var visual: Node3D = LowpolyFactory.build(sz, _base_color, model_path, false, _def.get("shape", "segmented"))
	_pivot.add_child(visual)  # 모델 정면이 +Z라 추가 회전 불필요
	_mat = LowpolyFactory.last_material  # 본체 머티리얼(플래시/광폭화 틴트용, 모델이면 null)
	_anim = LowpolyFactory.find_anim_player(visual)
	_walk_anim = LowpolyFactory.pick_locomotion(_anim)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	cs.shape = box
	cs.position.y = sz.y * 0.5
	add_child(cs)


func get_health() -> float: return _hp
func get_max_health() -> float: return _max_hp
func get_display_name() -> String:
	return _name + ("  (광폭화)" if _enraged else "")


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_summon_cd = maxf(0.0, _summon_cd - delta)
	LowpolyFactory.update_locomotion(_anim, _walk_anim, Vector2(velocity.x, velocity.z).length())

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(0.0, velocity.y)

	if _state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# 졸개 소환(전투 중)
	if _summon_cd <= 0.0 and _hp < _max_hp:
		_summon()
		_summon_cd = summon_interval

	var to_player := Vector3.ZERO
	var dist := INF
	if _player:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	var move_dir := Vector3.ZERO
	match _state:
		State.APPROACH:
			move_dir = to_player.normalized() if dist > _attack_range else Vector3.ZERO
			if _player and _attack_cd <= 0.0 and dist <= float(_def.get("detect_range", 40.0)):
				if dist > 11.0:
					_pending = "spit" if _can_spit else "lunge"
				elif dist > 6.0:
					_pending = "lunge"
				else:
					_pending = "sweep"
				_tele_timer = telegraph_time
				_state = State.TELEGRAPH
				_show_telegraph(to_player)
			_face(to_player)
		State.TELEGRAPH:
			move_dir = Vector3.ZERO
			_telegraph_pulse()
			_face(to_player)
			_tele_timer -= delta
			if _tele_timer <= 0.0:
				_execute_attack(to_player)
		State.LUNGE:
			move_dir = _lunge_dir
			if not _hit_done and dist <= 2.8 and _player and _player.has_method("take_damage"):
				_player.take_damage(_damage, global_position)
				_hit_done = true
				GameState.shake(0.3)
			_lunge_time -= delta
			if _lunge_time <= 0.0:
				_attack_cd = attack_cooldown
				_state = State.APPROACH
		State.SWEEP, State.SPIT:
			move_dir = Vector3.ZERO
			_recover -= delta
			if _recover <= 0.0:
				_attack_cd = attack_cooldown
				_state = State.APPROACH

	var spd := _speed * (lunge_speed_mult if _state == State.LUNGE else 1.0)
	velocity.x = move_dir.x * spd
	velocity.z = move_dir.z * spd
	move_and_slide()


func _execute_attack(to_player: Vector3) -> void:
	_clear_telegraph()
	match _pending:
		"spit":
			_spit(to_player)
			_recover = 0.4
			_state = State.SPIT
		"lunge":
			_lunge_dir = to_player.normalized()
			_lunge_time = lunge_duration
			_hit_done = false
			_state = State.LUNGE
		_:
			_do_sweep()
			_recover = 0.5
			_state = State.SWEEP


func _spit(to_player: Vector3) -> void:
	var p: Node3D = ProjectileScene.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 1.2, 0) + to_player.normalized() * 1.5
	if p.has_method("setup"):
		p.setup(to_player.normalized(), 14.0, _damage * 0.75)


func _summon() -> void:
	var n := 2 if _enraged else 1
	for i in n:
		var e: Node3D = EnemyScene.instantiate()
		e.enemy_type = _summon_type
		get_parent().add_child(e)
		var ang := randf() * TAU
		e.global_position = global_position + Vector3(cos(ang) * 3.0, 1.0, sin(ang) * 3.0)


func _do_sweep() -> void:
	GameState.shake(0.4)
	if _player and _player.has_method("take_damage"):
		var d: float = global_position.distance_to(_player.global_position)
		if d <= sweep_radius:
			_player.take_damage(_damage, global_position)


func _telegraph_pulse() -> void:
	var s: float = 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.03)
	_pivot.scale = Vector3(s, s, s)


func _face(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(dir.x, dir.z)
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, target_yaw, 0.2)


func take_damage(dmg: float, _from_pos: Vector3, crit: bool = false) -> void:
	if _state == State.DEAD:
		return
	_hp -= dmg
	_flash()
	if crit:
		GameState.spawn_text(global_position, "%d!" % int(dmg), Color(1.0, 0.8, 0.15), 1.8)
	else:
		GameState.spawn_text(global_position, str(int(dmg)), Color(1, 0.95, 0.6))
	# 광폭화 진입
	if not _enraged and _hp <= _max_hp * enrage_ratio:
		_enrage()
	if _hp <= 0.0:
		_die()


func _enrage() -> void:
	_enraged = true
	_speed *= 1.3
	_damage *= 1.4
	attack_cooldown *= 0.7
	summon_interval *= 0.6
	_base_color = Color(0.7, 0.3, 0.25)
	if _mat:
		_mat.albedo_color = _base_color
	# 페이즈2 진입 연출: 분노 배너 + 포효 + 방사형 독액 난사
	GameState.report_boss_enrage(_name)
	GameState.shake(0.5)
	AudioManager.play("boss_die")
	for i in 8:
		var ang := TAU * i / 8.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var p: Node3D = ProjectileScene.instantiate()
		get_parent().add_child(p)
		p.global_position = global_position + Vector3(0, 1.2, 0) + dir
		if p.has_method("setup"):
			p.setup(dir, 10.0, _damage * 0.6)


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
	remove_from_group("boss")
	_clear_telegraph()
	AudioManager.play("boss_die")
	GameState.spawn_puff(global_position, _base_color, 28)
	GameState.shake(0.6)
	GameState.spawn_drops(global_position, _def.get("drops", {}))
	# 보스 처치 확정 보상: 보물 상자 드롭
	var sm := get_tree().get_first_node_in_group("spawn_manager")
	if sm and sm.has_method("spawn_chest"):
		sm.spawn_chest("boss", global_position)
	GameState.report_boss_defeated(_final, _name)
	var tw := create_tween()
	tw.tween_property(_pivot, "scale", Vector3(1, 0.05, 1), 0.5)
	tw.tween_callback(queue_free)


## 공격 예고 바닥 마커 표시
func _show_telegraph(to_player: Vector3) -> void:
	_clear_telegraph()
	var sz := Vector3.ONE
	var pos := global_position
	var yaw := 0.0
	match _pending:
		"sweep":
			sz = Vector3(sweep_radius * 2.0, 0.06, sweep_radius * 2.0)
		"lunge":
			sz = Vector3(2.4, 0.06, 5.5)
			yaw = atan2(to_player.x, to_player.z)
			pos = global_position + to_player.normalized() * 2.6
		_:
			sz = Vector3(1.6, 0.06, 1.6)
			pos = global_position + to_player
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.2, 0.2, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.1, 0.1)
	mi.material_override = mat
	mi.rotation.y = yaw
	get_parent().add_child(mi)
	mi.global_position = Vector3(pos.x, 0.06, pos.z)
	_indicator = mi


func _clear_telegraph() -> void:
	if _indicator and is_instance_valid(_indicator):
		_indicator.queue_free()
	_indicator = null
