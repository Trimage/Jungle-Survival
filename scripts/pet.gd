extends CharacterBody3D
## 길들인 동료 펫 — 플레이어를 따라다니며 근처 맹수를 공격. 그룹 "pet"+"ally".
## - enemy 데이터로 능력치 구성(친화 색). 적이 표적으로 삼을 수 있어 죽기도 함.

@export var pet_type: String = "wolf"

var _def: Dictionary = {}
var _hp: float = 30.0
var _max_hp: float = 30.0
var _speed: float = 5.0
var _damage: float = 8.0
var _atk_range: float = 2.0
var _atk_cd: float = 0.8
var _detect: float = 16.0
var _atk_timer: float = 0.0
var _dead: bool = false
var _player: Node3D = null
var _mesh: Node3D
var _mat: StandardMaterial3D
var _base_color: Color = Color.WHITE
var _anim: AnimationPlayer = null
var _walk_anim: String = ""
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func setup(type: String) -> void:
	pet_type = type


func _ready() -> void:
	add_to_group("pet")
	add_to_group("ally")
	_def = ItemDB.enemy_def(pet_type)
	_hp = maxf(20.0, float(_def.get("hp", 25)) * 0.9)
	_max_hp = _hp
	_speed = float(_def.get("speed", 4.0)) + 0.8  # 플레이어를 잘 따라오게
	_damage = float(_def.get("damage", 8))
	_atk_range = float(_def.get("attack_range", 2.0))
	_atk_cd = float(_def.get("attack_cd", 0.8))
	_detect = float(_def.get("detect_range", 16.0))
	collision_layer = 0
	collision_mask = 1
	_build_visual()
	_player = get_tree().get_first_node_in_group("player")


func _build_visual() -> void:
	var size_arr: Array = _def.get("size", [1.0, 1.0, 1.0])
	var sz := Vector3(size_arr[0], size_arr[1], size_arr[2])
	_base_color = Color.html(_def.get("color", "#888888")).lightened(0.2)
	var model_path: String = _def.get("model", "")
	var built: Node3D = LowpolyFactory.build(sz, _base_color, model_path, false, _def.get("shape", "creature"))
	LowpolyFactory.outline_model(built)  # 카툰 외곽선
	_mat = LowpolyFactory.last_material
	if model_path != "" and ResourceLoader.exists(model_path):
		# 모델을 래퍼로 감싸 _face 회전과 분리(모델 정면 +Z)
		var wrapper := Node3D.new()
		wrapper.add_child(built)
		_mesh = wrapper
	else:
		_mesh = built
	add_child(_mesh)
	add_child(LowpolyFactory.make_blob_shadow(maxf(sz.x, sz.z) * 0.55))  # 발밑 그림자
	_anim = LowpolyFactory.find_anim_player(built)
	_walk_anim = LowpolyFactory.pick_locomotion(_anim)
	# 길들임 표식: 초록 목걸이 구슬
	var collar := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	collar.mesh = sm
	collar.position = Vector3(0, sz.y * 0.7, sz.z * 0.35)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.3, 0.9, 0.4)
	cm.emission_enabled = true
	cm.emission = Color(0.2, 0.8, 0.3)
	collar.material_override = cm
	add_child(collar)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	cs.shape = box
	cs.position.y = sz.y * 0.5
	add_child(cs)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_atk_timer = maxf(0.0, _atk_timer - delta)
	LowpolyFactory.update_locomotion(_anim, _walk_anim, Vector2(velocity.x, velocity.z).length())
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	var move_dir := Vector3.ZERO
	var foe := _nearest_enemy()
	if foe:
		var to: Vector3 = foe.global_position - global_position
		to.y = 0.0
		if to.length() <= _atk_range:
			_face(to)
			if _atk_timer <= 0.0 and foe.has_method("take_damage"):
				foe.take_damage(_damage, global_position)
				_atk_timer = _atk_cd
				AudioManager.play("hit")
		else:
			move_dir = to.normalized()
	elif _player and is_instance_valid(_player):
		var tp: Vector3 = _player.global_position - global_position
		tp.y = 0.0
		if tp.length() > 3.0:
			move_dir = tp.normalized()

	velocity.x = move_dir.x * _speed
	velocity.z = move_dir.z * _speed
	move_and_slide()
	if move_dir.length() > 0.05:
		_face(move_dir)


## 사거리(_detect) 내 최근접 맹수
func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d: float = _detect
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _face(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	_mesh.rotation.y = lerp_angle(_mesh.rotation.y, atan2(dir.x, dir.z), 0.3)


func take_damage(dmg: float, _from_pos: Vector3) -> void:
	if _dead:
		return
	_hp -= dmg
	if _mat:
		_mat.albedo_color = Color(1, 1, 1)
		var tw := create_tween()
		tw.tween_property(_mat, "albedo_color", _base_color, 0.25)
	if _hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("pet")
	remove_from_group("ally")
	GameState.spawn_puff(global_position, _base_color)
	GameState.spawn_text(global_position, "동료가 쓰러졌다…", Color(0.8, 0.8, 0.9))
	queue_free()
