extends Node3D
## 독특한 지형 생성 (콘텐츠 확장 + 고급 디자인)
## - 연못 / 흙 공터 / 걸어 오르는 고지대 / 고대 폐허 / KayKit 헥사곤 자연 장식
## - "정글에 삼켜진 옛 문명의 잔해" 분위기. 시작 시 한 번 생성.

const NATURE := "res://assets/models/hexagon/nature/"
const DECO_TREES := ["tree_single_A", "tree_single_B", "trees_A_large", "trees_A_medium", "trees_B_large", "trees_B_medium"]
const DECO_ROCKS := ["rock_single_A", "rock_single_B", "rock_single_C", "rock_single_D"]
const DECO_WATER := ["waterplant_A", "waterlily_A"]


func _ready() -> void:
	_pond(Vector3(-16, 0, -13), 7.0)
	_patch(Vector3(9, 0, 9), 5.5, Color(0.5, 0.42, 0.3))
	_patch(Vector3(-7, 0, 7), 4.5, Color(0.46, 0.4, 0.3))
	_patch(Vector3(0, 0, 0), 6.0, Color(0.55, 0.5, 0.4))  # 중앙 광장
	# 걸어 오를 수 있는 고지대(외곽) — 완만한 경사면을 걸어 정상에 오름
	_walkable_hill(Vector3(18, 0, -16), 7.5, 3.2, 2.0)
	_walkable_hill(Vector3(-20, 0, 14), 8.5, 3.6, 2.8)
	_walkable_hill(Vector3(16, 0, 18), 6.5, 2.8, 1.6)
	_walkable_hill(Vector3(-18, 0, -18), 7.0, 3.0, 2.4)
	# 고대 폐허 군집(엄폐물)
	_ruins(Vector3(8, 0, -4))
	# 맵 경계: 바닥(±30) 끝에서 떨어지지 않도록 보이지 않는 벽
	_boundary(29.0)
	# 장식 산포(나무·바위)로 맵 디자인
	_decorate()
	# 길찾기 내비게이션(부락민이 건물을 돌아서 이동)
	_setup_nav.call_deferred()
	# 분위기 파티클(낮 꽃가루 / 밤 반딧불이)
	_setup_ambient.call_deferred()


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


## === 길찾기 내비게이션 ===
var _nav: NavigationRegion3D = null
var _rebake_pending: bool = false

func _setup_nav() -> void:
	# 지형 정적바디 + 바닥을 내비게이션 소스 그룹에 등록
	var ground := get_parent().get_node_or_null("Ground")
	if ground:
		ground.add_to_group("nav_source")
	for c in get_children():
		if c is StaticBody3D:
			c.add_to_group("nav_source")
	_nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.2
	nm.agent_radius = 0.5
	nm.agent_height = 1.4
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 45.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	nm.geometry_collision_mask = 1 | 16  # 지형(1) + 건물(16)
	_nav.navigation_mesh = nm
	add_child(_nav)
	add_to_group("nav_baker")
	_do_rebake()


## 건물 변경 시 호출(디바운스). 0.4초 뒤 한 번만 재베이크.
func request_rebake() -> void:
	if _rebake_pending or _nav == null:
		return
	_rebake_pending = true
	get_tree().create_timer(0.4).timeout.connect(_do_rebake)


func _do_rebake() -> void:
	_rebake_pending = false
	if _nav and is_instance_valid(_nav):
		_nav.bake_navigation_mesh()  # 스레드 비동기


## === 분위기 파티클 (낮 꽃가루 / 밤 반딧불이) ===
var _ambient_mat: StandardMaterial3D = null

