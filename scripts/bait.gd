extends StaticBody3D
## 미끼(유인용 고기) — 던지면 그 자리에서 맹수를 끌어모은다.
## - 그룹 "bait" 로 enemy._get_target 가 최우선 표적으로 삼음.
## - 맹수가 물어뜯으면(take_damage) 닳고, 수명이 다하면 사라짐.

var _hp: float = 60.0
var _life: float = 8.0
var _mat: StandardMaterial3D
var _base_color := Color(0.78, 0.32, 0.3)


func setup(hp: float, duration: float) -> void:
	_hp = hp
	_life = duration


func _ready() -> void:
	add_to_group("bait")
	collision_layer = 0
	collision_mask = 0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.4, 0.7)
	mi.mesh = bm
	mi.position.y = 0.2
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	mi.material_override = _mat
	add_child(mi)

	# 냄새 표시(끌림 연출)
	var p := CPUParticles3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.1, 0.1, 0.1)
	p.mesh = pm
	p.amount = 10
	p.lifetime = 1.2
	p.emitting = true
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.6, 0)
	p.color = Color(0.7, 0.5, 0.3, 0.7)
	p.position.y = 0.4
	add_child(p)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()


func take_damage(dmg: float, _from_pos: Vector3) -> void:
	_hp -= dmg
	if _mat:
		_mat.albedo_color = Color(1, 1, 1)
		var tw := create_tween()
		tw.tween_property(_mat, "albedo_color", _base_color, 0.2)
	if _hp <= 0.0:
		GameState.spawn_puff(global_position, _base_color, 8)
		queue_free()
