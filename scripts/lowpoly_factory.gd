class_name LowpolyFactory
extends RefCounted
## 로우폴리 비주얼 팩토리 (M7 + 확장)
## - model(.glb 경로)이 있으면 외부 모델, 없으면 shape 에 맞는 합성 로우폴리 메시 생성
##   shape: "box"(기본) / "capsule" / "tree"(기둥+잎) / "creature"(몸통+머리+다리) / "segmented"(마디)
## - last_material: 피격 플래시용 본체 머티리얼(외부 모델이면 null)

static var last_material: StandardMaterial3D = null


static func build(size: Vector3, color: Color, model_path: String, ghost: bool, shape: String = "box") -> Node3D:
	last_material = null

	# 외부 모델(.glb) 우선 — 슬롯 size 에 맞춰 자동 스케일 + 바닥 정렬
	if model_path != "" and ResourceLoader.exists(model_path):
		var inst: Node3D = load(model_path).instantiate()
		_fit_to_size(inst, size)
		_play_idle(inst)  # 리깅 모델이면 Idle 애니메이션 루프(T포즈 방지)
		return inst

	match shape:
		"capsule":
			return _capsule(size, color)
		"tree":
			return _tree(size, color)
		"creature":
			return _creature(size, color)
		"segmented":
			return _segmented(size, color)
		_:
			return _box(size, color, ghost)


# --- 기본 박스 ---
static func _box(size: Vector3, color: Color, ghost: bool) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position.y = size.y * 0.5
	mi.material_override = _mat(color, ghost)
	last_material = mi.material_override
	return mi


static func _capsule(size: Vector3, color: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = minf(size.x, size.z) * 0.5
	cap.height = size.y
	mi.mesh = cap
	mi.position.y = size.y * 0.5
	mi.material_override = _mat(color, false)
	last_material = mi.material_override
	return mi


# --- 나무: 기둥 + 잎 더미 ---
static func _tree(size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = size.x * 0.18
	tm.bottom_radius = size.x * 0.22
	tm.height = size.y * 0.5
	trunk.mesh = tm
	trunk.position.y = size.y * 0.25
	trunk.material_override = _mat(Color(0.45, 0.32, 0.2), false)
	root.add_child(trunk)

	# 잎: 두 개의 박스를 겹쳐 또렷한 로우폴리 실루엣
	var f1 := _leaf_blob(Vector3(size.x * 1.1, size.y * 0.42, size.z * 1.1), Vector3(0, size.y * 0.62, 0), color)
	root.add_child(f1)
	var f2 := _leaf_blob(Vector3(size.x * 0.8, size.y * 0.34, size.z * 0.8), Vector3(0, size.y * 0.9, 0), color.lightened(0.08))
	root.add_child(f2)
	last_material = f1.material_override
	return root


static func _leaf_blob(sz: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color, false)
	return mi


# --- 네발짐승: 몸통 + 머리 + 다리 4 ---
static func _creature(size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	var leg_h := size.y * 0.35
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, size.y * 0.6, size.z * 0.85)
	body.mesh = bm
	body.position.y = leg_h + size.y * 0.3
	body.material_override = _mat(color, false)
	root.add_child(body)
	last_material = body.material_override

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(size.x * 0.7, size.y * 0.55, size.z * 0.3)
	head.mesh = hm
	head.position = Vector3(0, leg_h + size.y * 0.35, size.z * 0.5)
	head.material_override = _mat(color.darkened(0.1), false)
	root.add_child(head)

	# 다리
	var lx := size.x * 0.32
	var lz := size.z * 0.3
	for sx in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(size.x * 0.22, leg_h, size.z * 0.18)
			leg.mesh = lm
			leg.position = Vector3(sx * lx, leg_h * 0.5, sz2 * lz)
			leg.material_override = _mat(color.darkened(0.18), false)
			root.add_child(leg)
	return root


# --- 뱀/보스: 점점 작아지는 마디들 ---
static func _segmented(size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	var segs := 6
	var radius := minf(size.x, size.y) * 0.5
	var seg_len := size.z / float(segs)
	for i in segs:
		var t := float(i) / float(segs - 1)
		var scale := lerpf(1.0, 0.45, t)  # 머리(앞) 크고 꼬리 작게
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = radius * scale
		sm.height = radius * 2.0 * scale
		mi.mesh = sm
		# 앞(+z)이 머리: i=0 이 머리가 되도록 z 배치
		mi.position = Vector3(0, radius * scale, size.z * 0.5 - seg_len * (i + 0.5))
		mi.material_override = _mat(color.darkened(0.04 * i), false)
		root.add_child(mi)
		if i == 0:
			last_material = mi.material_override
	return root


## 외부 모델을 슬롯 크기(size)에 맞게 균일 스케일하고, 바닥이 y=0 에 닿도록 정렬
static func _fit_to_size(inst: Node3D, size: Vector3) -> void:
	var box := _node_aabb(inst, Transform3D.IDENTITY)
	if box.size.y <= 0.0001:
		return
	var s: float = size.y / box.size.y
	inst.scale = Vector3(s, s, s)
	var center_x: float = box.position.x + box.size.x * 0.5
	var center_z: float = box.position.z + box.size.z * 0.5
	inst.position = Vector3(-center_x * s, -box.position.y * s, -center_z * s)


## 노드 트리의 메시 AABB를 누적(루트 로컬 공간 기준)
static func _node_aabb(n: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var has := false
	if n is Node3D:
		xform = xform * n.transform
	if n is MeshInstance3D and n.mesh != null:
		box = xform * n.get_aabb()
		has = true
	for c in n.get_children():
		var cb := _node_aabb(c, xform)
		if cb.size != Vector3.ZERO:
			box = cb if not has else box.merge(cb)
			has = true
	return box


static func _mat(color: Color, ghost: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	mat.metallic = 0.0
	if ghost:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	else:
		mat.albedo_color = color
		apply_outline(mat)
	return mat


## 카툰 외곽선(인버티드 헐) 머티리얼 — 셰이더 없이 next_pass 로 검은 테두리
static func make_outline() -> StandardMaterial3D:
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = Color(0.06, 0.06, 0.09)
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = 0.04
	return o


## 머티리얼에 외곽선 패스를 더한다(이미 있으면 생략)
static func apply_outline(mat: StandardMaterial3D) -> void:
	if mat and mat.next_pass == null:
		mat.next_pass = make_outline()


## 리깅된 .glb의 Idle 애니메이션을 찾아 루프 재생(T포즈 방지)
static func _play_idle(root: Node) -> void:
	var ap := _find_anim_player(root)
	if ap == null:
		return
	var names := ap.get_animation_list()
	if names.is_empty():
		return
	var chosen := ""
	if "Idle" in names:
		chosen = "Idle"
	else:
		for n in names:
			if "idle" in String(n).to_lower():
				chosen = n
				break
	if chosen == "":
		chosen = names[0]
	var anim := ap.get_animation(chosen)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(chosen)


static func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null


## 발밑 블롭 그림자(둥근 반투명 디스크) — 토이 같은 하이퍼캐주얼 접지감
static func make_blob_shadow(radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 18
	mi.mesh = cyl
	mi.position.y = 0.03
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.0, 0.0, 0.0, 0.26)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
