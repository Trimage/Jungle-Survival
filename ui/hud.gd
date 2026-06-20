extends CanvasLayer
## HUD (M2 + M3 + M4)
## - 생존 스탯 게이지 / 낮·밤·Day (M2)
## - 인벤토리 슬롯 그리드 + 채집 토스트 / 액션버튼→채집 (M3)
## - 제작창 + 건설 메뉴(데이터 기반) + 건설 모드 확정/취소 (M4)
##   노드 _ready 순서 문제로 못 찾으면 _process 에서 지연 연결

@onready var _stats_box: VBoxContainer = $StatsPanel/Margin/Bars
@onready var _day_label: Label = $DayLabel
@onready var _village_label: Label = $VillageLabel
@onready var _action_button: Button = $ActionButton
@onready var _dodge_button: Button = $DodgeButton
@onready var _death_overlay: Control = $DeathOverlay
@onready var _revive_button: Button = $DeathOverlay/VBox/ReviveButton
@onready var _inv_button: Button = $InventoryButton
@onready var _craft_button: Button = $CraftButton
@onready var _build_button: Button = $BuildButton
@onready var _inv_panel: PanelContainer = $InventoryPanel
@onready var _inv_grid: GridContainer = $InventoryPanel/Margin/VBox/Grid
@onready var _craft_panel: PanelContainer = $CraftPanel
@onready var _craft_list: VBoxContainer = $CraftPanel/Margin/VBox/List
@onready var _build_panel: PanelContainer = $BuildPanel
@onready var _build_list: VBoxContainer = $BuildPanel/Margin/VBox/List
@onready var _build_controls: HBoxContainer = $BuildControls
@onready var _build_hint: Label = $BuildHint
@onready var _confirm_button: Button = $BuildControls/ConfirmButton
@onready var _cancel_button: Button = $BuildControls/CancelButton
@onready var _toast: Label = $Toast
@onready var _boss_bar: VBoxContainer = $BossBar
@onready var _boss_name: Label = $BossBar/BossName
@onready var _boss_hp: ProgressBar = $BossBar/BossHP
@onready var _save_button: Button = $SaveButton
@onready var _load_button: Button = $LoadButton
@onready var _help_button: Button = $HelpButton
@onready var _help_panel: PanelContainer = $HelpPanel
@onready var _help_close: Button = $HelpPanel/Margin/VBox/CloseButton
@onready var _volume_slider: HSlider = $HelpPanel/Margin/VBox/VolumeSlider
@onready var _music_slider: HSlider = $HelpPanel/Margin/VBox/MusicSlider
@onready var _sfx_slider: HSlider = $HelpPanel/Margin/VBox/SfxSlider
@onready var _haptics_check: CheckButton = $HelpPanel/Margin/VBox/HapticsCheck
@onready var _ending_overlay: Control = $EndingOverlay
@onready var _ending_result: Button = $EndingOverlay/VBox/ResultButton
@onready var _tut_label: Label = $TutorialHint
@onready var _victory_overlay: Control = $VictoryOverlay
@onready var _victory_continue: Button = $VictoryOverlay/VBox/ContinueButton
@onready var _victory_restart: Button = $VictoryOverlay/VBox/RestartButton
@onready var _pause_button: Button = $PauseButton
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _pause_resume: Button = $PauseOverlay/VBox/ResumeButton
@onready var _pause_restart: Button = $PauseOverlay/VBox/PauseRestartButton
@onready var _boss_banner: Label = $BossBanner
@onready var _death_label: Label = $DeathOverlay/VBox/DeathLabel
@onready var _win_label: Label = $VictoryOverlay/VBox/WinLabel
@onready var _save_panel: PanelContainer = $SavePanel
@onready var _slot_list: VBoxContainer = $SavePanel/Margin/VBox/SlotList
@onready var _save_close: Button = $SavePanel/Margin/VBox/CloseButton
@onready var _rally_button: Button = $RallyButton
@onready var _event_tint: ColorRect = $EventTint
@onready var _intro_overlay: Control = $IntroOverlay
@onready var _intro_start: Button = $IntroOverlay/VBox/StartButton

const MetaShopScene := preload("res://ui/meta_shop.tscn")
var _meta_shop: Control = null
const MerchantShopScene := preload("res://ui/merchant_shop.tscn")
var _merchant_shop: Control = null
var _continuous_btn: Button = null  # 연속(드래그) 건설 토글

# 주기적 자동저장
const AUTOSAVE_INTERVAL := 60.0
var _autosave_timer: float = AUTOSAVE_INTERVAL

# 퀘스트 / 연구 패널
var _quest_overlay: Control
var _quest_list: VBoxContainer
var _research_overlay: Control
var _research_list: VBoxContainer

var _bars: Dictionary = {}
var _stats: Node = null
var _daynight: Node = null
var _inventory: Node = null
var _player: Node = null
var _builder: Node = null
var _spawner: Node = null
var _connected: bool = false
var _player_wired: bool = false
var _toast_tween: Tween

