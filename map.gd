extends Node2D


enum BUILDING_TYPE{
	MAIN_HALL,
	ROAD,
	HOUSE,
	WORKSHOP
}

var is_first_time = true
var has_painted_building = false
var has_lands_preview = false

var build_mode = false
var sell_mode = false
var move_mode = false
var drag_mode = false
var expanse_mode = false

var place_valid = false

var build_type
var build_location

var sell_cursor
var move_cursor
var default_cursor

var file_manager: FileManager = FileManager.new()

var buildings_data_array = []
var own_lands_array = []
var for_sale_lands_array = []

var directions = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT
	]



func _ready() -> void:
	
	load_config()
	if is_first_time:
		build_main_hall()
	else:
		load_from_buildings_data_file()
	update_map()
	
	default_cursor = load("res://assets/ui/default_cursor_32.png")
	move_cursor = load("res://assets/ui/move_cursor_32.png")
	sell_cursor = load("res://assets/ui/sell_cursor_32.png")
	DisplayServer.cursor_set_custom_image(default_cursor)
	for b in get_tree().get_nodes_in_group("menu_buttons"):
		b.pressed.connect(init_menu_mode.bind(b))
	connect_builder_buttons()


func _process(_delta: float) -> void:
#	print(move_mode,expanse_mode)
	if build_mode or drag_mode:
		update_building_preview()


func _unhandled_input(event: InputEvent) -> void:
#	print(event)
	if build_mode:
		if event.is_action_released("ui_accept"):
#			prepare_to_place_dict()
			place_building()
			if build_type != "Road":
				cancel_build_mode()
				$Base.modulate = Color(1,1,1,1)
		if event.is_action_released("ui_cancel"):
			cancel_build_mode()
			$Base.modulate = Color(1,1,1,1)

	if sell_mode:
		if event.is_action_released("ui_accept"):
			var current_tile = $Buildings.local_to_map(get_global_mouse_position())
			if $Buildings.get_cell_source_id(0, current_tile) == BUILDING_TYPE.MAIN_HALL:
				print("You can`t!")
			else:
				if $Buildings.get_used_cells(0).has(current_tile):
					for item in buildings_data_array:
						for cell in get_atlas_positions_array_from_dims(item["dims"],item["base"]):
							if current_tile == cell:
								if !has_painted_building:
									$UI/HUD/Dialog/VBoxContainer/Label.text = "Sell "+ item["type"]+"?"
									paint_building(get_atlas_positions_array_from_dims(item["dims"],item["base"]),Color(1,0,0,0.5))
									$UI/HUD/Dialog.visible = true
									$UI/HUD/Menu.visible = false
									var callable = Callable(self,"erase_building")
									connect_dialog_buttons(item,callable)

	if move_mode:
		if !has_lands_preview:
			show_lands_for_sale()
			has_lands_preview = true
		if event.is_action_released("ui_accept"):
			var current_cell = $Buildings.local_to_map(get_global_mouse_position())
			if $Buildings.get_used_cells(0).has(current_cell):
				for item in buildings_data_array:
					for pos in get_atlas_positions_array_from_dims(item["dims"],item["base"]):
						if current_cell == pos:
							erase_building("Yes",item)
							$UI.set_building_preview(item["type"], get_global_mouse_position())
							build_type = item["type"]
							drag_mode = true
							
			elif has_point_in_for_sale_lands(current_cell):
				expanse_mode = true

	if drag_mode:
		$UI/HUD/DoneButton.visible = false
		move_mode = false
		if place_valid:
			if event.is_action_released("ui_accept"):
				place_building()
				cancel_drag_mode()

	if expanse_mode:
		if event.is_action_released("ui_accept"):
			if !has_painted_building:
				var current_tile = $Buildings.local_to_map(get_global_mouse_position())
				if has_point_in_for_sale_lands(current_tile):
					var rect_for_sale = get_rect_for_sale(current_tile)
					$UI/HUD/Dialog/VBoxContainer/Label.text = "Buy Expansion?"
					paint_building(get_atlas_positions_array_from_dims(Vector2i(5,5),rect_for_sale),Color(0,0,1,0.5))
					$UI/HUD/Dialog.visible = true
					var callable = Callable(self,"buy_expansion")
					connect_dialog_buttons({"position": rect_for_sale},callable)


func buy_expansion(btn_name,dict):
	if btn_name == "Yes":
		$Land.set_pattern(0,dict["position"],$Land.tile_set.get_pattern(0))
		own_lands_array.append(dict["position"])
		file_manager.save_to_file("lands_data", own_lands_array)
		if has_lands_preview:
			for l in $UI/LandPreviews.get_children():
				l.queue_free()
		show_lands_for_sale()
		desactivate_dialog_btns()
	elif btn_name == "No":
		desactivate_dialog_btns()





