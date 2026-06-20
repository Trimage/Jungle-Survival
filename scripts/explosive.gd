extends Area3D
## 투척 폭발물(폭탄/화염병) — 목표 지점으로 날아가 폭발, 반경 내 맹수에 광역 피해.
## - fire_duration>0 이면 폭발 후 그 자리에 화염 지대를 남겨 주기적으로 추가 피해(화염병).

var _target: Vector3 = Vector3.ZERO
var _speed: float = 15.0
var _damage: float = 40.0
var _radius: float = 3.0
var _fire_damage: float = 0.0
var _fire_duration: float = 0.0

var _state: String = "fly"   # fly → fire(있으면) → 소멸
var _fire_tick: float = 0.0
const FIRE_INTERVAL := 0.5
var _mesh: MeshInstance3D


func setup(target: Vector3, dmg: float, radius: float, fire_damage: float = 0.0, fire_duration: float = 0.0) -> void:
	_target = target
	_damage = dmg
	_radius = radius
	_fire_damage = fire_damage
	_fire_duration = fire_duration


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.18, 0.16)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.35, 0.1)
	_mesh.material_override = mat
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	if _state == "fly":
		var to: Vector3 = _target - global_position
		to.y = 0.0
		var step: float = _speed * delta
		if to.length() <= step + 0.3:
			_explode()
		else:
			global_position += to.normalized() * step
			_mesh.rotate_x(10.0 * delta)
	elif _state == "fire":
		_fire_duration -= delta
		_fire_tick -= delta
		if _fire_tick <= 0.0:
			_fire_tick = FIRE_INTERVAL
			_apply_aoe(_fire_damage)
		if _fire_duration <= 0.0:
			queue_free()


func _explode() -> void:
	_apply_aoe(_damage)
	GameState.spawn_puff(global_position, Color(1.0, 0.55, 0.15), 26)
	GameState.shake(0.3)
	AudioManager.play("hit")
	if _fire_duration > 0.0:
		# 화염 지대로 전환
		_state = "fire"
		_mesh.visible = false
		var fire := CPUParticles3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 0.2, 0.2)
		fire.mesh = bm
		fire.amount = 28
		fire.lifetime = 0.7
		fire.emitting = true
		fire.direction = Vector3.UP
		fire.spread = 35.0
		fire.initial_velocity_min = 1.0
		fire.initial_velocity_max = 2.6
		fire.gravity = Vector3(0, 1.5, 0)
		fire.color = Color(1.0, 0.5, 0.12)
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = _radius * 0.7
		add_child(fire)
	else:
		queue_free()


## 반경 내 맹수에 피해
func _apply_aoe(dmg: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.has_method("take_damage"):
			continue
		if global_position.distance_to(e.global_position) <= _radius:
			e.take_damage(dmg, global_position)