# === 성장(레벨/경험치) UI — 코드로 생성 ===
var _xp_bar: ProgressBar
var _xp_label: Label
var _levelup_overlay: Control
var _levelup_title: Label
var _levelup_choices: VBoxContainer
var _pending_levels: int = 0
var _levelup_showing: bool = false
# === 가독성: 야간 습격 경고 ===
var _raid_label: Label
# === 연속 처치 콤보 ===
var _combo_label: Label
var _raid_warned_day: int = -1
const RAID_LEAD := 18.0  # 밤까지 이 시간 이하로 남으면 경고

# 튜토리얼 단계: 0이동 1채집 2제작/건설 3영입 4밤 5완료
var _tut_step: int = 0
const TUT_TEXT := [
	"왼쪽 화면을 드래그해 이동해 보세요",
	"나무·약초 근처에서 [행동]으로 자원을 채집하세요",
	"[제작]으로 도구를, [건설]로 모닥불을 지어보세요",
	"회색 떠돌이에게 다가가 [행동]으로 영입하세요",
	"밤이 옵니다! 맹수는 [행동]으로 공격, [회피]로 피하세요",
]


func _ready() -> void:
	_build_bars()
	_inv_panel.visible = false
	_craft_panel.visible = false
	_build_panel.visible = false
	_build_controls.visible = false
	_build_hint.visible = false
	_toast.modulate.a = 0.0
	_death_overlay.visible = false
	_boss_bar.visible = false

	# 저장/불러오기(슬롯 패널) + 도움말 + 집결
	_save_panel.visible = false
	_save_button.pressed.connect(_open_save_panel)
	_load_button.pressed.connect(_open_save_panel)
	_save_close.pressed.connect(func(): _save_panel.visible = false)
	_rally_button.pressed.connect(_toggle_rally)
	_help_panel.visible = false
	_help_button.pressed.connect(func(): _help_panel.visible = not _help_panel.visible)
	_help_close.pressed.connect(func(): _help_panel.visible = false)
	_volume_slider.value_changed.connect(func(v): AudioManager.set_master_volume(v))
	_music_slider.value_changed.connect(func(v): AudioManager.set_music_volume(v))
	_sfx_slider.value_changed.connect(func(v): AudioManager.set_sfx_volume(v))
	_haptics_check.toggled.connect(func(on): GameState.haptics_enabled = on)
	_ending_overlay.visible = false
	_ending_result.pressed.connect(func(): _ending_overlay.visible = false; _victory_overlay.visible = true)
	_tut_label.text = TUT_TEXT[0]

	# 승리 / 보스 처치
	_victory_overlay.visible = false
	GameState.victory.connect(_on_victory)
	GameState.boss_defeated.connect(func(n): _flash_banner("🎉 %s 격파!" % n); GameState.vibrate(200))
	GameState.villager_died.connect(func(n): _show_toast("💀 부락민 사망: %s" % n))
	GameState.boss_incoming.connect(_on_boss_incoming)
	GameState.boss_enrage.connect(func(n): _flash_banner("🔥 %s 분노! 🔥" % n))
	GameState.achievement.connect(func(t): _show_toast("🏆 업적: %s" % t))
	GameState.event_changed.connect(_on_event_changed)
	_boss_banner.modulate.a = 0.0

	# 새 게임 인트로(스토리)
	if GameState.pending_intro:
		GameState.pending_intro = false
		_intro_overlay.visible = true
		get_tree().paused = true
	else:
		_intro_overlay.visible = false
	_intro_start.pressed.connect(func(): _intro_overlay.visible = false; get_tree().paused = false)
	_victory_continue.pressed.connect(func(): _victory_overlay.visible = false)
	_victory_restart.pressed.connect(func(): GameState.reset_for_new_game(); get_tree().reload_current_scene())

	# 일시정지 (HUD는 정지 중에도 동작해야 버튼이 먹힘)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.visible = false
	_pause_button.pressed.connect(func(): _set_pause(true))
	_pause_resume.pressed.connect(func(): _set_pause(false))
	_pause_restart.pressed.connect(func(): _set_pause(false); GameState.reset_for_new_game(); get_tree().reload_current_scene())

	# 위치 초기화 버튼(일시정지 메뉴) — 끼임/길잃음 해소
	var reset_btn := Button.new()
	reset_btn.text = "📍 위치 초기화"
	reset_btn.custom_minimum_size = Vector2(0, 52)
	var pvbox: VBoxContainer = $PauseOverlay/VBox
	pvbox.add_child(reset_btn)
	pvbox.move_child(reset_btn, _pause_restart.get_index())  # 재시작 위에
	reset_btn.pressed.connect(func():
		if is_instance_valid(_player) and _player.has_method("reset_position"):
			_player.reset_position()
		_set_pause(false)
		_show_toast("📍 위치 초기화"))

	# 메뉴 토글
	_inv_button.pressed.connect(func(): _toggle_panel(_inv_panel))
	_craft_button.pressed.connect(_open_craft)
	_build_button.pressed.connect(_open_build)
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_cancel)

	# 연속(드래그) 건설 토글 — 켜면 걸어다니며 벽이 자동 설치됨
	_continuous_btn = Button.new()
	_continuous_btn.toggle_mode = true
	_continuous_btn.text = "연속 OFF"
	_continuous_btn.custom_minimum_size = Vector2(128, 0)
	_build_controls.add_child(_continuous_btn)
	_continuous_btn.toggled.connect(func(on):
		if _builder:
			_builder.set_continuous(on)
		_continuous_btn.text = "연속 ON" if on else "연속 OFF")

	# 건설 패널: 건물 이동 / 회수 버튼
	var bvbox: VBoxContainer = $BuildPanel/Margin/VBox
	var move_btn := Button.new()
	move_btn.text = "🔧 건물 이동"
	move_btn.custom_minimum_size = Vector2(0, 46)
	bvbox.add_child(move_btn)
	bvbox.move_child(move_btn, _build_list.get_index())
	move_btn.pressed.connect(func():
		_build_panel.visible = false
		if _builder and not _builder.start_move():
			_show_toast("이동할 건물이 근처에 없어요"))
	var store_btn := Button.new()
	store_btn.text = "📦 건물 회수 (자원 환급)"
	store_btn.custom_minimum_size = Vector2(0, 46)
	bvbox.add_child(store_btn)
	bvbox.move_child(store_btn, _build_list.get_index())
	store_btn.pressed.connect(func():
		_build_panel.visible = false
		if _builder and _builder.store_building():
			_show_toast("📦 건물 회수 · 자원 환급")
		else:
			_show_toast("회수할 건물이 근처에 없어요"))
	_revive_button.pressed.connect(func(): if is_instance_valid(_player): _player.respawn())

	# 사망 화면에 유산의 제단(메타 상점) 버튼 추가
	var altar := Button.new()
	altar.text = "💠 유산의 제단"
	altar.custom_minimum_size = Vector2(0, 52)
	$DeathOverlay/VBox.add_child(altar)
	altar.pressed.connect(_open_meta_shop)

	_build_craft_list()
	_build_build_list()

	# 성장 시스템 + 가독성 UI
	_build_progression_ui()
	_build_threat_layer()
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.level_up.connect(_on_level_up)
	GameState.perk_chosen.connect(func(n): _show_toast("⭐ 퍽 획득: %s" % n))
	GameState.combo_changed.connect(_on_combo_changed)
	_on_xp_changed(GameState.xp, GameState.xp_to_next, GameState.level)

	# 퀘스트/연구 패널 + 도움말 패널에 진입 버튼
	_build_quest_research_ui()
	GameState.quest_completed.connect(func(qn, rw): _show_toast("🎯 목표 달성: %s (보상 %s)" % [qn, rw]); GameState.vibrate(80))
	GameState.research_changed.connect(func(): _build_build_list(); _build_craft_list())


