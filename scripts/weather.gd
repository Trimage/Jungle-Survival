extends Node3D
## 간헐적 비 날씨 — 마른 텀과 비 텀을 번갈아.
## 비가 오면: 플레이어 위를 따라다니는 빗방울 파티클 + 화면이 어둑/탁해지고
## (밝기·채도·안개 보정) 강한 비엔 간헐적 번개 번쩍 + 천둥 진동.
## 환경의 adjustment_*/fog_density 만 건드려 낮/밤 사이클(앰비언트·하늘)과 충돌 없음.

@export var dry_min: float = 70.0
@export var dry_max: float = 150.0
@export var rain_min: float = 30.0
@export var rain_max: float = 60.0

var _rain: CPUParticles3D
var _raining: bool = false
var _timer: float = 0.0
var _wet: float = 0.0          # 0~1 비 강도(부드러운 전환)
var _flash: float = 0.0        # 번개 번쩍(감쇠)
var _light_t: float = 8.0
var _player: Node3D = null
var _env: Environment = null

const BASE_BRIGHT := 1.06
const BASE_SAT := 1.4
const BASE_FOG := 0.006


func _ready() -> void:
	_make_rain()
	_timer = randf_range(dry_min, dry_max)
	# 환경은 _process 에서 지연 조회(자식 _ready 가 부모보다 먼저 실행돼 그룹 미등록)


## WorldEnvironment 의 Environment 를 찾는다(있으면 캐시).
func _resolve_env() -> void:
	var dn := get_tree().get_first_node_in_group("day_night")
	if dn:
		var we := dn.get_node_or_null("WorldEnvironment")
		if we:
			_env = we.environment


func _make_rain() -> void:
	_rain = CPUParticles3D.new()
	_rain.amount = 230
	_rain.lifetime = 0.7
	_rain.local_coords = false  # 빗방울이 월드 공간에서 떨어짐
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(15, 0.5, 15)
	_rain.direction = Vector3(0, -1, 0)
	_rain.spread = 0.0
	_rain.gravity = Vector3(0, -3, 0)
	_rain.initial_velocity_min = 18.0
	_rain.initial_velocity_max = 22.0
	var m := BoxMesh.new()
	m.size = Vector3(0.025, 0.5, 0.025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.72, 0.82, 0.96, 0.6)
	m.material = mat
	_rain.mesh = m
	_rain.emitting = false
	_rain.position.y = 13.0
	add_child(_rain)


func _process(delta: float) -> void:
	if _env == null:
		_resolve_env()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		_rain.global_position = _player.global_position + Vector3(0, 13, 0)

	_timer -= delta
	if _timer <= 0.0:
		_toggle()

	# 비 강도 부드러운 전환
	_wet = move_toward(_wet, 1.0 if _raining else 0.0, delta * 0.4)
	_flash = maxf(0.0, _flash - delta * 4.0)

	# 강한 비에 간헐적 번개
	if _raining and _wet > 0.55:
		_light_t -= delta
		if _light_t <= 0.0:
			_light_t = randf_range(6.0, 16.0)
			_flash = 1.0
			GameState.vibrate(90)
			GameState.shake(0.18)

	_apply_wet()


func _toggle() -> void:
	_raining = not _raining
	_rain.emitting = _raining
	_timer = randf_range(rain_min, rain_max) if _raining else randf_range(dry_min, dry_max)


func _apply_wet() -> void:
	if _env == null:
		return
	_env.adjustment_brightness = lerpf(BASE_BRIGHT, 0.82, _wet) + _flash * 0.85
	_env.adjustment_saturation = lerpf(BASE_SAT, 1.04, _wet)
	_env.fog_density = lerpf(BASE_FOG, 0.02, _wet)


## 현재 비가 오는지(다른 시스템이 참고 가능)
func is_raining() -> bool:
	return _raining
