extends Node3D
## 낮/밤 사이클 (M2)
## - 하루(day_length)를 0~1 의 time_of_day 로 순환
## - 태양(DirectionalLight3D)을 회전시키고, 낮/밤에 따라 빛 색·밝기와
##   환경 앰비언트를 보간 → 밤엔 어둡고 푸른 톤
## - 낮↔밤 전환 및 날짜 증가를 시그널로 알림(맹수 웨이브 등 M5 연동 대비)

## time_of_day(0~1) 와 현재 날짜를 매 프레임 알림
signal time_changed(time_of_day: float, day: int)
## 낮↔밤 전환 (is_night)
signal phase_changed(is_night: bool)
## 하루가 지나 날짜가 바뀜
signal day_advanced(day: int)

## 하루 전체 길이(초). 너무 빠르지 않게 여유 있는 호흡으로.
@export var day_length: float = 240.0
## 시작 시각(0=자정, 0.25=일출, 0.5=정오, 0.75=일몰)
@export var start_time: float = 0.3

@export_group("낮 라이팅")
@export var day_light_color: Color = Color(1.0, 0.96, 0.86)
@export var day_light_energy: float = 1.2
@export var day_ambient_color: Color = Color(0.7, 0.75, 0.7)
@export var day_ambient_energy: float = 0.6

@export_group("밤 라이팅")
@export var night_light_color: Color = Color(0.55, 0.65, 0.95)
@export var night_light_energy: float = 0.3
@export var night_ambient_color: Color = Color(0.26, 0.33, 0.52)
@export var night_ambient_energy: float = 0.45

## 밤으로 판정하는 태양 높이 임계값
@export var night_threshold: float = 0.25

var time_of_day: float = 0.0
var day: int = 1

var _is_night: bool = false
@onready var _sun: DirectionalLight3D = $Sun
@onready var _world_env: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	add_to_group("day_night")
	time_of_day = start_time
	_update_visuals(true)


func _process(delta: float) -> void:
	# 시간 진행 및 날짜 넘김
	time_of_day += delta / day_length
	while time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		day_advanced.emit(day)

	_update_visuals(false)
	time_changed.emit(time_of_day, day)


func _update_visuals(force_signal: bool) -> void:
	# 태양 높이: 0=지평선 아래(밤), 1=머리 위(정오)
	var sun_height: float = sin(time_of_day * TAU - PI * 0.5)  # 자정 -1, 정오 +1
	var day_factor: float = clampf(smoothstep(-0.15, 0.35, sun_height), 0.0, 1.0)

	# 태양을 시간에 따라 회전(시각적 호) — 일출 0° → 정오 -90° → 일몰 -180°
	_sun.rotation_degrees = Vector3((time_of_day - 0.25) * -360.0, -35.0, 0.0)

	# 빛 색/밝기 보간
	_sun.light_color = night_light_color.lerp(day_light_color, day_factor)
	_sun.light_energy = lerpf(night_light_energy, day_light_energy, day_factor)

	# 환경 앰비언트 보간
	if _world_env and _world_env.environment:
		var env: Environment = _world_env.environment
		env.ambient_light_color = night_ambient_color.lerp(day_ambient_color, day_factor)
		env.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, day_factor)

	# 낮/밤 전환 판정
	var now_night: bool = sun_height < night_threshold
	if now_night != _is_night or force_signal:
		_is_night = now_night
		phase_changed.emit(_is_night)


func is_night() -> bool:
	return _is_night


## 밤(맹수 습격) 시작까지 남은 초. 이미 밤이면 0.
## sun_height = -cos(2πt) 이 night_threshold 아래로 떨어지는 황혼 시점까지의 거리로 계산.
func seconds_until_night() -> float:
	if _is_night:
		return 0.0
	# 황혼(하강 구간)에서 sun_height == threshold 가 되는 시각
	var dusk_t: float = (TAU - acos(-clampf(night_threshold, -1.0, 1.0))) / TAU
	var dt: float = dusk_t - time_of_day
	if dt < 0.0:
		dt += 1.0
	return dt * day_length
