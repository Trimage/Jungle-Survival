extends Node
## 게임 진행 상태 (M7 확장, 오토로드 "GameState")
## - 보스 처치/승리(최종 보스 처치) 전역 이벤트 중계, 목표 텍스트 계산

signal boss_defeated(boss_name: String)
signal victory
signal villager_died(job_name: String)
signal boss_incoming(boss_name: String)
signal boss_enrage(boss_name: String)
signal achievement(text: String)
signal event_changed(event_name: String, color: Color, active: bool)
## 경험치 변화(현재 xp, 다음 레벨까지 필요량, 현재 레벨)
signal xp_changed(xp: float, xp_to_next: float, level: int)
## 레벨 업(새 레벨) — HUD가 받아 퍽 선택창을 띄움
signal level_up(level: int)
## 퍽 획득(표시명) — 토스트용
signal perk_chosen(perk_name: String)
## 연속 처치 콤보 변화(현재 콤보 수)
signal combo_changed(combo: int)
## 퀘스트 완료(이름, 보상 설명)
signal quest_completed(quest_name: String, reward_text: String)
## 연구 상태 변화(메뉴/패널 갱신용)
signal research_changed

const PickupScene := preload("res://scenes/pickup.tscn")

var won: bool = false

# === 성장 시스템(레벨 / 경험치 / 퍽) ===
var level: int = 1
var xp: float = 0.0
var xp_to_next: float = 12.0
var perk_levels: Dictionary = {}  # 퍽 id → 보유 레벨

# 퀘스트 / 연구 (런 단위)
var quests_done: Dictionary = {}   # 퀘스트 id → true
var researched: Dictionary = {}    # 기술 id → true
var _locked_ids: Dictionary = {}   # 잠긴 건물/레시피 id → 해금 기술 id
var _locked_built: bool = false

# 통계
var kills: int = 0
var bosses: int = 0
var recruits: int = 0
var builds: int = 0
var max_day: int = 1
var _ach_done: Dictionary = {}


# === 연속 처치 콤보 / 히트스톱 ===
var combo: int = 0
var _combo_timer: float = 0.0
const COMBO_WINDOW := 3.0   # 이 시간 내 다음 처치가 없으면 콤보 리셋
var _hitstop_active: bool = false


func _process(delta: float) -> void:
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0 and combo > 0:
			combo = 0
			combo_changed.emit(0)


## 콤보에 따른 경험치 배수(최대 +60%)
func combo_xp_mult() -> float:
	return 1.0 + mini(combo, 20) * 0.03


## 짧은 시간 정지(타격감). ignore_time_scale 타이머로 실시간 복구.
func hitstop(duration: float = 0.06) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_hitstop_active = false)


func note_kill() -> void:
	kills += 1
	# 콤보 누적
	combo += 1
	_combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	if kills == 25:
		_grant("사냥꾼 (맹수 25 처치)")
	elif kills == 100:
		_grant("정글의 포식자 (맹수 100 처치)")
	check_quests()

func note_recruit() -> void:
	recruits += 1
	if recruits == 5:
		_grant("부락의 시작 (5명 영입)")
	check_quests()

func note_build() -> void:
	builds += 1
	if builds == 5:
		_grant("건설자 (5채 건설)")
	check_quests()

func note_day(day: int) -> void:
	max_day = maxi(max_day, day)
	if day == 5:
		_grant("생존자 (5일 생존)")
	elif day == 10:
		_grant("불굴 (10일 생존)")
	check_quests()


func _grant(text: String) -> void:
	if _ach_done.has(text):
		return
	_ach_done[text] = true
	achievement.emit(text)


# === 성장 시스템 ===

## 경험치 획득(획득 경험치 퍽 반영). 누적이 충분하면 레벨 업.
func add_xp(amount: float) -> void:
	if amount <= 0.0:
		return
	# 런 단위 퍽 + 영구 메타(현자의 피) 경험치 보너스
	amount *= (1.0 + perk_sum("xp_gain") + MetaManager.meta_sum("xp_gain"))
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = roundf(xp_to_next * 1.3 + 6.0)
		level_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)


## 레벨업 보상 후보 n개를 뽑는다(최대치 도달 퍽 제외, 중복 없음).
func roll_perk_choices(n: int) -> Array:
	var pool: Array = []
	for id in ItemDB.perks:
		var lv: int = perk_levels.get(id, 0)
		if lv < int(ItemDB.perks[id].get("max", 99)):
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


