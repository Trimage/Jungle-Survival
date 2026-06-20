extends Node
## 날씨/이벤트 매니저 (콘텐츠 확장)
## - 날이 바뀔 때 확률로 이벤트 발생(폭우/역병/혹한/폭염)
## - 지속 시간 동안 플레이어 생존 스탯에 초당 효과 적용 + HUD 배너/틴트
##   폭우=수분 회복, 역병=감염↑, 혹한=허기 가속, 폭염=수분 가속

## 날이 바뀔 때 이벤트 발생 확률
@export var event_chance: float = 0.55

var _daynight: Node = null
var _connected: bool = false
var _active_effects: Dictionary = {}
var _timer: float = 0.0
var _stats: Node = null


func _process(delta: float) -> void:
	if not _connected:
		_daynight = get_tree().get_first_node_in_group("day_night")
		if _daynight:
			_daynight.day_advanced.connect(_on_day_advanced)
			_connected = true
		return

	if _timer > 0.0:
		_timer -= delta
		_apply(delta)
		if _timer <= 0.0:
			_end()


func _on_day_advanced(_day: int) -> void:
	if _timer > 0.0:
		return
	if randf() <= event_chance and not ItemDB.events.is_empty():
		var keys: Array = ItemDB.events.keys()
		_start(keys[randi() % keys.size()])


func _start(id: String) -> void:
	var def: Dictionary = ItemDB.events[id]
	_active_effects = def.get("effects", {})
	_timer = float(def.get("duration", 40.0))
	GameState.report_event(def.get("name", id), Color.html(def.get("tint", "#000000")), true)


func _apply(delta: float) -> void:
	if _stats == null or not is_instance_valid(_stats):
		var p := get_tree().get_first_node_in_group("player")
		_stats = p.get_node_or_null("Stats") if p else null
	if _stats == null:
		return
	for key in _active_effects:
		_stats.modify(key, float(_active_effects[key]) * delta)


func _end() -> void:
	_active_effects = {}
	GameState.report_event("", Color.BLACK, false)
