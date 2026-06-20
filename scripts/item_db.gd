extends Node
## 아이템/자원노드 데이터베이스 (M3, 오토로드 싱글톤 "ItemDB")
## - data/*.json 을 로드해 아이템·자원노드 정의를 제공(데이터 주도)
## - 코드 여기저기서 ItemDB.item_name(...) 등으로 접근

var items: Dictionary = {}        # 아이템 id → 정의
var node_defs: Dictionary = {}    # 자원노드 타입 → 정의
var recipes: Dictionary = {}      # 레시피 id → 정의 (제작)
var buildings: Dictionary = {}    # 건물 타입 → 정의 (건설)
var enemies: Dictionary = {}      # 적 타입 → 정의
var villagers: Dictionary = {}    # 부락민 직업 → 정의
var events: Dictionary = {}       # 날씨/이벤트 → 정의
var perks: Dictionary = {}        # 성장 퍽 id → 정의 (레벨업 보상)
var meta_upgrades: Dictionary = {} # 영구 강화 id → 정의 (로그라이트 메타)
var trades: Array = []            # 떠돌이 상인 거래 목록 [{give,get}]
var quests: Array = []            # 퀘스트/목표 [{id,name,type,target,reward}]
var research: Array = []          # 기술 연구 [{id,name,cost,unlocks,prereq}]


func _ready() -> void:
	items = _load_json("res://data/items.json")
	node_defs = _load_json("res://data/resource_nodes.json")
	recipes = _load_json("res://data/recipes.json")
	buildings = _load_json("res://data/buildings.json")
	enemies = _load_json("res://data/enemies.json")
	villagers = _load_json("res://data/villagers.json")
	events = _load_json("res://data/events.json")
	perks = _load_json("res://data/perks.json")
	meta_upgrades = _load_json("res://data/meta_upgrades.json")
	trades = _load_json_array("res://data/trades.json")
	quests = _load_json_array("res://data/quests.json")
	research = _load_json_array("res://data/research.json")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("ItemDB: 파일 없음 " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ItemDB: JSON 파싱 실패 " + path)
		return {}
	return parsed


## 배열 형태 JSON 로드(거래 목록 등)
func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("ItemDB: 파일 없음 " + path)
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ItemDB: JSON 배열 파싱 실패 " + path)
		return []
	return parsed


# --- 아이템 헬퍼 ---
func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id)

func item_color(id: String) -> Color:
	return Color.html(items.get(id, {}).get("color", "#ffffff"))

func max_stack(id: String) -> int:
	return int(items.get(id, {}).get("max_stack", 99))


# --- 자원노드 헬퍼 ---
func node_def(node_type: String) -> Dictionary:
	return node_defs.get(node_type, {})


# --- 제작/건설 헬퍼 ---
func recipe(id: String) -> Dictionary:
	return recipes.get(id, {})

func building_def(build_type: String) -> Dictionary:
	return buildings.get(build_type, {})

func enemy_def(enemy_type: String) -> Dictionary:
	return enemies.get(enemy_type, {})

func villager_def(job: String) -> Dictionary:
	return villagers.get(job, {})

func perk_def(id: String) -> Dictionary:
	return perks.get(id, {})

func meta_def(id: String) -> Dictionary:
	return meta_upgrades.get(id, {})


## 비용 사전을 "자재 2, 고철 1" 형태 문자열로
func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost:
		parts.append("%s %d" % [item_name(id), int(cost[id])])
	return ", ".join(parts)
