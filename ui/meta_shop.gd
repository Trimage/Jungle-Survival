extends Control
## 유산의 제단 — 로그라이트 메타 강화 상점(재사용 가능, 타이틀/사망 화면에서 인스턴스)
## - MetaManager.currency 로 data/meta_upgrades.json 강화를 구매.
## - 구매 효과는 다음 새 게임 시작 시 player.apply_meta_start() 에서 적용됨.

signal closed

var _currency_label: Label
var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.74)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(580, 0)
	margin.add_child(vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.text = "💠 유산의 제단"
	vb.add_child(title)

	_currency_label = Label.new()
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(_currency_label)

	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.text = "강화는 다음 새 게임부터 적용됩니다"
	vb.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(0, 52)
	close_btn.pressed.connect(func(): visible = false; closed.emit())
	vb.add_child(close_btn)


## 표시 + 최신 상태 반영
func open() -> void:
	visible = true
	_refresh()


func _refresh() -> void:
	_currency_label.text = "보유 유산: 💠 %d" % MetaManager.currency
	for c in _list.get_children():
		c.queue_free()
	for id in ItemDB.meta_upgrades:
		_list.add_child(_make_row(id))


func _make_row(id: String) -> Control:
	var def: Dictionary = ItemDB.meta_def(id)
	var lv: int = MetaManager.level_of(id)
	var maxlv: int = int(def.get("max", 1))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 17)
	info.text = "%s %s  [%d/%d]\n%s" % [def.get("icon", "•"), def.get("name", id), lv, maxlv, def.get("desc", "")]
	row.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 56)
	if MetaManager.is_max(id):
		btn.text = "MAX"
		btn.disabled = true
	else:
		btn.text = "💠 %d" % MetaManager.cost_of(id)
		btn.disabled = not MetaManager.can_buy(id)
		btn.pressed.connect(func():
			if MetaManager.buy(id):
				_refresh())
	row.add_child(btn)
	return row
