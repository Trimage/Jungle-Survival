extends Control
## 타이틀/메인 메뉴 (콘텐츠 추천)
## - 새 게임 / 이어하기(최근 저장) / 종료

const MetaShopScene := preload("res://ui/meta_shop.tscn")

@onready var _new_btn: Button = $Center/VBox/NewGame
@onready var _continue_btn: Button = $Center/VBox/Continue
@onready var _quit_btn: Button = $Center/VBox/Quit

var _shop: Control = null


var _diorama: Node3D = null


func _ready() -> void:
	_setup_background()
	_continue_btn.disabled = SaveManager.latest_slot() == -999
	_new_btn.pressed.connect(_on_new)
	_continue_btn.pressed.connect(_on_continue)
	_quit_btn.pressed.connect(func(): get_tree().quit())

	# 유산의 제단(메타 강화 상점) 버튼을 메뉴에 추가
	var altar := Button.new()
	altar.text = "유산의 제단"
	altar.custom_minimum_size = _quit_btn.custom_minimum_size
	var vbox := $Center/VBox
	vbox.add_child(altar)
	vbox.move_child(altar, _quit_btn.get_index())  # 종료 버튼 바로 위
	altar.pressed.connect(_open_shop)


func _process(delta: float) -> void:
	if _diorama:
		_diorama.rotation.y += delta * 0.3


## 3D 디오라마 배경(회전하는 기사 + 집 + 나무)
func _setup_background() -> void:
	# 기존 단색 배경을 끄고 3D 디오라마로 대체
	var bg := get_node_or_null("BG")
	if bg:
		bg.visible = false
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	move_child(svc, 0)  # UI 뒤에 배치
	var sv := SubViewport.new()
	sv.size = Vector2i(540, 960)
	svc.add_child(sv)

	var world := Node3D.new()
	sv.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.86, 0.8)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.75, 0.62)
	env.fog_density = 0.02
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -45, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 6.0
	pm.bottom_radius = 6.0
	pm.height = 0.5
	ground.mesh = pm
	ground.position.y = -0.25
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.62, 0.36)
	ground.material_override = gm
	world.add_child(ground)

	_diorama = Node3D.new()
	world.add_child(_diorama)
	_add_model("res://assets/models/kaykit/Knight.glb", Vector3(0, 0, 0), 1.8)
	_add_model("res://assets/models/hexagon/building_home_A_green.gltf", Vector3(2.6, 0, -1.6), 2.6)
	_add_model("res://assets/models/hexagon/nature/tree_single_A.gltf", Vector3(-2.6, 0, -1.0), 3.2)
	_add_model("res://assets/models/hexagon/nature/tree_single_B.gltf", Vector3(2.0, 0, 2.0), 2.6)
	_add_model("res://assets/models/hexagon/nature/rock_single_A.gltf", Vector3(-2.2, 0, 1.8), 1.2)

	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 3.4, 7.2)
	cam.look_at(Vector3(0, 1.1, 0), Vector3.UP)
	cam.current = true  # 서브뷰포트가 이 카메라로 렌더


func _add_model(path: String, pos: Vector3, height: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var vis: Node3D = LowpolyFactory.build(Vector3(height, height, height), Color.WHITE, path, false)
	_diorama.add_child(vis)
	vis.position = pos


## 큰 타이틀 텍스트
func _setup_title_text() -> void:
	var lbl := Label.new()
	lbl.text = "초록의 무덤"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 72)
	lbl.add_theme_color_override("font_color", Color(0.92, 1.0, 0.9))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.12))
	lbl.add_theme_constant_override("outline_size", 12)
	lbl.anchor_left = 0.0
	lbl.anchor_right = 1.0
	lbl.anchor_top = 0.0
	lbl.offset_top = 90
	lbl.offset_bottom = 180
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var sub := Label.new()
	sub.text = "Verdant Tomb — 정글에 삼켜진 폐허에서 살아남아라"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	sub.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.12))
	sub.add_theme_constant_override("outline_size", 6)
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.anchor_top = 0.0
	sub.offset_top = 178
	sub.offset_bottom = 210
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)


func _open_shop() -> void:
	if _shop == null:
		_shop = MetaShopScene.instantiate()
		add_child(_shop)
	_shop.open()


func _on_new() -> void:
	GameState.reset_for_new_game()
	GameState.pending_intro = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_continue() -> void:
	GameState.reset_for_new_game()
	GameState.pending_load_slot = SaveManager.latest_slot()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
