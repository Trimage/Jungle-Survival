extends Node3D
## 떠돌이 상인 — 가끔 등장해 잠시 머무름. 다가가 [행동]으로 거래(HUD 상인 패널).
## 그룹 "merchant", 수명이 다하면 떠남.

var _life: float = 80.0


func _ready() -> void:
	add_to_group("merchant")
	_build_visual()


func _build_visual() -> void:
	# 후드 쓴 떠돌이 상인(KayKit 캐릭터) + 발밑 그림자
	var model := "res://assets/models/kaykit/Rogue_Hooded.glb"
	if ResourceLoader.exists(model):
		var vis: Node3D = LowpolyFactory.build(Vector3(0.85, 1.7, 0.85), Color.WHITE, model, false)
		LowpolyFactory.outline_model(vis)  # 카툰 외곽선
		add_child(vis)
		add_child(LowpolyFactory.make_blob_shadow(0.45))
	else:
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
