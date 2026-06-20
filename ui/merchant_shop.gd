extends Control
## 떠돌이 상인 거래 패널(재사용 Control) — ItemDB.trades 를 자원으로 교환.

signal closed

var _inv: Node = null
var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
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
	vb.custom_minimum_size = Vector2(560, 0)
	margin.add_child(vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.text = "🛒 떠돌이 상인"
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
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


func open(inv: Node) -> void:
	_inv = inv
	visible = true
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for trade in ItemDB.trades:
		_list.add_child(_make_row(trade))


func _make_row(trade: Dictionary) -> Control:
	var give: Dictionary = trade.get("give", {})
	var get_d: Dictionary = trade.get("get", {})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 17)
	info.text = "%s  →  %s" % [ItemDB.cost_text(give), ItemDB.cost_text(get_d)]
	row.add_child(info)

	var btn := Button.new()
	btn.text = "거래"
	btn.custom_minimum_size = Vector2(110, 52)
	btn.disabled = _inv == null or not _inv.can_afford(give)
	btn.pressed.connect(func():
		if _inv and _inv.can_afford(give):
			_inv.spend(give)
			for id in get_d:
				_inv.add_item(id, int(get_d[id]))
			AudioManager.play("craft")
			_refresh())
	row.add_child(btn)
	return row
