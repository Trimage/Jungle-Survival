extends Node3D
## 떠돌이 상인 — 가끔 등장해 잠시 머무름. 다가가 [행동]으로 거래(HUD 상인 패널).
## 그룹 "merchant", 수명이 다하면 떠남.

var _life: float = 80.0


func _ready() -> void:
	add_to_group("merchant")
	_build_visual()


func _build_visual() -> void:
	# 로브 입은 상인(파란 몸통 + 머리 + 등짐) — 마을 사람과 구별되는 색
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.5
	body.mesh = cap
	body.position.y = 0.75
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.3, 0.45, 0.75)
	body.material_override = bm
	add_child(body)

	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.45, 0.45, 0.45)
	head.mesh = hb
	head.position.y = 1.6
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.9, 0.78, 0.62)
	head.material_override = hm
	add_child(head)

	var pack := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.7, 0.7, 0.45)
	pack.mesh = pb
	pack.position = Vector3(0, 1.0, -0.45)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.55, 0.38, 0.2)
	pack.material_override = pm
	add_child(pack)

	# 머리 위 안내 표식
	var sign := Label3D.new()
	sign.text = "🛒 상인"
	sign.position.y = 2.3
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.modulate = Color(1.0, 0.9, 0.5)
	add_child(sign)


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_leave()


func _leave() -> void:
	GameState.spawn_puff(global_position, Color(0.4, 0.55, 0.8), 14)
	GameState.spawn_text(global_position, "상인이 떠났다…", Color(0.7, 0.8, 0.95))
	queue_free()
