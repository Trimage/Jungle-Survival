extends Area3D
## 보스 독액 투사체 (M7 확장)
## - 직선으로 날아가 플레이어에 닿으면 피해, 수명 후 소멸

var _dir: Vector3 = Vector3.FORWARD
var _speed: float = 12.0
var _damage: float = 10.0
var _life: float = 3.0


func setup(dir: Vector3, speed: float, dmg: float) -> void:
	_dir = dir.normalized()
	_speed = speed
	_damage = dmg


func _ready() -> void:
	add_to_group("projectile")
	collision_layer = 0
	collision_mask = 1  # 플레이어/지형 감지
	monitoring = true

	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.8, 0.2)
	LowpolyFactory.apply_outline(mat)
	mi.material_override = mat
	add_child(mi)

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	cs.shape = sh
	add_child(cs)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(_damage, global_position)
		queue_free()
