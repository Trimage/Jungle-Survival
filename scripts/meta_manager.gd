extends Node
## 로그라이트 메타 진행(오토로드 "MetaManager")
## - 죽음으로 영구 재화 "유산"을 모으고, data/meta_upgrades.json 의 영구 강화를 구매한다.
## - 구매한 강화는 매 새 게임 시작 시 적용된다(런 단위 퍽과 별개의 영구 층위).
## - 저장은 런 세이브와 분리된 user://meta.json (죽어도/리셋해도 유지).

const PATH := "user://meta.json"

var currency: int = 0                 # 보유 유산
var upgrade_levels: Dictionary = {}   # 강화 id → 레벨
var _run_claimed: int = 0             # 이번 런에서 이미 지급한 유산(중복 지급 방지)


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		currency = int(parsed.get("currency", 0))
		upgrade_levels = (parsed.get("upgrades", {}) as Dictionary).duplicate()


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"currency": currency, "upgrades": upgrade_levels}, "  "))


func level_of(id: String) -> int:
	return int(upgrade_levels.get(id, 0))


func is_max(id: String) -> bool:
	return level_of(id) >= int(ItemDB.meta_upgrades.get(id, {}).get("max", 1))


## 다음 레벨 구매 비용(레벨마다 cost_growth 배로 상승)
func cost_of(id: String) -> int:
	var d: Dictionary = ItemDB.meta_upgrades.get(id, {})
	return int(round(float(d.get("cost", 10)) * pow(float(d.get("cost_growth", 1.6)), level_of(id))))


func can_buy(id: String) -> bool:
	return (not is_max(id)) and currency >= cost_of(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	currency -= cost_of(id)
	upgrade_levels[id] = level_of(id) + 1
	_save()
	return true


## 유산 적립(퀘스트 보상 등)
func add_currency(n: int) -> void:
	if n <= 0:
		return
	currency += n
	_save()


## 특정 효과(stat)의 보유 강화 합산값(per_level × 레벨)
func meta_sum(stat: String) -> float:
	var total: float = 0.0
	for id in upgrade_levels:
		var d: Dictionary = ItemDB.meta_upgrades.get(id, {})
		if d.get("stat", "") == stat:
			total += float(d.get("per_level", 0.0)) * level_of(id)
	return total


## 새 런 시작(reset_for_new_game 에서 호출): 이번 런 지급 누적 초기화
func begin_run() -> void:
	_run_claimed = 0


## 사망 시 호출. 이번 런 성과 기반 유산을, 이미 지급한 분을 뺀 만큼만 지급(되살아나기 악용 방지).
func award_on_death() -> int:
	var total: int = GameState.max_day * 3 + GameState.kills + GameState.bosses * 10
	var gain: int = maxi(0, total - _run_claimed)
	if gain > 0:
		currency += gain
		_run_claimed = total
		_save()
	return gain
