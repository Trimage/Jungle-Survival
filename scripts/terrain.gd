extends Node3D
## 독특한 지형 생성 (콘텐츠 확장)
## - 연못 / 흙 공터 / 낮은 언덕(시각) / 고대 폐허 기둥·아치(충돌=엄폐물)
## - "정글에 삼켜진 옛 문명의 잔해" 분위기. 시작 시 한 번 생성.


func _ready() -> void:
	_pond(Vector3(-16, 0, -13), 7.0)
	_patch(Vector3(9, 0, 9), 5.5, Color(0.5, 0.42, 0.3))
	_patch(Vector3(-7, 0, 7), 4.5, Color(0.46, 0.4, 0.3))
	_patch(Vector3(0, 0, 0), 6.0, Color(0.55, 0.5, 0.4))  # 중앙 광장
	# 낮은 언덕(외곽)
	_hill(Vector3(18, 0, -16), 7.0, 1.4)
	_hill(Vector3(-20, 0, 14), 8.0, 1.8)
	_hill(Vector3(16, 0, 18), 6.0, 1.2)
	_hill(Vector3(-18, 0, -18), 6.5, 1.5)
	# 고대 폐허 군집(엄폐물)
	_ruins(Vector3(8, 0, -4))
	# 맵 경계: 바닥(±30) 끝에서 떨어지지 않도록 보이지 않는 벽
	_boundary(29.0)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _pond(pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.12
	mi.mesh = cyl
	mi.position = pos + Vector3(0, 0.07, 0)
	var m := _mat(Color(0.3, 0.55, 0.8))
	m.metallic = 0.3
	m.roughness = 0.2
	mi.material_override = m
	add_child(mi)


func _patch(pos: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.08
	mi.mesh = cyl
	mi.position = pos + Vector3(0, 0.05, 0)
	mi.material_override = _mat(col)
	add_child(mi)


func _hill(pos: Vector3, base_r: float, h: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = base_r
	cyl.top_radius = base_r * 0.45
	cyl.height = h
	mi.mesh = cyl
	mi.position = pos + Vector3(0, h * 0.5, 0)
	mi.material_override = _mat(Color(0.36, 0.55, 0.3).lightened(randf() * 0.08))
	add_child(mi)


# 부서진 기둥 1개(충돌 있는 StaticBody)
func _pillar(pos: Vector3, h: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, h, 0.7)
	mi.mesh = bm
	mi.position.y = h * 0.5
	mi.material_override = _mat(Color(0.62, 0.6, 0.55))
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, h, 0.7)
	cs.shape = box
	cs.position.y = h * 0.5
	body.add_child(cs)


func _ruins(center: Vector3) -> void:
	# 흩어진 부서진 기둥들
	_pillar(center + Vector3(-3, 0, 2), 2.6)
	_pillar(center + Vector3(3, 0, 3), 1.4)
	_pillar(center + Vector3(4, 0, -2), 3.2)
	_pillar(center + Vector3(-2, 0, -3), 1.8)
	# 아치(기둥 둘 + 상인방)
	_pillar(center + Vector3(-1, 0, 0), 3.4)
	_pillar(center + Vector3(1.6, 0, 0), 3.4)
	var lintel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.4, 0.6, 0.8)
	lintel.mesh = bm
	lintel.position = center + Vector3(0.3, 3.6, 0)
	lintel.material_override = _mat(Color(0.58, 0.56, 0.5))
	add_child(lintel)


## 맵 경계의 보이지 않는 벽 4개(메시 없이 콜리전만). half = 중심에서 벽까지 거리.
func _boundary(half: float) -> void:
	var h := 6.0       # 벽 높이(넘지 못하게)
	var t := 1.0       # 벽 두께
	var span := half * 2.0 + 2.0
	# x = ±half (z축 따라 긴 벽)
	for sx in [-1.0, 1.0]:
		_wall(Vector3(sx * half, h * 0.5, 0.0), Vector3(t, h, span))
	# z = ±half (x축 따라 긴 벽)
	for sz in [-1.0, 1.0]:
		_wall(Vector3(0.0, h * 0.5, sz * half), Vector3(span, h, t))


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1   # 지형과 동일 레이어 → 플레이어/맹수가 막힘
	body.collision_mask = 0
	add_child(body)
	body.position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	# 메시 없음 = 투명 벽
