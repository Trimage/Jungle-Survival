extends Node
class_name Inventory
## 슬롯형 인벤토리 (M3)
## - 같은 아이템은 max_stack 까지 한 슬롯에 쌓고, 넘치면 새 슬롯 사용
## - 변경 시 changed, 획득 시 item_added 시그널 발신

## 슬롯 구성이 바뀜(UI 재구성용)
signal changed
## 아이템을 실제로 획득함 (토스트용)
signal item_added(id: String, amount: int)

## 최대 슬롯 수
@export var max_slots: int = 20

## 슬롯 배열. 각 원소 = {"id": String, "count": int}
var slots: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("inventory")


## 아이템 추가. 담지 못한 잔량을 반환(0이면 전부 수납).
func add_item(id: String, amount: int) -> int:
	var remaining: int = amount
	var ms: int = ItemDB.max_stack(id)

	# 1) 기존 같은 아이템 슬롯에 채우기
	for s in slots:
		if remaining <= 0:
			break
		if s["id"] == id and s["count"] < ms:
			var add: int = mini(ms - s["count"], remaining)
			s["count"] += add
			remaining -= add

	# 2) 남으면 새 슬롯 생성
	while remaining > 0 and slots.size() < max_slots:
		var add: int = mini(ms, remaining)
		slots.append({"id": id, "count": add})
		remaining -= add

	var added: int = amount - remaining
	if added > 0:
		item_added.emit(id, added)
		changed.emit()
	return remaining


## 아이템 총 보유 수량
func count_of(id: String) -> int:
	var total: int = 0
	for s in slots:
		if s["id"] == id:
			total += s["count"]
	return total


## 비용 사전(예: {"wood":5})을 모두 충족하는지
func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if count_of(id) < int(cost[id]):
			return false
	return true


## 비용만큼 차감. 부족하면 아무것도 안 하고 false.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for id in cost:
		_remove(id, int(cost[id]))
	changed.emit()
	return true


## 특정 아이템을 amount 만큼 제거(슬롯 가로질러). 부족하면 false.
func remove_item(id: String, amount: int) -> bool:
	if count_of(id) < amount:
		return false
	_remove(id, amount)
	changed.emit()
	return true


## 내부: 시그널 없이 슬롯에서 제거(뒤 슬롯부터)
func _remove(id: String, amount: int) -> void:
	var left: int = amount
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			break
		if slots[i]["id"] == id:
			var take: int = mini(slots[i]["count"], left)
			slots[i]["count"] -= take
			left -= take
			if slots[i]["count"] <= 0:
				slots.remove_at(i)


func get_slots() -> Array[Dictionary]:
	return slots


## 저장 데이터로 슬롯 교체(불러오기용)
func load_slots(arr: Array) -> void:
	slots.clear()
	for s in arr:
		slots.append({"id": str(s["id"]), "count": int(s["count"])})
	changed.emit()
