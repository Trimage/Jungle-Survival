extends Node
## 사운드 매니저 (M7, 오토로드 "AudioManager") — 자리(스텁)
## - data/sounds.json 의 {이름: 경로} 매핑을 로드(에셋이 아직 없으면 무음으로 동작)
## - play(name): 풀에서 빈 플레이어로 재생. 에셋이 없으면 조용히 무시.
##   주요 액션(공격/채집/건설/피격 등)에서 호출 자리를 마련해 둠.

@export var pool_size: int = 8

var _sounds: Dictionary = {}              # 이름 → AudioStream
var _players: Array[AudioStreamPlayer] = []
var _idx: int = 0
var _music: AudioStreamPlayer


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_load_map()
	for i in pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_start_music()


## 버스가 없으면 생성하고 Master 로 보냄
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


## BGM 재생(루프). 에셋 없으면 무음.
func _start_music() -> void:
	if not _sounds.has("bgm"):
		return
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	var stream: AudioStream = _sounds["bgm"]
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16bit 모노 프레임 수
	_music.stream = stream
	_music.volume_db = -6.0
	_music.play()
	# 루프가 안 걸리는 포맷 대비: 끝나면 다시 재생
	_music.finished.connect(func(): if is_instance_valid(_music): _music.play())


## 마스터 음량(0~1 선형) 설정 — 설정 메뉴에서 사용
func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(linear, 0.0001, 1.0)))


func set_music_volume(linear: float) -> void:
	var i := AudioServer.get_bus_index("Music")
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0001, 1.0)))


func set_sfx_volume(linear: float) -> void:
	var i := AudioServer.get_bus_index("SFX")
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0001, 1.0)))


func _load_map() -> void:
	var path := "res://data/sounds.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in parsed:
		var res_path: String = parsed[key]
		# 실제 오디오 파일이 존재할 때만 로드(없으면 자리만 유지)
		if res_path != "" and ResourceLoader.exists(res_path):
			_sounds[key] = load(res_path)


## 효과음 재생. 등록된 에셋이 없으면 무음(no-op).
func play(sound_name: String) -> void:
	if not _sounds.has(sound_name) or _players.is_empty():
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _sounds[sound_name]
	p.play()
