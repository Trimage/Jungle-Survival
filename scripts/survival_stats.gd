extends Node
class_name SurvivalStats
## 생존 스탯 시스템 (M2)
## - 체력/허기/수분/스태미나/감염도 5종을 데이터 주도(STAT_DEFS)로 관리
## - 매 프레임 시간에 따라 변동, 위험치에서 체력 패널티, 체력 0 → 사망
## - 값이 바뀌면 stat_changed 시그널을 보내 HUD가 갱신하도록 함

## 스탯이 바뀔 때마다 알림 (키, 현재값, 최대값)
signal stat_changed(key: String, value: float, max_value: float)
## 체력이 0이 되어 사망
signal died

## 스탯 정의(데이터 주도): 키 → 표시이름 / 색 / 최대값 / 시작값 / 초당 감소율
## decay 가 양수면 감소(허기·수분), 음수면 증가(감염도). 0은 별도 로직 처리.
const STAT_DEFS := {
	"health":    {"name": "체력",    "icon": "♥", "color": Color(0.85, 0.27, 0.27), "max": 100.0, "start": 100.0, "decay": 0.0},
	"hunger":    {"name": "허기",    "icon": "🍖", "color": Color(0.92, 0.57, 0.22), "max": 100.0, "start": 100.0, "decay": 0.8},
	"thirst":    {"name": "수분",    "icon": "💧", "color": Color(0.32, 0.62, 0.9),  "max": 100.0, "start": 100.0, "decay": 1.1},
	"stamina":   {"name": "스태미나", "icon": "⚡", "color": Color(0.42, 0.8, 0.45),  "max": 100.0, "start": 100.0, "decay": 0.0},
	"infection": {"name": "감염도",  "icon": "☣", "color": Color(0.62, 0.36, 0.72), "max": 100.0, "start": 0.0,   "decay": -0.15},
}

## 허기/수분이 0일 때 초당 체력 감소
@export var starve_damage: float = 2.0
## 감염도가 이 값 이상이면 체력 감소 시작
@export var infection_threshold: float = 80.0
## 감염 위험 시 초당 체력 감소
@export var infection_damage: float = 1.5
## 스태미나 초당 자연 회복(이동/공격에서 소모는 추후 M5)
@export var stamina_regen: float = 8.0

var _values: Dictionary = {}
var _alive: bool = true
## 퍽 등으로 늘어난 스탯 상한 보너스(키 → 추가 최대값)
var _max_bonus: Dictionary = {}


func _ready() -> void:
	add_to_group("survival_stats")
	# 시작값 초기화
	for key in STAT_DEFS:
		_values[key] = float(STAT_DEFS[key]["start"])


func _process(delta: float) -> void:
	if not _alive:
		return

	# 1) 일반 스탯 변동(허기·수분 감소, 감염도 증가)
	for key in ["hunger", "thirst", "infection"]:
		_apply(key, -STAT_DEFS[key]["decay"] * delta)

	# 2) 스태미나 자연 회복
	_apply("stamina", stamina_regen * delta)

	# 3) 체력 패널티 계산
	var dmg := 0.0
	if _values["hunger"] <= 0.0:
		dmg += starve_damage
	if _values["thirst"] <= 0.0:
		dmg += starve_damage
	if _values["infection"] >= infection_threshold:
		dmg += infection_damage
	if dmg > 0.0:
		_apply("health", -dmg * delta)


## 스탯의 현재 최대값(기본 + 퍽 보너스)
func get_max(key: String) -> float:
	return float(STAT_DEFS[key]["max"]) + float(_max_bonus.get(key, 0.0))


## 스탯 상한 보너스를 절대값으로 설정(누적 아님). heal_delta>0 이면 그만큼 회복.
func set_max_bonus(key: String, amount: float, heal_delta: float = 0.0) -> void:
	if not STAT_DEFS.has(key):
		return
	_max_bonus[key] = amount
	if heal_delta > 0.0:
		_apply(key, heal_delta)
	else:
		stat_changed.emit(key, _values.get(key, 0.0), get_max(key))


## 스탯 값을 amount 만큼 더하고 클램프 후 시그널 발신
func _apply(key: String, amount: float) -> void:
	var max_v: float = get_max(key)
	var old: float = _values[key]
	var new_v: float = clampf(old + amount, 0.0, max_v)
	if not is_equal_approx(old, new_v):
		_values[key] = new_v
		stat_changed.emit(key, new_v, max_v)
	# 체력이 0이 되면 즉시 사망 판정(즉사 공격도 바로 반영)
	if key == "health" and _alive and _values["health"] <= 0.0:
		_alive = false
		died.emit()


## 외부에서 스탯을 변경(예: 음식 섭취 +허기). amount 양수=증가
func modify(key: String, amount: float) -> void:
	if _values.has(key):
		_apply(key, amount)


## 현재 값 조회
func get_value(key: String) -> float:
	return _values.get(key, 0.0)


## 특정 스탯 값을 직접 설정(불러오기용)
func set_value(key: String, value: float) -> void:
	if STAT_DEFS.has(key):
		_values[key] = clampf(value, 0.0, get_max(key))
		stat_changed.emit(key, _values[key], get_max(key))


## 생존 상태로 강제(불러오기 시 사망 플래그 해제)
func force_alive() -> void:
	_alive = true


## 부활: 모든 스탯을 시작값으로 복구하고 생존 상태로
func revive() -> void:
	_alive = true
	for key in STAT_DEFS:
		var start_v: float = float(STAT_DEFS[key]["start"])
		_values[key] = start_v
		stat_changed.emit(key, start_v, get_max(key))