func _setup_ambient() -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.09, 0.09)
	_ambient_mat = StandardMaterial3D.new()
	_ambient_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ambient_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ambient_mat.albedo_color = Color(1.0, 0.96, 0.72, 0.45)
	bm.material = _ambient_mat
	p.mesh = bm
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 5.0
	p.randomness = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(28, 4, 28)
	p.direction = Vector3(0.2, 1.0, 0.1)
	p.spread = 50.0
	p.gravity = Vector3(0, 0.15, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.position = Vector3(0, 3.5, 0)
	add_child(p)
	# 낮/밤 전환에 반응
	var dn := get_tree().get_first_node_in_group("day_night")
	if dn and dn.has_signal("phase_changed"):
		dn.phase_changed.connect(_on_ambient_phase)
		_on_ambient_phase(dn.is_night() if dn.has_method("is_night") else false)


func _on_ambient_phase(is_night: bool) -> void:
	if _ambient_mat == null:
		return
	if is_night:
		# 반딧불이: 발광 노랑-초록
		_ambient_mat.albedo_color = Color(0.7, 1.0, 0.5, 0.95)
		_ambient_mat.emission_enabled = true
		_ambient_mat.emission = Color(0.6, 1.0, 0.4)
		_ambient_mat.emission_energy_multiplier = 2.2
	else:
		# 꽃가루/먼지: 옅은 따뜻함
		_ambient_mat.albedo_color = Color(1.0, 0.96, 0.72, 0.45)
		_ambient_mat.emission_enabled = false


## 외곽선 머티리얼
func _outlined(c: Color) -> StandardMaterial3D:
	var m := _mat(c)
	LowpolyFactory.apply_outline(m)
	return m


## 걸어 오를 수 있는 고지대(원뿔대) — 옆면이 완만해 걸어서 정상에 도달, 윗면은 평평
func _walkable_hill(center: Vector3, base_r: float, top_r: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1   # 지형과 동일 → 플레이어/맹수가 위를 걸음
	body.collision_mask = 0
	add_child(body)
	body.position = center

	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = base_r
	cyl.top_radius = top_r
	cyl.height = height
	cyl.radial_segments = 14
	mi.mesh = cyl
	mi.position.y = height * 0.5
	mi.material_override = _outlined(Color(0.5, 0.42, 0.3))  # 흙 옆면
	body.add_child(mi)

	# 충돌: 원뿔대 볼록 형상 → 경사면을 걸어 오를 수 있음
	var cs := CollisionShape3D.new()
	cs.shape = cyl.create_convex_shape()
	cs.position.y = height * 0.5
	body.add_child(cs)

	# 윗면 잔디 캡(시각)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = top_r * 1.04
	cm.top_radius = top_r * 1.04
	cm.height = 0.14
	cap.mesh = cm
	cap.position.y = height + 0.05
	cap.material_override = _outlined(Color(0.4, 0.6, 0.34))  # 잔디 윗면
	body.add_child(cap)


## 맵 장식 산포: 헥사곤 나무 + 바위 + 연못 수생식물(건물과 통일된 고급 룩, 비충돌)
func _decorate() -> void:
	for _i in 20:
		var a := randf() * TAU
		var r := randf_range(11.0, 26.5)
		_deco(DECO_TREES.pick_random(), Vector3(cos(a) * r, 0.0, sin(a) * r), randf_range(2.6, 3.8))
	for _j in 16:
		var a2 := randf() * TAU
		var r2 := randf_range(9.0, 27.0)
		_deco(DECO_ROCKS.pick_random(), Vector3(cos(a2) * r2, 0.0, sin(a2) * r2), randf_range(0.9, 1.7))
	# 연못((-16,-13), r7) 주변 수생식물
	for _k in 7:
		var a3 := randf() * TAU
		var rr := randf_range(2.0, 6.5)
		_deco(DECO_WATER.pick_random(), Vector3(-16, 0.05, -13) + Vector3(cos(a3) * rr, 0.0, sin(a3) * rr), randf_range(0.5, 0.9))


## 자연 모델 1개 배치(높이에 맞춰 자동 스케일, 랜덤 회전, 비충돌)
func _deco(model_name: String, pos: Vector3, height: float) -> void:
	var path := NATURE + model_name + ".gltf"
	if not ResourceLoader.exists(path):
		return
	var vis: Node3D = LowpolyFactory.build(Vector3(height, height, height), Color.WHITE, path, false)
	add_child(vis)
	vis.position = pos
	vis.rotation.y = randf() * TAU


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