func _process(delta: float) -> void:
	if not _connected:
		_try_connect()
	_update_boss_bar()
	_update_raid_warning()
	_tick_autosave(delta)
	# 부락민 수 + 현재 목표 표시
	var day: int = _daynight.day if _daynight else 1
	var boss_alive: bool = get_tree().get_first_node_in_group("boss") != null
	var cap: int = _spawner.get_pop_cap() if (_spawner and _spawner.has_method("get_pop_cap")) else 0
	var recruited: int = get_tree().get_nodes_in_group("recruited").size()
	_village_label.text = "부락민: %d (정원 %d)   🎯 %s" % [recruited, cap, GameState.objective_text(day, boss_alive)]
	# 튜토리얼 0단계: 이동 감지
	if _tut_step == 0:
		var joy: Node = get_tree().get_first_node_in_group("joystick")
		if joy and joy.has_method("get_output") and joy.get_output().length() > 0.2:
			_tut_reach(1)


## 튜토리얼을 step 단계까지 진행(앞으로만)
func _tut_reach(step: int) -> void:
	if _tut_step >= step:
		return
	_tut_step = step
	if _tut_step >= TUT_TEXT.size():
		_tut_label.visible = false
	else:
		_tut_label.text = TUT_TEXT[_tut_step]


# 보스 그룹을 폴링해 체력바 표시/갱신
func _update_boss_bar() -> void:
	var boss: Node = get_tree().get_first_node_in_group("boss")
	if boss and boss.has_method("get_health"):
		_boss_bar.visible = true
		_boss_name.text = boss.get_display_name()
		_boss_hp.max_value = boss.get_max_health()
		_boss_hp.value = boss.get_health()
	else:
		_boss_bar.visible = false


func _open_save_panel() -> void:
	_build_slot_list()
	_toggle_panel(_save_panel)


