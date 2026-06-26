extends Node3D
func _ready() -> void:
	var world: Node3D = preload("res://scenes/world.tscn").instantiate()
	add_child(world)
	world.set_process(false)
	world.time_of_day = 0.42
	world._update_visuals(true)
	var cam := Camera3D.new()
	add_child(cam)
	await get_tree().process_frame
	await get_tree().process_frame
	# 연못 바로 위 비스듬한 시점
	cam.look_at_from_position(Vector3(-16, 9, -5), Vector3(-16, 0, -13), Vector3.UP)
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://_fx_water2.png")
	print("[VERIFY] water2 saved")
	get_tree().quit()