## 퍽 선택 적용. 즉시효과(최대 체력 등)는 여기서 반영.
func choose_perk(id: String) -> void:
	if not ItemDB.perks.has(id):
		return
	perk_levels[id] = perk_levels.get(id, 0) + 1
	var def: Dictionary = ItemDB.perks[id]
	# 최대 체력 퍽: 생존 스탯의 체력 상한을 올리고 그만큼 회복
	if def.get("stat", "") == "max_hp":
		var stats := get_tree().get_first_node_in_group("survival_stats")
		if stats and stats.has_method("set_max_bonus"):
			stats.set_max_bonus("health", perk_sum("max_hp"), float(def.get("per_level", 0.0)))
	perk_chosen.emit(def.get("name", id))


## 특정 효과(stat)의 보유 퍽 합산값(per_level × 보유레벨).
func perk_sum(stat: String) -> float:
	var total: float = 0.0
	for id in perk_levels:
		var def: Dictionary = ItemDB.perks.get(id, {})
		if def.get("stat", "") == stat:
			total += float(def.get("per_level", 0.0)) * int(perk_levels[id])
	return total


## 저장/불러오기용 진행도 묶음
func export_progress() -> Dictionary:
	return {
		"level": level, "xp": xp, "xp_to_next": xp_to_next, "perks": perk_levels.duplicate(),
		"quests": quests_done.duplicate(), "research": researched.duplicate(),
	}


