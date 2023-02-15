extends CanvasLayer


func set_building_preview(building_type, mouse_pos):
	var drag_building = load("res://scenes/" + building_type.to_lower() + ".tscn").instantiate()
	drag_building.set_name("DragBuilding")
	var control = Control.new()
	control.add_child(drag_building,true)
	control.position = mouse_pos
	control.set_name("BuildingPreview")
	add_child(control, true)
	move_child(get_node("BuildingPreview"), 0)


func update_building_preview(new_pos, color):
	get_node("BuildingPreview").position = new_pos
#	if get_node("BuildingPreview/DragBuilding").modulate != Color(color):
	get_node("BuildingPreview/DragBuilding").modulate = Color(color)
