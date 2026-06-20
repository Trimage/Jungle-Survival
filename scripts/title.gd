extends Control
## 타이틀/메인 메뉴 (콘텐츠 추천)
## - 새 게임 / 이어하기(최근 저장) / 종료

const MetaShopScene := preload("res://ui/meta_shop.tscn")

@onready var _new_btn: Button = $Center/VBox/NewGame
@onready var _continue_btn: Button = $Center/VBox/Continue
@onready var _quit_btn: Button = $Center/VBox/Quit

var _shop: Control = null


func _ready() -> void:
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