func desactivate_dialog_btns():
	$UI/HUD/Dialog.visible = false
	var color_rect_array = $UI/ColoredRectangles.get_children()
	if color_rect_array.size() > 0:
		for i in color_rect_array:
			i.queue_free()
	if has_painted_building:
		has_painted_building = false
	
	var c = null
	if sell_mode:
		c = Callable(self,"erase_building")
	if expanse_mode:
		c = Callable(self,"buy_expansion")
		
	disconnect_dialog_buttons(c)


func paint_building(rects_array: Array,color):
	for cell in rects_array:
		var cr = ColorRect.new()
		cr.size = Vector2i(32,32)
		cr.position = (cell)*32
		cr.modulate = color
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$UI/ColoredRectangles.add_child(cr)
	has_painted_building = true


func init_menu_mode(btn):
	match btn.name:
		"BuilderButton":
			$UI/HUD/BuildButtons.visible = true
			$UI/HUD/Menu.visible = false
			$UI/HUD/DoneButton.visible = true
		"SellButton":
			DisplayServer.cursor_set_custom_image(sell_cursor)
			sell_mode = true
			$UI/HUD/Menu.visible = false
			$UI/HUD/DoneButton.visible = true
		"MoveButton":
			move_mode = true
			$Cells.visible = true
			DisplayServer.cursor_set_custom_image(move_cursor)
			$UI/HUD/Menu.visible = false
			$UI/HUD/DoneButton.visible = true
		"ResearchButton":
			pass
		"WorldMapButton":
			pass
		"InventoryButton":
			pass
		

func init_build_mode(type):
#	$UI.modulate_ui(Color(1,1,1,0.4))
	build_mode = true
	build_type = type.name
	$Cells.visible = true
	$UI/HUD/BuildButtons.visible = false
	$UI/HUD/DoneButton.visible = false
	if build_type != "Expansion":
		$Base.modulate = Color(1,1,1,0.4)
		$UI.set_building_preview(build_type, get_global_mouse_position())
	else:
		show_lands_for_sale()
		has_lands_preview = true
		$UI/HUD/DoneButton.visible = true
		expanse_mode = true
		build_mode = false


func update_building_preview():
	var current_cell = $Buildings.local_to_map(get_global_mouse_position())
	var current_cell_in_px = Vector2i($Buildings.map_to_local(current_cell))
	
	var atlas = _get_atlas_array($Buildings.tile_set.get_source(BUILDING_TYPE[build_type.to_upper()])) if build_type != "Road" else [Vector2i(0,0)]
	var count_cells = 0
	for cell in atlas:
		if $Buildings.get_cell_source_id(0,current_cell + cell) == -1 and is_cell_legal_to_place(current_cell + cell):
			count_cells += 1
	if count_cells == atlas.size():
		$UI.update_building_preview(current_cell_in_px,"33fd146b")
		place_valid = true
		build_location = current_cell
	else:
		$UI.update_building_preview(current_cell_in_px,"f600039c")
		place_valid = false


func cancel_drag_mode():
	place_valid = false
	drag_mode = false
	move_mode = true
	$Cells.visible = true
	$UI/HUD/DoneButton.visible = true
	get_node("UI/BuildingPreview").queue_free()


func cancel_build_mode():
	$Cells.visible = false
	place_valid = false
	build_mode = false
	get_node("UI/BuildingPreview").queue_free()
	$UI/HUD/BuildButtons.visible = true
	$UI/HUD/DoneButton.visible = true

#func has_neighbor_road_connected_to_main_hall(pos):
#	for neighbor in get_neighbors(pos):
#		if get_type_from_buildings_data_array(neighbor) == "Main_Hall":
#			return true
#		elif get_type_from_buildings_data_array(neighbor) == "Road":
#				if get_connected_from_map_data(neighbor):
#					return true
##			if entry["base"] == neighbor:
##				if get_type_from_map_data(neighbor) == "Main_Hall":
##					return true
##				elif get_type_from_map_data(neighbor) == "Road":
##					if entry["connected"]:
##						return true
#	return false


func get_type_from_buildings_data_array(pos):
	for item in buildings_data_array:
		for cell in get_atlas_positions_array_from_dims(item["dims"],item["base"]):
			if cell == pos:
				return item["type"]