func _build_slot_list() -> void:
	for c in _slot_list.get_children():
		c.queue_free()
	# 자동저장 불러오기
	if SaveManager.has_save(-1):
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 12)
		var al := Label.new()
		al.text = "자동저장"
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arow.add_child(al)
		var ab := Button.new()
		ab.text = "불러오기"
		ab.custom_minimum_size = Vector2(110, 40)
		ab.pressed.connect(_on_slot_load.bind(-1))
		arow.add_child(ab)
		_slot_list.add_child(arow)
	# 수동 슬롯
	for s in range(SaveManager.SLOT_COUNT):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lbl := Label.new()
		lbl.text = "슬롯 %d  ·  %s" % [s + 1, "있음" if SaveManager.has_save(s) else "비어있음"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var sb := Button.new()
		sb.text = "저장"
		sb.custom_minimum_size = Vector2(86, 40)
		sb.pressed.connect(_on_slot_save.bind(s))
		row.add_child(sb)
		var lb := Button.new()
		lb.text = "불러오기"
		lb.custom_minimum_size = Vector2(110, 40)
		lb.disabled = not SaveManager.has_save(s)
		lb.pressed.connect(_on_slot_load.bind(s))
		row.add_child(lb)
		_slot_list.add_child(row)


func _on_slot_save(slot: int) -> void:
	if SaveManager.save_game(slot):
		_show_toast("슬롯 %d 저장됨" % (slot + 1))
		_build_slot_list()


func _on_slot_load(slot: int) -> void:
	if SaveManager.load_game(slot):
		_show_toast("불러옴")
		_save_panel.visible = false


func _toggle_rally() -> void:
	GameState.rally_active = not GameState.rally_active
	_rally_button.text = "집결 해제" if GameState.rally_active else "집결"
	_show_toast("부락민 집결" if GameState.rally_active else "집결 해제")


# === M2: 생존 스탯 게이지 ===
func _build_bars() -> void:
	for key in SurvivalStats.STAT_DEFS:
		var def: Dictionary = SurvivalStats.STAT_DEFS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var label := Label.new()
		label.text = "%s %s" % [def.get("icon", ""), def["name"]]
		label.custom_minimum_size = Vector2(82, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = def["max"]
		bar.value = def["start"]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(180, 18)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var fill := StyleBoxFlat.new()
		fill.bg_color = def["color"]
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)

		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.35)
		bg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg)

		row.add_child(bar)
		_stats_box.add_child(row)
		_bars[key] = bar


# === 시그널 연결(지연) ===
func _try_connect() -> void:
	if _stats == null:
		_stats = get_tree().get_first_node_in_group("survival_stats")
		if _stats:
			_stats.stat_changed.connect(_on_stat_changed)
			_stats.died.connect(_on_died)
	if _daynight == null:
		_daynight = get_tree().get_first_node_in_group("day_night")
		if _daynight:
			_daynight.time_changed.connect(_on_time_changed)
			_daynight.day_advanced.connect(_on_day_advanced)
	if _inventory == null:
		_inventory = get_tree().get_first_node_in_group("inventory")
		if _inventory:
			_inventory.changed.connect(_on_inventory_changed)
			_inventory.item_added.connect(_on_item_added)
			_rebuild_inventory()
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player and not _player_wired:
			_action_button.pressed.connect(func(): if is_instance_valid(_player): _player.action())
			_dodge_button.pressed.connect(func(): if is_instance_valid(_player): _player.dodge())
			_player.player_died.connect(_on_player_died)
			_player.player_respawned.connect(_on_player_respawned)
			_player.villager_recruited.connect(_on_villager_recruited)
			_player.villager_job_changed.connect(_on_villager_job_changed)
			_player.harvested.connect(func(_n, _y): _tut_reach(2))
			_player.request_merchant.connect(_open_merchant_shop)
			_player_wired = true
	if _builder == null:
		_builder = get_tree().get_first_node_in_group("build_manager")
		if _builder:
			_builder.build_mode_changed.connect(_on_build_mode_changed)
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawn_manager")
		if _spawner:
			_spawner.wave_spawned.connect(_on_wave_spawned)

	if _stats and _daynight and _inventory and _player and _builder and _spawner:
		_connected = true
		# 타이틀의 "이어하기"로 들어왔으면 해당 슬롯 로드, 아니면 새 게임 → 영구 메타 강화 적용
		if GameState.pending_load_slot != -999:
			SaveManager.load_game(GameState.pending_load_slot)
			GameState.pending_load_slot = -999
		elif is_instance_valid(_player) and _player.has_method("apply_meta_start"):
			_player.apply_meta_start()


var _warned: Dictionary = {}

func _on_stat_changed(key: String, value: float, max_value: float) -> void:
	if _bars.has(key):
		_bars[key].value = value
	# 생존 스탯 위급 경고(중복 방지: 회복하면 리셋)
	if key in ["health", "hunger", "thirst"] and max_value > 0.0:
		var ratio: float = value / max_value
		if ratio <= 0.2 and not _warned.get(key, false):
			_warned[key] = true
			_show_toast("⚠ %s 위험!" % SurvivalStats.STAT_DEFS[key]["name"])
			AudioManager.play("player_hurt")
		elif ratio >= 0.35:
			_warned[key] = false


func _on_time_changed(time_of_day: float, day: int) -> void:
	var total_min: int = int(time_of_day * 24.0 * 60.0)
	var hh: int = (total_min / 60) % 24
	var mm: int = total_min % 60
	var night: bool = _daynight.is_night() if _daynight else false
	var icon: String = "🌙 밤" if night else "☀ 낮"
	_day_label.text = "%s  ·  Day %d  ·  %02d:%02d" % [icon, day, hh, mm]


func _on_died() -> void:
	_day_label.text = "💀 사망 — 당신은 정글에 삼켜졌다"
	_death_label.text = "💀 사망\n당신은 정글에 삼켜졌다\n\n%s" % GameState.stats_summary()


