extends Area3D
## 보물 상자 — 맵에 등장하거나 보스 처치 시 확정 드롭. [행동]으로 열면 보상 일괄 지급.
## - 그룹 "chest", player._try_open_chest 가 근접 시 open() 호출.
## - tier: "common"(맵) / "boss"(보스 보상, 더 풍성 + 발광).

var _tier: String = "common"
var _loot: Dictionary = {}
var _opened: bool = false
var _box: MeshInstance3D
var _lid: MeshInstance3D


func setup(tier: String, loot: Dictionary = {}) -> void:
	_tier = tier
	_loot = loot


func _ready() -> void:
	add_to_group("chest")
	collision_layer = 0
	collision_mask = 0
	if _loot.is_empty():
		_loot = _gen_loot(_tier)
	_build_visual()
	# 살짝 통통 튀는 등장 연출
	scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_visual() -> void:
	var boss: bool = _tier == "boss"
	_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.66, 0.7)
	_box.mesh = bm
	_box.position.y = 0.33
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.55, 0.22) if boss else Color(0.5, 0.34, 0.18)
	mat.roughness = 1.0
	_box.material_override = mat
	add_child(_box)

	_lid = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.96, 0.2, 0.76)
	_lid.mesh = lm
	_lid.position.y = 0.74
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.9, 0.72, 0.28)
	lmat.emission_enabled = true
	lmat.emission = Color(0.9, 0.66, 0.2)
	lmat.emission_energy_multiplier = 1.4 if boss else 0.7
	_lid.material_override = lmat
	add_child(_lid)

	# 반짝이는 유혹 파티클
	var p := CPUParticles3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.08, 0.08, 0.08)
	p.mesh = pm
	p.amount = 14
	p.lifetime = 1.3
	p.emitting = true
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.8, 0)
	p.color = Color(1.0, 0.86, 0.35)
	p.position.y = 0.8
	add_child(p)


## 열기: 보상 드롭 + 연출. 성공 시 true.
func open(_inv: Node) -> bool:
	if _opened:
		return false
	_opened = true
	GameState.spawn_drops(global_position, _loot)
	GameState.spawn_puff(global_position, Color(1.0, 0.86, 0.35), 24)
	GameState.spawn_text(global_position, "✨ 보물!", Color(1.0, 0.86, 0.35), 1.3)
	GameState.shake(0.22)
	GameState.vibrate(80)
	AudioManager.play("craft")
	# 뚜껑 열림 후 사라짐
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", -1.2, 0.18)
	tw.tween_interval(0.1)
	tw.tween_property(self, "scale", Vector3(1.1, 0.05, 1.1), 0.2)
	tw.tween_callback(queue_free)
	return true


## 보상 생성. 자원 2종 + 확률로 전투템 + 보스상자는 수정 보너스.
func _gen_loot(tier: String) -> Dictionary:
	var d: Dictionary = {}
	var res := ["wood", "stone", "fiber", "food", "scrap", "herb", "clay", "hide"]
	d[res.pick_random()] = randi_range(4, 9)
	d[res.pick_random()] = randi_range(2, 6)
	var goodies := ["bomb", "firebomb", "arrow", "rage_brew", "swift_tonic", "iron_skin", "medkit", "bandage", "lure_meat"]
	if randf() < (0.85 if tier == "boss" else 0.4):
		d[goodies.pick_random()] = randi_range(1, 3)
	if tier == "boss":
		d["crystal"] = randi_range(1, 3)
	return d
