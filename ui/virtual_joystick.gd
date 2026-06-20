extends Control
## 동적 가상 조이스틱 (M1)
## - 지정한 활성 영역(보통 화면 좌측 절반)을 터치하면 그 자리에 조이스틱이 나타남
## - 손가락(또는 마우스)을 드래그하면 방향/세기를 출력
## - get_output() → 정규화 보정된 Vector2 (x: 좌우, y: 위(-)/아래(+))
##   주의: 화면 y는 아래가 +이므로, 이동에서 "위로"는 음수 y로 들어온다.

## 베이스(바깥 원) 반지름(px)
@export var base_radius: float = 90.0
## 노브(안쪽 원) 반지름(px)
@export var knob_radius: float = 45.0
## 입력으로 인정할 최소 거리 비율(데드존)
@export var dead_zone: float = 0.15

var _active: bool = false           # 현재 조작 중 여부
var _touch_index: int = -1          # 추적 중인 터치 인덱스
var _base_pos: Vector2 = Vector2.ZERO   # 조이스틱이 생긴 중심
var _knob_pos: Vector2 = Vector2.ZERO   # 노브 현재 위치
var _output: Vector2 = Vector2.ZERO     # -1~1 출력


func _ready() -> void:
	add_to_group("joystick")


## 플레이어가 매 프레임 읽어가는 입력 벡터
func get_output() -> Vector2:
	return _output


func _gui_input(event: InputEvent) -> void:
	# 터치 시작/해제
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_active = true
			_touch_index = event.index
			_base_pos = event.position
			_knob_pos = event.position
			_update_output()
			queue_redraw()
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_reset()
			queue_redraw()
			accept_event()

	# 드래그
	elif event is InputEventScreenDrag and _active and event.index == _touch_index:
		var offset: Vector2 = event.position - _base_pos
		# 노브를 베이스 반지름 안으로 제한
		if offset.length() > base_radius:
			offset = offset.normalized() * base_radius
		_knob_pos = _base_pos + offset
		_update_output()
		queue_redraw()
		accept_event()


func _update_output() -> void:
	var raw := (_knob_pos - _base_pos) / base_radius
	if raw.length() < dead_zone:
		_output = Vector2.ZERO
	else:
		_output = raw


func _reset() -> void:
	_active = false
	_touch_index = -1
	_output = Vector2.ZERO


func _draw() -> void:
	# 조작 중일 때만 베이스/노브 표시
	if not _active:
		return
	draw_circle(_base_pos, base_radius, Color(1, 1, 1, 0.12))
	draw_arc(_base_pos, base_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_knob_pos, knob_radius, Color(1, 1, 1, 0.4))