# === 패널 토글(한 번에 하나만) ===
func _toggle_panel(panel: Control) -> void:
	var show_it: bool = not panel.visible
	_inv_panel.visible = false
	_craft_panel.visible = false
	_build_panel.visible = false
	_save_panel.visible = false
	panel.visible = show_it


const STATION_RANGE := 4.0

func _open_craft() -> void:
	# 제작은 작업대/대장간 같은 제작 건물 근처에서만 가능
	if not _near_any_station():
		_show_toast("작업대 근처에서 제작할 수 있어요")
		return
	_build_craft_list()  # 보유량/근접 건물에 따라 버튼 활성/비활성 갱신
	_toggle_panel(_craft_panel)


## 특정 제작 건물이 플레이어 근처(STATION_RANGE)에 있는지
func _near_station(type: String) -> bool:
	if not is_instance_valid(_player):
		return false
	for b in get_tree().get_nodes_in_group("building"):
		if b.build_type == type and _player.global_position.distance_to(b.global_position) <= STATION_RANGE:
			return true
	return false


## 제작 건물(작업대 또는 대장간) 근처인지
func _near_any_station() -> bool:
	return _near_station("workbench") or _near_station("forge")


## 레시피가 요구하는 제작 건물(없으면 작업대 기본)
func _recipe_station(r: Dictionary) -> String:
	var st: String = r.get("station", "")
	return st if st != "" else "workbench"


func _open_build() -> void:
	_toggle_panel(_build_panel)


# === M3: 인벤토리 UI ===
func _on_inventory_changed() -> void:
	_rebuild_inventory()
	if _craft_panel.visible:
		_build_craft_list()


func _rebuild_inventory() -> void:
	for c in _inv_grid.get_children():
		c.queue_free()
	for slot in _inventory.get_slots():
		_inv_grid.add_child(_make_slot(slot["id"], slot["count"]))


