extends Node3D
## 장식 식생 (콘텐츠 다듬기) — 풀/꽃/자갈을 흩뿌려 정글 분위기
## 상호작용·충돌 없음(순수 시각). 시작 시 한 번 생성.

@export var count: int = 48
@export var area: float = 28.0

const ROCKS := [
	"res://assets/models/hexagon/nature/rock_single_A.gltf",
	"res://assets/models/hexagon/nature/rock_single_B.gltf",
	"res://assets/models/hexagon/nature/rock_single_C.gltf",
	"res://assets/models/hexagon/nature/rock_single_D.gltf",
]


func _ready() -> void:
	for i in count:
		var pos := _rand_pos()
		var r := randf()
		if r < 0.55:
			_grass(pos)
		elif r < 0.8:
			_flower(pos)
		else:
			_pebble(pos)


func _rand_pos() -> Vector3:
	for _i in 8:
		var p := Vector3(randf_range(-area, area), 0.0, randf_range(-area, area))
		if p.length() > 4.0:
			return p
	return Vector3(area, 0, area)


func _mat(c: Color, outline: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if outline:
		LowpolyFactory.apply_outline(m)
	return m


func _grass(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	var col := Color(0.32, 0.55, 0.26).lightened(randf() * 0.12)
	for j in 3:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, randf_range(0.5, 0.95), 0.1)
		mi.mesh = bm
		mi.position = Vector3(randf_range(-0.15, 0.15), bm.size.y * 0.5, randf_range(-0.15, 0.15))
		mi.rotation.z = randf_range(-0.2, 0.2)
		mi.material_override = _mat(col)
		node.add_child(mi)


func _flower(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	var stem := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.08, 0.45, 0.08)
	stem.mesh = sm
	stem.position.y = 0.225
	stem.material_override = _mat(Color(0.3, 0.5, 0.25), true)
	node.add_child(stem)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.28, 0.18, 0.28)
	top.mesh = tm
	top.position.y = 0.52
	var colors := [Color(0.9, 0.4, 0.5), Color(0.95, 0.8, 0.3), Color(0.7, 0.5, 0.9), Color(0.95, 0.95, 0.95)]
	top.material_override = _mat(colors[randi() % colors.size()], true)
	node.add_child(top)


func _pebble(pos: Vector3) -> void:
	# 납작한 박스 → 헥사곤 로우폴리 바위 모델(지형의 바위들과 톤 일치)
	var path: String = ROCKS[randi() % ROCKS.size()]
	var s := randf_range(0.35, 0.7)
	var rock: Node3D = LowpolyFactory.build(Vector3(s, s, s), Color.WHITE, path, false)
	rock.position = pos
	rock.rotation.y = randf() * TAU
	add_child(rock)