#func get_connected_from_buildings_data_array(pos):
#	for item in buildings_data_array:
#		if item["type"] == "Road":
#			if item["base"] == pos:
#				return item["connected"]
#	return false
#		for cell in entry["atlas"]:
#			if cell + entry["base"] == pos:
#				return entry["connected"]

#func has_neighbor_road_connected(base_pos,atlas) -> bool:
#	for cell in atlas:
#		for neighbor in get_neighbors(base_pos+cell):
#			# if n "road" and "connected"
#
#			if get_type_from_buildings_data_array(neighbor) == "Road":
#				if get_connected_from_buildings_data_array(neighbor):
#					return true
#	return false


#func prepare_to_place_dict():
#	var dict = {}
#	var building_atlas = [Vector2i(0,0)] if build_type == "Road" else _get_atlas_array($Buildings.tile_set.get_source(BUILDING_TYPE[build_type.to_upper()]))
#	var has_connection: bool
#	if build_type == "Main_Hall":
#		has_connection = true
#	else:
#		has_connection = false
#
#	dict = {
#			"id": str(Time.get_unix_time_from_system()).split(".")[0],
#			"type": build_type,
#			"base": Vector2i(build_location)/32,
#			"level": 1,
#			"atlas": building_atlas,
#			"connected": has_connection,
#			"last_coll": str(0) if build_type == "Road" else str(Time.get_unix_time_from_system()).split(".")[0]
#		}
#	buildings_data_array.append(dict)
#	if build_type == "Road":
#		check_and_refresh_new_for_mh(Vector2i(build_location)/32,0)
#	return dict

func erase_building(btn_name,dict):
#	print(dict)
	if btn_name == "Yes":
		
		buildings_data_array.erase(dict)
		
		# if road -> 1 - change neighbor roadtrees from base_pos.
		#     if roadtree == false -> check all buildings along the roadtree, if they
		#     has connection to MH.
		# if MH -> 
		
		for cell in get_atlas_positions_array_from_dims(dict["dims"],dict["base"]):
			$Buildings.erase_cell(0, cell)
		file_manager.save_to_file("buildings_data", buildings_data_array)
		
		desactivate_dialog_btns()
	elif btn_name == "No":
		desactivate_dialog_btns()

func collect_all_buildings_along_the_roadtree(road_tree):
	var result = []
	for road_pos in road_tree:
		for n in get_neighbors_for_position(road_pos):
			if is_type_not_road_or_main_hall(n):
				var bui = get_item_from_buildings_data_array_by_position(n)
				if !result.has(bui):
					result.append(bui)
	return result



func get_neighbors_for_building(base_pos,dims):
	var result = []
	var pos_array = get_atlas_positions_array_from_dims(dims,base_pos)
	for pos in pos_array:
		if pos.x - base_pos.x == 0 or pos.y - base_pos.y == 0 or pos.x - base_pos.x + 1 == dims.x or pos.y - base_pos.y + 1 == dims.y:
			for n in get_neighbors_for_position(pos):
				if pos_array.has(n):
					continue
				else:
					if $Land.get_cell_source_id(0,n) >= 0:
						result.append(n)
	return result


func is_road_connected_to_MH(pos: Vector2i) -> bool:
	var road_tree = get_road_tree(pos) #[pos]
#	recursive_collecting_roads(pos, road_tree)
	for road_pos in road_tree:
		for n in get_neighbors_for_position(road_pos):
			if get_type_from_buildings_data_array(n) == "Main_Hall":
				return true
	return false

func get_road_tree(pos):
	var road_tree = [pos]
	recursive_collecting_roads(pos, road_tree)
	return road_tree

func recursive_collecting_roads(pos, array):
	for n in get_neighbors_for_position(pos):
		if !array.has(n):
			if get_type_from_buildings_data_array(n) == "Road":
				array.append(n)
				recursive_collecting_roads(n, array)

func get_connected_for_building_to_place(dims) -> bool:
	for n in get_neighbors_for_building(build_location,dims):
		if get_type_from_buildings_data_array(n) == "Road":
			if is_road_connected_to_MH(n):
				return true
	return false

func place_building():
	if place_valid:
		# -1- prepare dictionary
		var dict = {}
		var dims = Vector2i(1,1) if build_type == "Road" else Vector2i(2,2)
		if build_type == "Main_Hall":
			dims = Vector2i(6,7)
		var connected
		if build_type == "Road":
			connected = is_road_connected_to_MH(build_location)