func _make_slot(id: String, count: int) -> Control:
	# 클릭 가능한 슬롯: 소비 아이템→사용, 도구→장착
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(112, 60)
	btn.text = "%s\n×%d" % [ItemDB.item_name(id), count]
	btn.add_theme_font_size_override("font_size", 16)

	var base := ItemDB.item_color(id).darkened(0.15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hi := StyleBoxFlat.new()
	sb_hi.bg_color = ItemDB.item_color(id)
	sb_hi.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", sb_hi)
	btn.add_theme_stylebox_override("pressed", sb_hi)

	btn.pressed.connect(_use_slot.bind(id))
	return btn


## 슬롯 클릭: 사용 또는 장착
func _use_slot(id: String) -> void:
	if _player == null or _inventory == null:
		return
	var def: Dictionary = ItemDB.items.get(id, {})
	if def.has("throw"):
		_player.throw_item(id, def["throw"])
		_inventory.remove_item(id, 1)
		_show_toast("%s 투척!" % ItemDB.item_name(id))
	elif def.has("buff"):
		_player.apply_buff(def["buff"])
		_inventory.remove_item(id, 1)
		_show_toast("%s 사용 (버프)" % ItemDB.item_name(id))
	elif def.has("use"):
		_player.consume_item(id, def["use"])
		_inventory.remove_item(id, 1)
		_show_toast("%s 사용" % ItemDB.item_name(id))
	elif def.has("equip"):
		var msg: String = _player.equip_item(id, def["equip"])
		if msg != "":
			_show_toast(msg)


# === M4: 제작 ===
func _build_craft_list() -> void:
	for c in _craft_list.get_children():
		c.queue_free()
	for id in ItemDB.recipes:
		if not GameState.is_unlocked(id):
			continue  # 미연구 레시피는 숨김
		var r: Dictionary = ItemDB.recipes[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var req_station: String = _recipe_station(r)
		var near_station: bool = _near_station(req_station)

		var lbl := Label.new()
		lbl.text = "%s  (%s)" % [r["name"], ItemDB.cost_text(r["cost"])]
		if not near_station:
			lbl.text += "  · %s 근처 필요" % ItemDB.building_def(req_station).get("name", req_station)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "제작"
		btn.custom_minimum_size = Vector2(96, 40)
		var affordable: bool = _inventory != null and _inventory.can_afford(r["cost"])
		btn.disabled = not (affordable and near_station)
		btn.pressed.connect(_craft.bind(id))
		row.add_child(btn)

		_craft_list.add_child(row)


func _craft(recipe_id: String) -> void:
	var r: Dictionary = ItemDB.recipe(recipe_id)
	if r.is_empty() or _inventory == null:
		return
	var req_station: String = _recipe_station(r)
	if not _near_station(req_station):
		_show_toast("%s 근처에서 제작하세요" % ItemDB.building_def(req_station).get("name", req_station))
		return
	if not _inventory.can_afford(r["cost"]):
		_show_toast("자원이 부족합니다")
		return
	_inventory.spend(r["cost"])
	for out_id in r["result"]:
		_inventory.add_item(out_id, int(r["result"][out_id]))
	AudioManager.play("craft")
	_tut_reach(3)
	_show_toast("제작: %s" % r["name"])
	_build_craft_list()


# === M4: 건설 ===
func _build_build_list() -> void:
	for c in _build_list.get_children():
		c.queue_free()
	for type in ItemDB.buildings:
		if not GameState.is_unlocked(type):
			continue  # 미연구 건물은 숨김
		var b: Dictionary = ItemDB.buildings[type]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var lbl := Label.new()
		lbl.text = "%s  (%s)" % [b["name"], ItemDB.cost_text(b["cost"])]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "건설"
		btn.custom_minimum_size = Vector2(96, 40)
		btn.pressed.connect(_start_build.bind(type))
		row.add_child(btn)

		_build_list.add_child(row)


func _start_build(build_type: String) -> void:
	if _builder == null:
		return
	_build_panel.visible = false
	_builder.start_build(build_type)


func _on_build_mode_changed(active: bool) -> void:
	_build_controls.visible = active
	_build_hint.visible = active
	# 건설 모드 진입/종료 시 연속 토글 초기화(OFF)
	if _continuous_btn:
		_continuous_btn.button_pressed = false
		_continuous_btn.text = "연속 OFF"
	# 건설 중엔 메뉴 버튼 숨김
	_inv_button.visible = not active
	_craft_button.visible = not active
	_build_button.visible = not active
	_action_button.visible = not active
	_dodge_button.visible = not active


func _on_confirm() -> void:
	if _builder and not _builder.confirm():
		_show_toast("자원이 부족합니다")
	else:
		_tut_reach(3)


func _on_cancel() -> void:
	if _builder:
		_builder.cancel()


# === M5: 전투/사망/웨이브 ===
func _on_player_died() -> void:
	_death_overlay.visible = true
	# 로그라이트: 이번 런 성과만큼 유산 지급 + 사망창에 표시
	var gain: int = MetaManager.award_on_death()
	_death_label.text += "\n\n💠 획득 유산: +%d   (보유 %d)" % [gain, MetaManager.currency]


func _on_player_respawned() -> void:
	_death_overlay.visible = false


func _on_wave_spawned(count: int) -> void:
	_tut_reach(5)
	_show_toast("🌙 밤! 맹수 %d마리 습격!" % count)


func _on_villager_recruited(count: int) -> void:
	_tut_reach(4)
	_show_toast("부락민 영입! (총 %d명)" % count)


func _on_villager_job_changed(job_name: String) -> void:
	_show_toast("직업 변경 → %s" % job_name)


func _on_day_advanced(day: int) -> void:
	GameState.note_day(day)
	SaveManager.save_game(-1)  # 자동저장 슬롯
	_autosave_timer = AUTOSAVE_INTERVAL  # 방금 저장했으니 주기 리셋
	_show_toast("자동 저장 · Day %d" % day)


## 주기적 자동저장(시간 기반) — 낮/밤이 길어도 진행 보존
func _tick_autosave(delta: float) -> void:
	if not _connected:
		return
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_INTERVAL
		if _can_autosave():
			SaveManager.save_game(-1)
			_show_toast("💾 자동 저장")


func _can_autosave() -> bool:
	if get_tree().paused or not is_instance_valid(_player):
		return false
	if _player.has_method("is_dead") and _player.is_dead():
		return false
	return true


## 모바일: 앱이 백그라운드로 가거나 종료될 때 즉시 저장(진행 손실 방지)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 일시정지 중이어도 저장(백그라운드 전환 시 손실 방지)
		if _connected and is_instance_valid(_player) and not (_player.has_method("is_dead") and _player.is_dead()):
			SaveManager.save_game(-1)


func _on_victory() -> void:
	_win_label.text = "🏆 승리!\n정글의 지배자를 물리쳤다\n\n%s" % GameState.stats_summary()
	GameState.vibrate(300)
	# 엔딩 시퀀스 먼저 → "결과 보기"로 승리 화면
	_ending_overlay.visible = true


func _on_event_changed(event_name: String, color: Color, active: bool) -> void:
	if active:
		_flash_banner(event_name)
		_event_tint.color = Color(color.r, color.g, color.b, 0.16)
		var tw := create_tween()
		tw.tween_property(_event_tint, "color:a", 0.16, 0.5)
	else:
		var tw := create_tween()
		tw.tween_property(_event_tint, "color:a", 0.0, 0.8)


func _set_pause(p: bool) -> void:
	get_tree().paused = p
	_pause_overlay.visible = p




func _on_boss_incoming(boss_name: String) -> void:
	_flash_banner("⚠ %s 출현! ⚠" % boss_name)
	AudioManager.play("boss_die")  # 포효(하강 럼블) 재사용
	GameState.shake(0.4)
	GameState.vibrate(200)


func _flash_banner(text: String) -> void:
	_boss_banner.text = text
	_boss_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_boss_banner, "modulate:a", 0.0, 0.8)


# === 성장(레벨/경험치) UI ===
func _build_progression_ui() -> void:
	# 화면 상단 중앙의 경험치 바 + 레벨/수치 라벨
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.min_value = 0.0
	_xp_bar.max_value = 1.0
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.anchor_left = 0.5
	_xp_bar.anchor_right = 0.5
	_xp_bar.offset_left = -210
	_xp_bar.offset_right = 210
	_xp_bar.offset_top = 96
	_xp_bar.offset_bottom = 120
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.98, 0.78, 0.25)
	fill.set_corner_radius_all(6)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(6)
	_xp_bar.add_theme_stylebox_override("background", bg)
	add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_label.add_theme_font_size_override("font_size", 15)
	_xp_label.anchor_left = 0.5
	_xp_label.anchor_right = 0.5
	_xp_label.offset_left = -210
	_xp_label.offset_right = 210
	_xp_label.offset_top = 96
	_xp_label.offset_bottom = 120
	add_child(_xp_label)

	# 야간 습격 경고 라벨(경험치 바 아래)
	_raid_label = Label.new()
	_raid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raid_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_label.add_theme_font_size_override("font_size", 22)
	_raid_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
	_raid_label.anchor_left = 0.5
	_raid_label.anchor_right = 0.5
	_raid_label.offset_left = -260
	_raid_label.offset_right = 260
	_raid_label.offset_top = 126
	_raid_label.offset_bottom = 158
	_raid_label.visible = false
	add_child(_raid_label)

	# 연속 처치 콤보 카운터
	_combo_label = Label.new()
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.add_theme_font_size_override("font_size", 30)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_label.anchor_left = 0.5
	_combo_label.anchor_right = 0.5
	_combo_label.offset_left = -200
	_combo_label.offset_right = 200
	_combo_label.offset_top = 166
	_combo_label.offset_bottom = 206
	_combo_label.pivot_offset = Vector2(200, 20)
	_combo_label.visible = false
	add_child(_combo_label)

	# 레벨업 보상 선택 오버레이(일시정지)
	_levelup_overlay = Control.new()
	_levelup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_levelup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_levelup_overlay.visible = false
	add_child(_levelup_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.66)
	_levelup_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(520, 0)
	margin.add_child(vb)
	_levelup_title = Label.new()
	_levelup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_levelup_title.add_theme_font_size_override("font_size", 30)
	_levelup_title.text = "⭐ 레벨 업!"
	vb.add_child(_levelup_title)
	_levelup_choices = VBoxContainer.new()
	_levelup_choices.add_theme_constant_override("separation", 10)
	vb.add_child(_levelup_choices)


