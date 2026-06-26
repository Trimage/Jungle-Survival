extends Area3D
## 자원 노드 (M3)
## - node_type 에 맞는 메시/색/수확물을 ItemDB 데이터로 구성
## - 플레이어가 근처에서 채집하면 yield 만큼 인벤토리에 적재, uses 소진 시 고갈
## - respawn_time > 0 이면 일정 시간 후 재생

## 자원 종류(데이터 키). 인스턴스마다 인스펙터/씬에서 지정.
@export var node_type: String = "tree"
## 고갈 후 재생까지 시간(초). 0이면 재생 안 함.
@export var respawn_time: float = 25.0

var _def: Dictionary = {}
var _uses: int = 0
var _mesh: Node3D
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group("resource_node")
	_def = ItemDB.node_def(node_type)
	# 감지용 레이어 설정: 자원노드=레이어2, 자체 감지는 불필요
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	_build_visual()
	_uses = int(_def.get("uses", 1))


## 데이터 기반으로 박스 메시 + 감지 충돌형을 생성
func _build_visual() -> void:
	var size_arr: Array = _def.get("size", [1.0, 1.0, 1.0])
	var sz := Vector3(size_arr[0], size_arr[1], size_arr[2])
	var col := Color.html(_def.get("color", "#888888"))

	# 데이터의 model(.glb) 경로가 있으면 외부 모델, 없으면 기본 박스
	_mesh = LowpolyFactory.build(sz, col, _def.get("model", ""), false, _def.get("shape", "box"))
	add_child(_mesh)

	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	_shape.shape = box
	_shape.position.y = sz.y * 0.5
	add_child(_shape)


func display_name() -> String:
	return _def.get("name", node_type)


func is_available() -> bool:
	return _uses > 0


## 1회 채집. 획득한 {id: amount} 사전을 반환(없으면 빈 사전).
func harvest(inv: Node) -> Dictionary:
	if _uses <= 0:
		return {}
	var yields: Dictionary = _def.get("yield", {})
	for id in yields:
		inv.add_item(id, int(yields[id]))
	_uses -= 1
	_punch()
	# 채집 파편(자원 색의 조각/잎이 튐)
	var col := Color.html(_def.get("color", "#888888"))
	GameState.spawn_puff(global_position, col, 8)
	if _uses <= 0:
		_deplete()
	return yields


## 채집 시 살짝 눌렸다 돌아오는 피드백
func _punch() -> void:
	if _mesh == null:
		return
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.15, 0.8, 1.15), 0.06)
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.12)


func _deplete() -> void:
	set_deferred("monitorable", false)
	# 줄어들며 사라지는 고갈 연출
	if _mesh:
		var tw := create_tween()
		tw.tween_property(_mesh, "scale", Vector3(0.05, 0.05, 0.05), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		await tw.finished
	visible = false
	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time).timeout
		_uses = int(_def.get("uses", 1))
		visible = true
		set_deferred("monitorable", true)
		# 솟아오르며 재등장
		if _mesh:
			_mesh.scale = Vector3(0.05, 0.05, 0.05)
			var rt := create_tween()
			rt.tween_property(_mesh, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
