extends Control
## 미니맵/레이더 (콘텐츠 추천)
## - 플레이어 중심으로 자원/건물/적/부락민을 점으로 표시
## - 카메라 요(45°)에 맞춰 회전해 화면 방향과 정렬

@export var world_radius: float = 26.0

var _player: Node3D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r: float = size.x * 0.5
	var c := Vector2(r, r)
	draw_circle(c, r, Color(0, 0, 0, 0.45))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 2.0, true)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	var pp: Vector3 = _player.global_position
	_dots("resource_node", Color(0.5, 0.85, 0.4), pp, c, r, 2.5)
	_dots("building", Color(0.45, 0.7, 1.0), pp, c, r, 3.0)
	_dots("villager", Color(0.4, 0.85, 0.95), pp, c, r, 2.5)
	_dots("enemy", Color(0.95, 0.3, 0.3), pp, c, r, 3.0)
	# 플레이어(중앙)
	draw_circle(c, 4.0, Color(1, 1, 1))


func _dots(group: String, color: Color, pp: Vector3, c: Vector2, r: float, dot_size: float) -> void:
	for n in get_tree().get_nodes_in_group(group):
		if not (n is Node3D):
			continue
		var rel: Vector3 = n.global_position - pp
		var v := Vector2(rel.x, rel.z) / world_radius * r
		v = v.rotated(deg_to_rad(45.0))  # 화면 방향 정렬
		if v.length() <= r - 2.0:
			draw_circle(c + v, dot_size, color)