func _on_xp_changed(xp: float, xp_to_next: float, level: int) -> void:
	if _xp_bar == null:
		return
	_xp_bar.max_value = maxf(1.0, xp_to_next)
	_xp_bar.value = clampf(xp, 0.0, _xp_bar.max_value)
	_xp_label.text = "Lv.%d   %d / %d" % [level, int(xp), int(xp_to_next)]


func _on_level_up(_level: int) -> void:
	_pending_levels += 1
	_try_show_levelup()


func _try_show_levelup() -> void:
	if _levelup_showing or _pending_levels <= 0:
		return
	var choices: Array = GameState.roll_perk_choices(3)
	if choices.is_empty():
		# 모든 퍽 최대치 — 조용히 소비
		_pending_levels = 0
		return
	_levelup_showing = true
	get_tree().paused = true
	_levelup_title.text = "⭐ 레벨 %d!  보상을 선택하세요" % GameState.level
	for c in _levelup_choices.get_children():
		c.queue_free()
	for id in choices:
		_levelup_choices.add_child(_make_perk_button(id))
	_levelup_overlay.visible = true
	GameState.vibrate(120)


func _make_perk_button(id: String) -> Button:
	var def: Dictionary = ItemDB.perk_def(id)
	var lv: int = GameState.perk_levels.get(id, 0)
	var maxlv: int = int(def.get("max", 1))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_size_override("font_size", 20)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.text = "%s  %s  —  %s   [Lv.%d→%d / 최대 %d]" % [
		def.get("icon", "•"), def.get("name", id), def.get("desc", ""),
		lv, lv + 1, maxlv
	]
	btn.pressed.connect(_on_perk_picked.bind(id))
	return btn


func _on_perk_picked(id: String) -> void:
	GameState.choose_perk(id)
	_pending_levels = maxi(0, _pending_levels - 1)
	_levelup_overlay.visible = false
	_levelup_showing = false
	if _pending_levels > 0:
		_try_show_levelup()
	else:
		get_tree().paused = false


# === 퀘스트 / 기술 연구 ===
func _build_quest_research_ui() -> void:
	var qo := _make_overlay("🎯 목표")
	_quest_overlay = qo[0]
	_quest_list = qo[1]
	var ro := _make_overlay("🔬 기술 연구")
	_research_overlay = ro[0]
	_research_list = ro[1]
	# 도움말 패널에 진입 버튼 2개(닫기 위에)
	var vbox: VBoxContainer = $HelpPanel/Margin/VBox
	var qbtn := Button.new()
	qbtn.text = "🎯 목표 보기"
	qbtn.custom_minimum_size = Vector2(0, 48)
	qbtn.pressed.connect(_open_quests)
	vbox.add_child(qbtn)
	vbox.move_child(qbtn, _help_close.get_index())
	var rbtn := Button.new()
	rbtn.text = "🔬 기술 연구"
	rbtn.custom_minimum_size = Vector2(0, 48)
	rbtn.pressed.connect(_open_research)
	vbox.add_child(rbtn)
	vbox.move_child(rbtn, _help_close.get_index())