#			print(collect_all_buildings_along_the_roadtree(get_road_tree(build_location)))
		elif build_type == "Main_Hall":
			connected = true
		else:
			connected = get_connected_for_building_to_place(dims)
			
		dict = {
			"id": str(Time.get_unix_time_from_system()).split(".")[0],
			"type": build_type,
			"base": build_location,
			"level": 1,
			"dims": dims,
			"connected": connected,
			"last_coll": str(0) if build_type == "Road" else str(Time.get_unix_time_from_system()).split(".")[0]
		}
		# -2- place building
		if build_type == "Road":
			$Buildings.set_cells_terrain_connect(0,[build_location],0,0,false)
		else:
			for cell in get_atlas_positions_array_from_dims(dims,build_location):
				if connected:
					$Buildings.set_cell(0,cell,BUILDING_TYPE[build_type.to_upper()],Vector2i(0,0)+cell)
				else:
					$Buildings.set_cell(0,cell,BUILDING_TYPE[build_type.to_upper()]+2,Vector2i(0,0)+cell)
		# -3- save changes
		buildings_data_array.append(dict)
		file_manager.save_to_file("buildings_data", buildings_data_array)
	update_map()



#func check_and_refresh_new_for_mh(pos,d):
#	var deep = d
#	for n in get_neighbors(pos):
##		if get_atlas_type_for_tile($Buildings,n) == -1:
##			continue
##		else:
#		if get_type_from_buildings_data_array(n) == "Main_Hall":
#			change_connected(pos,true)
#			return
#		elif get_type_from_buildings_data_array(n) == "Road":
#			check_and_refresh_new_for_mh(n,deep+1)
#			return
##		change_connected(n,false)


#func refresh_neighbors_connected(pos):
#	for n in get_neighbors(pos):
#		if get_type_from_buildings_data_array(n) == "Road":
#			if get_connected_from_map_data(n):
#				continue
#			else:
#				change_connected(n,true)
#				refresh_neighbors_connected(n)
##				return

 

func get_index_from_buildings_data_array(pos):
	for i in buildings_data_array.size():
		if buildings_data_array[i]["base"] == pos:
			return i

#func change_connected(pos,b):
#	print(get_index_from_map_data(pos))
#	var entry = buildings_data_array.pop_at(get_index_from_map_data(pos))
##	map_data.remove_at(get_index_from_map_data(pos))
#	entry["connected"] = b
#	buildings_data_array.append(entry)


func connect_builder_buttons():
	for b in get_tree().get_nodes_in_group("builder_buttons"):
		b.pressed.connect(init_build_mode.bind(b))


func _get_atlas(map: TileMap, type: int):
	return map.tile_set.get_source(type)


func _get_atlas_array(atlas: TileSetAtlasSource) -> Array:
	var result = []
	var cells = atlas.get_atlas_grid_size()
	for cell in cells.x * cells.y:
		result.append(atlas.get_tile_id(cell))
	return result


#func get_neighbors(pos: Vector2i) -> Array:
#	var result = []
#	for dir in directions:
#		result.append(dir+pos)
#	return result

func _on_done_button_pressed() -> void:
	if has_lands_preview:
		for l in get_node("UI/LandPreviews").get_children():
			l.queue_free()
	$UI.modulate_ui(Color(1,1,1,1))
	has_lands_preview = false
	$Cells.visible = false
	has_painted_building = false
	
	sell_mode = false
	move_mode = false
	build_mode = false
	drag_mode = false
	expanse_mode = false
	
	DisplayServer.cursor_set_custom_image(default_cursor)
	$UI/HUD/BuildButtons.visible = false
	$UI/HUD/Menu.visible = true
	$UI/HUD/DoneButton.visible = false
	$UI/HUD/Dialog.visible = false
	var color_rect_array = $UI/ColoredRectangles.get_children()
	if color_rect_array.size() > 0:
		for r in color_rect_array:
			r.queue_free()


