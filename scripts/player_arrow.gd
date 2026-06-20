extends Node3D
## 플레이어 원거리 무기(활/great_bow) 화살 — 직선 비행, 근접한 맹수에 명중 시 피해 후 소멸.
## - 충돌 레이어 대신 xz 평면 근접 판정(높이 무관)으로 안정적으로 적중(쿼터뷰 액션에 적합).

var _dir: Vector3 = Vector3.FORWARD
var _speed: float = 22.0
var _damage: float = 14.0
var _crit: bool = false
var _life: float = 2.2
const HIT_RADIUS := 0.7


func setup(dir: Vector3, speed: float, dmg: float, crit: bool = false) -> void:
	_dir = dir.normalized()
	_dir.y = 0.0
	_speed = speed
	_damage = dmg
	_crit = crit


func _ready() -> void:
	add_to_group("player_projectile")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.8)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.92, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.7, 0.3)
	mi.material_override = mat
	if _dir.length() > 0.01:
		mi.look_at_from_position(Vector3.ZERO, _dir, Vector3.UP)
	add_child(mi)


func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta
	# xz 평면 근접 판정
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.has_method("take_damage"):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() <= HIT_RADIUS:
			e.take_damage(_damage, global_position, _crit)
			GameState.spawn_puff(global_position, Color(0.95, 0.9, 0.6), 6)
			queue_free()
			return
	_life -= delta
	if _life <= 0.0:
		queue_free()