## 공용 오버레이(딤+중앙패널+스크롤 리스트+닫기) 생성 → [overlay, list]
func _make_overlay(title_text: String) -> Array:
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.visible = false
	add_child(ov)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	ov.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(center)
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
	title.text = title_text
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 52)
	close.pressed.connect(func(): ov.visible = false; get_tree().paused = false)
	vb.add_child(close)
	return [ov, list]


func _open_quests() -> void:
	_help_panel.visible = false
	_refresh_quests()
	_quest_overlay.visible = true
	get_tree().paused = true


func _refresh_quests() -> void:
	for c in _quest_list.get_children():
		c.queue_free()
	for q in ItemDB.quests:
		var done: bool = GameState.quests_done.has(q.get("id", ""))
		var cur: int = mini(GameState.quest_progress(q), int(q.get("target", 0)))
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)
		var mark: String = "✅" if done else "▫"
		lbl.text = "%s %s  (%d/%d)" % [mark, q.get("name", ""), cur, int(q.get("target", 0))]
		if done:
			lbl.modulate = Color(0.6, 0.9, 0.6)
		_quest_list.add_child(lbl)


func _open_research() -> void:
	_help_panel.visible = false
	_refresh_research()
	_research_overlay.visible = true
	get_tree().paused = true


func _refresh_research() -> void:
	for c in _research_list.get_children():
		c.queue_free()
	for t in ItemDB.research:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 16)
		var unlock_names: Array = []
		for u in t.get("unlocks", []):
			unlock_names.append(_thing_name(u))
		info.text = "%s  (%s)\n해금: %s" % [t.get("name", ""), ItemDB.cost_text(t.get("cost", {})), ", ".join(unlock_names)]
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 56)
		if GameState.researched.has(t.get("id", "")):
			btn.text = "✅ 완료"
			btn.disabled = true
		elif not GameState.can_research(t):
			btn.text = "🔒 선행"
			btn.disabled = true
		else:
			btn.text = "연구"
			btn.disabled = not (_inventory and _inventory.can_afford(t.get("cost", {})))
			btn.pressed.connect(func():
				if GameState.do_research(t):
					_refresh_research())
		row.add_child(btn)
		_research_list.add_child(row)


## 건물/아이템 표시명
func _thing_name(id: String) -> String:
	if ItemDB.buildings.has(id):
		return ItemDB.buildings[id].get("name", id)
	return ItemDB.item_name(id)


# === 로그라이트: 메타 상점(사망 화면) ===
func _open_meta_shop() -> void:
	if _meta_shop == null:
		_meta_shop = MetaShopScene.instantiate()
		add_child(_meta_shop)
		_meta_shop.closed.connect(func(): get_tree().paused = false)
	get_tree().paused = true
	_meta_shop.open()


func _open_merchant_shop() -> void:
	if _merchant_shop == null:
		_merchant_shop = MerchantShopScene.instantiate()
		add_child(_merchant_shop)
		_merchant_shop.closed.connect(func(): get_tree().paused = false)
	get_tree().paused = true
	if is_instance_valid(_player):
		_merchant_shop.open(_player.get_inventory())


# === 연속 처치 콤보 표시 ===
func _on_combo_changed(c: int) -> void:
	if _combo_label == null:
		return
	if c >= 2:
		_combo_label.visible = true
		_combo_label.text = "🔥 %d 연속!" % c
		_combo_label.scale = Vector2(1.35, 1.35)
		var tw := create_tween()
		tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.18)
		# 5의 배수 마일스톤은 배너로 강조
		if c % 5 == 0:
			_flash_banner("🔥 %d 연속 처치!" % c)
			GameState.vibrate(60)
	else:
		_combo_label.visible = false


# === 가독성: 화면 밖 위협 화살표 ===
func _build_threat_layer() -> void:
	var layer := Control.new()
	layer.set_script(load("res://ui/threat_indicators.gd"))
	add_child(layer)


# === 가독성: 야간 습격 경고 ===
func _update_raid_warning() -> void:
	if _daynight == null or _raid_label == null:
		return
	if not _daynight.has_method("seconds_until_night"):
		return
	var night: bool = _daynight.is_night() if _daynight.has_method("is_night") else false
	var boss_alive: bool = get_tree().get_first_node_in_group("boss") != null
	if night or boss_alive:
		_raid_label.visible = false
		return
	var secs: float = _daynight.seconds_until_night()
	if secs <= RAID_LEAD and secs > 0.0:
		_raid_label.visible = true
		_raid_label.text = "🌙 곧 밤이 옵니다 — 맹수 습격까지 %d초" % int(ceilf(secs))
		# 하루에 한 번 배너+진동으로 강조
		var day: int = _daynight.day if _daynight else 0
		if _raid_warned_day != day:
			_raid_warned_day = day
			_flash_banner("🌙 야간 습격 대비!")
			GameState.vibrate(150)
	else:
		_raid_label.visible = false


func _has_building(type: String) -> bool:
	for b in get_tree().get_nodes_in_group("building"):
		if b.build_type == type:
			return true
	return false


# === 공용 ===
func _on_item_added(id: String, amount: int) -> void:
	_show_toast("+%d %s" % [amount, ItemDB.item_name(id)])


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_running():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.7)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