func import_progress(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = float(d.get("xp", 0.0))
	xp_to_next = float(d.get("xp_to_next", 12.0))
	perk_levels = (d.get("perks", {}) as Dictionary).duplicate()
	quests_done = (d.get("quests", {}) as Dictionary).duplicate()
	researched = (d.get("research", {}) as Dictionary).duplicate()
	research_changed.emit()
	# 최대 체력 퍽을 현재 생존 스탯에 다시 반영(회복 없이 상한만)
	var stats := get_tree().get_first_node_in_group("survival_stats")
	if stats and stats.has_method("set_max_bonus"):
		stats.set_max_bonus("health", perk_sum("max_hp"))
	xp_changed.emit(xp, xp_to_next, level)


# === 퀘스트 / 목표 ===

## 퀘스트 타입별 현재 진행값
func quest_progress(q: Dictionary) -> int:
	match q.get("type", ""):
		"kills": return kills
		"bosses": return bosses
		"builds": return builds
		"recruits": return recruits
		"survive": return max_day
	return 0


## 달성한 퀘스트 보상 지급(중복 방지)
func check_quests() -> void:
	for q in ItemDB.quests:
		var id: String = q.get("id", "")
		if quests_done.has(id):
			continue
		if quest_progress(q) >= int(q.get("target", 999999)):
			quests_done[id] = true
			_grant_quest_reward(q)


func _grant_quest_reward(q: Dictionary) -> void:
	var reward: Dictionary = q.get("reward", {})
	var parts: Array = []
	var items: Dictionary = reward.get("items", {})
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("get_inventory"):
		for id in items:
			pl.get_inventory().add_item(id, int(items[id]))
			parts.append("%s %d" % [ItemDB.item_name(id), int(items[id])])
	var legacy: int = int(reward.get("legacy", 0))
	if legacy > 0:
		MetaManager.add_currency(legacy)
		parts.append("유산 %d" % legacy)
	quest_completed.emit(q.get("name", ""), ", ".join(parts))


# === 기술 연구 ===

func _ensure_locked_index() -> void:
	if _locked_built:
		return
	_locked_built = true
	for t in ItemDB.research:
		for id in t.get("unlocks", []):
			_locked_ids[id] = t.get("id", "")


## 건물/레시피가 해금되었는지(연구로 잠긴 것만 검사)
func is_unlocked(id: String) -> bool:
	_ensure_locked_index()
	if not _locked_ids.has(id):
		return true
	return researched.has(_locked_ids[id])


## 연구 가능 여부(선행 기술 완료 + 미연구)
func can_research(tech: Dictionary) -> bool:
	if researched.has(tech.get("id", "")):
		return false
	for pre in tech.get("prereq", []):
		if not researched.has(pre):
			return false
	return true


## 연구 수행(자원 소모). 성공 시 true.
func do_research(tech: Dictionary) -> bool:
	if not can_research(tech):
		return false
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null or not pl.has_method("get_inventory"):
		return false
	var inv: Node = pl.get_inventory()
	var cost: Dictionary = tech.get("cost", {})
	if not inv.can_afford(cost):
		return false
	inv.spend(cost)
	researched[tech.get("id", "")] = true
	AudioManager.play("craft")
	research_changed.emit()
	return true


## 요약 문자열(사망/승리 화면)
func stats_summary() -> String:
	return "생존 %d일 · 처치 %d · 보스 %d · 영입 %d · 건설 %d" % [max_day, kills, bosses, recruits, builds]
## 부락민 집결 명령 활성화(플레이어 주위로 모여 방어)
var rally_active: bool = false
## 타이틀에서 메인 진입 시 불러올 슬롯(-999=새 게임)
var pending_load_slot: int = -999
## 새 게임 진입 시 인트로 컷신 재생 여부
var pending_intro: bool = false
## 모바일 진동(햅틱) 사용
var haptics_enabled: bool = true


## 모바일 햅틱 진동(데스크톱은 무시됨)
func vibrate(ms: int) -> void:
	if haptics_enabled:
		Input.vibrate_handheld(ms)


## 새 게임 시작 시 전역 상태 초기화
func reset_for_new_game() -> void:
	won = false
	rally_active = false
	pending_load_slot = -999
	pending_intro = false
	kills = 0
	bosses = 0
	recruits = 0
	builds = 0
	max_day = 1
	_ach_done = {}
	# 성장 초기화
	level = 1
	xp = 0.0
	xp_to_next = 12.0
	perk_levels = {}
	# 콤보 초기화
	combo = 0
	_combo_timer = 0.0
	# 퀘스트/연구 초기화(런 단위)
	quests_done = {}
	researched = {}
	# 로그라이트 메타: 이번 런 유산 지급 누적 초기화
	MetaManager.begin_run()


func report_villager_died(job_name: String) -> void:
	villager_died.emit(job_name)


func report_boss_incoming(boss_name: String) -> void:
	boss_incoming.emit(boss_name)


func report_boss_enrage(boss_name: String) -> void:
	boss_enrage.emit(boss_name)


## 위치에 전리품 드롭 생성 (drops: {아이템id: 수량})
func spawn_drops(pos: Vector3, drops: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for id in drops:
		var p: Node3D = PickupScene.instantiate()
		p.setup(id, int(drops[id]))
		scene.add_child(p)
		var ang := randf() * TAU
		p.global_position = pos + Vector3(cos(ang) * 0.8, 0.0, sin(ang) * 0.8)


## 화면 흔들림 (카메라 리그로 전달)
func shake(amount: float) -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("shake"):
		rig.shake(amount)


## 사망/타격 파티클 퍼프
func spawn_puff(pos: Vector3, color: Color, amount: int = 12) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 0.18, 0.18)
	p.mesh = bm
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -8, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.color = color
	scene.add_child(p)
	p.global_position = pos + Vector3(0, 0.6, 0)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## 타격 스파크(날카로운 발광 줄기 버스트) — 적 피격 시
func spawn_spark(pos: Vector3, color: Color = Color(1, 1, 1), amount: int = 10) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 0.24)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	bm.material = mat
	p.mesh = bm
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.5
	p.gravity = Vector3(0, -7, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	scene.add_child(p)
	p.global_position = pos + Vector3(0, 1.0, 0)
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


## 베기 충격 링(바닥에 퍼지는 발광 링) — 근접 공격 시
func spawn_slash(pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.8
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.95, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.6
	mi.material_override = mat
	scene.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.3, 0)
	mi.scale = Vector3(0.5, 0.5, 0.5)
	var tw := mi.create_tween()
	tw.parallel().tween_property(mi, "scale", Vector3(2.6, 1.0, 2.6), 0.2)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(mi.queue_free)


## 플로팅 텍스트(데미지 숫자 등). scale 로 크기 강조(치명타 등).
func spawn_text(pos: Vector3, text: String, color: Color, scale: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var lbl := Label3D.new()
	lbl.text = text
	lbl.modulate = color
	lbl.font_size = int(64 * scale)
	lbl.outline_size = 8 if scale > 1.2 else 0
	lbl.pixel_size = 0.012
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	scene.add_child(lbl)
	lbl.global_position = pos + Vector3(0, 1.6, 0)
	var tw := lbl.create_tween()
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y + 1.6, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)


## 보스 처치 보고. is_final 이면 승리.
func report_boss_defeated(_is_final: bool, boss_name: String) -> void:
	# 무한 생존: 승리/엔딩 없음. 보스 처치는 축하 + 보상(드롭/경험치)만.
	bosses += 1
	add_xp(40.0)  # 보스는 큰 경험치
	_grant("보스 토벌 (%s)" % boss_name)
	check_quests()
	boss_defeated.emit(boss_name)


func report_event(event_name: String, color: Color, active: bool) -> void:
	event_changed.emit(event_name, color, active)


## 현재 목표 문구(무한 생존)
func objective_text(day: int, boss_alive: bool) -> String:
	if boss_alive:
		return "보스를 격파하라!"
	if day < 3:
		return "3일째 밤까지 생존"
	return "부락을 키우고 밤을 버텨라"
