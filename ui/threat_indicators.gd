extends Control
## 화면 밖 위협(맹수/보스) 방향 화살표 — 세로 화면 가독성(가독성 보강)
## - 매 프레임 적 그룹을 훑어 화면 밖이면 화면 가장자리에 방향 화살표를 그린다.
## - 보스는 더 크고 붉은 화살표 + 이름표.

const EDGE_MARGIN := 54.0       # 화면 가장자리 여백(px)
const ARROW := 17.0             # 일반 화살표 크기
const BOSS_ARROW := 26.0        # 보스 화살표 크기
const MAX_RANGE := 60.0         # 이 거리 밖의 적은 표시 안 함(너무 먼 배회 적 제외)

var _enemy_color := Color(0.95, 0.4, 0.3, 0.9)
var _boss_color := Color(1.0, 0.78, 0.2, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	var p_pos: Vector3 = player.global_position if player else Vector3.ZERO
	var vp: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp * 0.5
	var rect := Rect2(EDGE_MARGIN, EDGE_MARGIN, vp.x - EDGE_MARGIN * 2.0, vp.y - EDGE_MARGIN * 2.0)

	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D):
			continue
		var wpos: Vector3 = e.global_position + Vector3(0, 1.0, 0)
		var is_boss: bool = e.is_in_group("boss")
		# 보스는 거리 무관, 일반 적은 가까운 위협만
		if not is_boss and player and p_pos.distance_to(e.global_position) > MAX_RANGE:
			continue

		var behind: bool = cam.is_position_behind(wpos)
		var screen: Vector2 = cam.unproject_position(wpos)
		var on_screen: bool = (not behind) and rect.has_point(screen)
		if on_screen:
			continue  # 화면 안이면 굳이 화살표 불필요

		# 화면 밖(또는 뒤): 중심→대상 방향으로 가장자리에 화살표
		var dir: Vector2 = screen - center
		if behind:
			dir = -dir  # 카메라 뒤면 방향 반전
		if dir.length() < 0.001:
			dir = Vector2(0, 1)
		dir = dir.normalized()
		var edge: Vector2 = _edge_point(center, dir, rect)
		_draw_arrow(edge, dir, is_boss)


## 중심에서 dir 방향으로 rect 경계와 만나는 점
func _edge_point(center: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var tx: float = INF
	var ty: float = INF
	if absf(dir.x) > 0.0001:
		var bx: float = rect.position.x if dir.x < 0.0 else rect.end.x
		tx = (bx - center.x) / dir.x
	if absf(dir.y) > 0.0001:
		var by: float = rect.position.y if dir.y < 0.0 else rect.end.y
		ty = (by - center.y) / dir.y
	var t: float = minf(tx, ty)
	return center + dir * t


func _draw_arrow(pos: Vector2, dir: Vector2, is_boss: bool) -> void:
	var size: float = BOSS_ARROW if is_boss else ARROW
	var col: Color = _boss_color if is_boss else _enemy_color
	var perp := Vector2(-dir.y, dir.x)
	var tip: Vector2 = pos + dir * size
	var a: Vector2 = pos - dir * size * 0.5 + perp * size * 0.7
	var b: Vector2 = pos - dir * size * 0.5 - perp * size * 0.7
	# 외곽(가독성) + 본체
	draw_colored_polygon([tip, a, b], Color(0, 0, 0, 0.5))
	var inset := 0.78
	draw_colored_polygon([
		pos + dir * size * inset,
		pos - dir * size * 0.4 + perp * size * 0.55,
		pos - dir * size * 0.4 - perp * size * 0.55,
	], col)
	if is_boss:
		draw_circle(pos - dir * size * 1.1, 4.0, col)