func build_main_hall():
	own_lands_array = [
		Vector2i(15, 0),
		Vector2i(20, 0),
		Vector2i(20, 5),
		Vector2i(15, 5),
		Vector2i(15, 10),
		Vector2i(20, 10)
		]
	# build main hall
	var main_hall_dict = {
				"id": str(Time.get_unix_time_from_system()).split(".")[0],
				"type": "Main_Hall",
				"base": Vector2i(15,0),
				"level": 1,
				"dims": Vector2i(6,7),
				"connected": true,
				"last_coll": str(Time.get_unix_time_from_system()).split(".")[0]
			}
	
	var main_hall_atlas = _get_atlas_array(_get_atlas($Buildings, BUILDING_TYPE.MAIN_HALL))
	for cell in main_hall_atlas:
		$Buildings.set_cell(0,Vector2i(15,0) + cell,BUILDING_TYPE.MAIN_HALL,Vector2i(0,0) + cell)
	buildings_data_array.append(main_hall_dict)
	
	# build 1 road
	var road_dict = {}
	road_dict = {
		"id": str(Time.get_unix_time_from_system() + 1).split(".")[0],
		"type": "Road",
		"base": Vector2i(17,7),
		"level": 1,
		"dims": Vector2i(1,1),
		"connected": true,
		"last_coll": 0
	}
	$Buildings.set_cells_terrain_connect(0,[road_dict["base"]],0,0,false)
	buildings_data_array.append(road_dict)
	
	# save mh and road to []
	file_manager.save_to_file("buildings_data",buildings_data_array)
	file_manager.save_to_file("lands_data",own_lands_array)
	
	# change config
	file_manager.save_to_file("config","not_first_time")

func load_config():
	var content = file_manager.load_from_file("config")
	if content == "not_first_time":
		is_first_time = false


func load_from_buildings_data_file() :
	var content: Array = file_manager.load_from_file("buildings_data") as Array
	buildings_data_array.clear()
	buildings_data_array.append_array(content)
	
	content = file_manager.load_from_file("lands_data") as Array
	own_lands_array.clear()
	own_lands_array.append_array(content)


func update_map():
	
	for land in own_lands_array:
		$Land.set_pattern(0,land,$Land.tile_set.get_pattern(0))
	
	var roads_array = []
	for item in buildings_data_array:
		if item["type"] == "Road":
			roads_array.append(item["base"])
		else:
			for cell in get_atlas_positions_array_from_dims(item["dims"],item["base"]):
				var sourse_id = BUILDING_TYPE[item["type"].to_upper()] if item["connected"] else BUILDING_TYPE[item["type"].to_upper()] + 2
				$Buildings.set_cell(0, cell, sourse_id, cell - item["base"])
	$Buildings.set_cells_terrain_connect(0,roads_array,0,0,false)

func get_atlas_positions_array_from_dims(dims,base) -> Array:
	var result = []
	for y in dims.y:
		for x in dims.x:
			result.append(base + Vector2i(x,y))
	return result

func get_item_from_buildings_data_array_by_position(pos):
	for item in buildings_data_array:
		for cell in get_atlas_positions_array_from_dims(item["dims"],item["base"]):
			if cell == pos:
				return item

func get_neighbors_for_position(pos) -> Array:
	var result = []
	for dir in directions:
		result.append(pos + dir)
	return result

func is_cell_legal_to_place(cell: Vector2i) -> bool:
	return $Land.get_used_cells(0).has(cell) and $Land.get_cell_source_id(0, cell) == 0


func show_lands_for_sale():
#	$Base.modulate = Color(1,1,1,0.5)
	$UI.modulate_ui(Color(1,1,1,0.4))
	var all_lands = $Land.get_used_cells(0)
	for cell in all_lands:
		if cell.x % 5 == 0 and cell.y % 5 == 0:
			if !own_lands_array.has(cell):
				own_lands_array.append(cell)
	
	for_sale_lands_array.clear()
	for land_base in own_lands_array:
		for dir in directions:
			var cell = land_base + dir*5
			if cell.x >= 0 and cell.x < 40 and cell.y >= 0 and cell.y < 30 and !own_lands_array.has(cell):
				if !for_sale_lands_array.has(cell):
					for_sale_lands_array.append(cell)

	for cell in for_sale_lands_array:
		$UI.set_lands_for_sale_preview("expansion",cell * 32)


func has_point_in_for_sale_lands(point: Vector2i) -> bool:
	for pos in for_sale_lands_array:
		if Rect2i(pos,Vector2i(5,5)).has_point(point):
			return true
	return false


func get_rect_for_sale(point: Vector2i):
	for pos in for_sale_lands_array:
		if Rect2i(pos,Vector2i(5,5)).has_point(point):
			return pos


func connect_dialog_buttons(b_dict,func_name):
	for b in get_tree().get_nodes_in_group("dialog_buttons"):
		if !b.pressed.is_connected(func_name):
			b.pressed.connect(func_name.bind(b.name,b_dict))


func is_type_not_road_or_main_hall(pos : Vector2i) -> bool:
	return $Buildings.get_cell_source_id(0,pos) > 1

func disconnect_dialog_buttons(func_name):
#	print(func_name)
	if func_name != null:
		for b in get_tree().get_nodes_in_group("dialog_buttons"):
			if b.pressed.is_connected(func_name):
				b.pressed.disconnect(func_name)
