extends Node3D
## 전리품 획득물 (콘텐츠 다듬기)
## - 적/보스 처치 시 드롭. 플레이어가 가까이 오면 빨려들어와 인벤토리에 적재.

var _id: String = "food"
var _amount: int = 1
var _mesh: MeshInstance3D
var _collected: bool = false
var _player: Node3D = null

const PICKUP_RANGE := 2.6


func setup(id: String, amount: int) -> void:
	_id = id
	_amount = amount


func _ready() -> void:
	add_to_group("pickup")
	var col := ItemDB.item_color(_id)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.4, 0.4)
	_mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col * 0.4
	_mesh.material_override = mat
	_mesh.position.y = 0.5
	add_child(_mesh)
	# 솟아오르는 등장 연출
	var tw := create_tween()
	tw.tween_property(_mesh, "position:y", 0.8, 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_mesh, "position:y", 0.5, 0.3)


func _process(delta: float) -> void:
	if _collected:
		return
	_mesh.rotate_y(delta * 2.5)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player and global_position.distance_to(_player.global_position) <= PICKUP_RANGE:
		_collect()


func _collect() -> void:
	_collected = true
	if _player.has_method("get_inventory"):
		_player.get_inventory().add_item(_id, _amount)
	AudioManager.play("harvest")
	var tw := create_tween()
	tw.tween_property(self, "global_position", _player.global_position + Vector3(0, 1, 0), 0.15)
	tw.parallel().tween_property(_mesh, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(queue_free)
