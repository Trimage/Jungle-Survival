extends Node3D
func _ready() -> void:
	var world: Node3D = preload("res://scenes/world.tscn").instantiate()
	add_child(world)
	world.set_process(false)
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 6, 22), Vector3(0, 4, 0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	var shots := {"sunset": 0.75, "sunrise": 0.25}
	for name in shots:
		world.time_of_day = shots[name]
		world._update_visuals(true)
		for i in 3:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://_sky_%s.png" % name)
		print("[VERIFY] %s saved" % name)
	get_tree().quit()
