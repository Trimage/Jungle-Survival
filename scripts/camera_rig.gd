extends Node3D
## 쿼터뷰(아이소메트릭) 카메라 리그 (M1)
## - 고정된 각도(요/피치)를 유지하며 타깃(플레이어)을 부드럽게 추적
## - 실제 Camera3D 는 이 리그의 자식으로, 직교 투영 + 뒤/위로 오프셋

## 추적 대상(플레이어). 없으면 그룹 "player" 로 탐색.
@export var target_path: NodePath
## 추적 보간 속도(클수록 빠르게 따라붙음)
@export var follow_speed: float = 8.0

var _target: Node3D = null
var _shake: float = 0.0          # 현재 흔들림 강도
@onready var _cam: Camera3D = $Camera


func _ready() -> void:
	add_to_group("camera_rig")
	if target_path:
		_target = get_node_or_null(target_path)
	if _target == null:
		_target = get_tree().get_first_node_in_group("player")


## 화면 흔들림 추가(강도 누적, 큰 값 우선)
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _physics_process(delta: float) -> void:
	if _target:
		# 리그 위치를 타깃 위치로 부드럽게 보간 → 각도는 고정 유지
		var t: float = clampf(follow_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(_target.global_position, t)

	# 흔들림: 카메라 프러스텀 오프셋을 랜덤 흔든 뒤 감쇠
	if _shake > 0.001 and _cam:
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake
		_shake = move_toward(_shake, 0.0, delta * 2.5)
	elif _cam:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
