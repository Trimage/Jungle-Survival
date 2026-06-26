extends Node3D
## 설치형 함정 — 바닥에 깔아두면 맹수가 밟을 때 작동.
## - trap_type "mine": 근접 시 폭발(광역 피해, fire_duration>0면 화염 잔류)
## - trap_type "slow": 마름쇠. 지속시간 동안 범위 내 맹수 감속 + 약한 출혈 피해

var _def: Dictionary = {}
var _type: String = "mine"
var _radius: float = 3.0
var _trigger: float = 1.4
var _damage: float = 50.0
var _fire_damage: float = 0.0
var _fire_duration: float = 0.0
var _slow: float = 0.5
var _duration: float = 7.0
var _tick_damage: float = 2.0

var _armed: float = 0.4   # 설치 직후 짧은 무장 지연
var _tick: float = 0.0
const TICK := 0.5
const ExplosiveScene := preload("res://scenes/explosive.tscn")


func setup(throw_def: Dictionary) -> void:
	_def = throw_def
	_type = throw_def.get("trap_type", "mine")
	_radius = float(throw_def.get("radius", 3.0))
	_trigger = float(throw_def.get("trigger", 1.4))
	_damage = float(throw_def.get("damage", 50.0))
	_fire_damage = float(throw_def.get("fire_damage", 0.0))
	_fire_duration = float(throw_def.get("fire_duration", 0.0))
	_slow = float(throw_def.get("slow", 0.5))
	_duration = float(throw_def.get("duration", 7.0))
	_tick_damage = float(throw_def.get("tick_damage", 2.0))


func _ready() -> void:
	add_to_group("trap")
	_build_visual()


func _build_visual() -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 0.12
	mi.mesh = cyl
	mi.position.y = 0.06
	var mat := StandardMaterial3D.new()
	if _type == "slow":
		mat.albedo_color = Color(0.6, 0.6, 0.65)
	else:
		mat.albedo_color = Color(0.7, 0.25, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.2, 0.1)
		mat.emission_energy_multiplier = 0.6
	LowpolyFactory.apply_outline(mat)
	mi.material_override = mat
	add_child(mi)


func _process(delta: float) -> void:
	if _armed > 0.0:
		_armed -= delta
		return
	if _type == "slow":
		_run_slow(delta)
	else:
		_check_mine()


## 지뢰: 가까운 맹수 감지 시 폭발
func _check_mine() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if global_position.distance_to(e.global_position) <= _trigger:
			_detonate()
			return


func _detonate() -> void:
	var ex: Node3D = ExplosiveScene.instantiate()
	ex.setup(global_position, _damage, _radius, _fire_damage, _fire_duration)
	get_parent().add_child(ex)
	ex.global_position = global_position
	queue_free()


## 마름쇠: 지속시간 동안 범위 내 맹수 감속 + 출혈
func _run_slow(delta: float) -> void:
	_duration -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.is_in_group("boss"):
				continue
			if global_position.distance_to(e.global_position) <= _radius:
				if e.has_method("apply_slow"):
					e.apply_slow(_slow, 0.8)
				if _tick_damage > 0.0 and e.has_method("take_damage"):
					e.take_damage(_tick_damage, global_position)
	if _duration <= 0.0:
		queue_free()
