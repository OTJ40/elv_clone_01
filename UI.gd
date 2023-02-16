extends CanvasLayer


func set_building_preview(building_type, preview_position):
	var drag_building = load("res://scenes/" + building_type.to_lower() + ".tscn").instantiate()
	drag_building.set_name("DragBuilding")
	var control = Control.new()
	control.add_child(drag_building,true)
	control.position = preview_position
	control.set_name("BuildingPreview")
	add_child(control, true)
	move_child(get_node("BuildingPreview"), 0)


func set_lands_for_sale_preview(building_type, preview_position):
	var drag_building = load("res://scenes/" + building_type.to_lower() + ".tscn").instantiate()
#	drag_building.set_name("DragBuilding")
	var control = Control.new()
	control.add_child(drag_building,true)
	control.position = preview_position
	control.set_name("LandPreview")
	$LandPreviews.add_child(control, true)
#	move_child(get_node("LandPreview"), 0)

func update_building_preview(new_pos, color):
	get_node("BuildingPreview").position = new_pos
#	if get_node("BuildingPreview/DragBuilding").modulate != Color(color):
	get_node("BuildingPreview/DragBuilding").modulate = Color(color)
