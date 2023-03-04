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
#var mouse_position

var file_manager: FileManager = FileManager.new()
var buildings_data_array = []

#@onready var buildings_map = $Buildings
@onready var menu = $UI/HUD/Menu
#@onready var done_btn = $UI/HUD/DoneButton
#@onready var color_rects = $UI/ColorRects
#@onready var road_btn = $UI/HUD/BuildButtons/MarginContainer/Road

var own_lands_array = []
var for_sale_lands = []
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


func show_lands_for_sale():
#	$Base.modulate = Color(1,1,1,0.5)
	$UI.modulate_ui(Color(1,1,1,0.4))
	var all_lands = $Land.get_used_cells(0)
	for cell in all_lands:
		if cell.x % 5 == 0 and cell.y % 5 == 0:
			if !own_lands_array.has(cell):
				own_lands_array.append(cell)
	
	for_sale_lands.clear()
	for l in own_lands_array:
		for dir in directions:
			var c = l + dir*5
			if c.x >= 0 and c.x < 40 and c.y >= 0 and c.y < 30 and !own_lands_array.has(c):
				if !for_sale_lands.has(c):
					for_sale_lands.append(c)

	for cell in for_sale_lands:
		$UI.set_lands_for_sale_preview("expansion",cell * 32)


func has_point_in_for_sale_lands(point: Vector2i) -> bool:
	for pos in for_sale_lands:
		if Rect2i(pos,Vector2i(5,5)).has_point(point):
			return true
	return false


func get_rect_for_sale(point: Vector2i):
	for pos in for_sale_lands:
		if Rect2i(pos,Vector2i(5,5)).has_point(point):
			return pos



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
					for entry in buildings_data_array:
						for cell in entry["atlas"]:
							if current_tile == cell + entry["base"]:
								if !has_painted_building:
									$UI/HUD/DialogContainer/VBoxContainer/Label.text = "Sell "+ entry["type"]+"?"
									paint_building(entry["atlas"],entry["base"],Color(1,0,0,0.5))
									$UI/HUD/DialogContainer.visible = true
									menu.visible = false
									var cal = Callable(self,"selling_building")
									connect_dialog_buttons(entry,cal)

	if move_mode:
#		$Base.modulate = Color(1,1,1,0.5)
		if !has_lands_preview:
			show_lands_for_sale()
			has_lands_preview = true
		if event.is_action_released("ui_accept"):
			
			var current_cell = get_current_tile(get_global_mouse_position())
			if $Buildings.get_used_cells(0).has(current_cell):
				for item in buildings_data_array:
					for position in get_atlas_positions_array_from_dims(item["dims"],item["base"]):
						if current_cell == position:
							eraselling_building("Yes",item)
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
			var current_tile = get_current_tile(get_global_mouse_position())
			if has_point_in_for_sale_lands(current_tile):
				var rect_for_sale = get_rect_for_sale(current_tile)
				$UI/HUD/Dialog/VBoxContainer/Label.text = "Buy Expansion?"
				paint_building(_get_atlas_array(_get_atlas($Land, 1)),rect_for_sale,Color(0,0,1,0.5))
				$UI/HUD/Dialog.visible = true
				var callable = Callable(self,"buy_expansion")
				connect_dialog_buttons({"position": rect_for_sale},callable)





func connect_dialog_buttons(b_dict,func_name):
	for b in get_tree().get_nodes_in_group("dialog_buttons"):
		if !b.pressed.is_connected(func_name):
			b.pressed.connect(func_name.bind(b.name,b_dict))


func disconnect_dialog_buttons(func_name):
#	print(func_name)
	if func_name != null:
		for b in get_tree().get_nodes_in_group("dialog_buttons"):
			if b.pressed.is_connected(func_name):
				b.pressed.disconnect(func_name)


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


func eraselling_building(b_name,dict):
	if b_name == "Yes":
		buildings_data_array.erase(dict)
#		erase_building(b_dict)
		for cell in get_atlas_positions_array_from_dims(dict["dims"],dict["base"]):
			$Buildings.erase_cell(0, cell)
		file_manager.save_to_file("buildings_data", buildings_data_array)
#		load_from_buildings_data_file()
		update_map()
		desactivate_dialog_btns()
	elif b_name == "No":
		desactivate_dialog_btns()


#func erase_building(dict):
#	for cell in dict["atlas"]:
#		$Buildings.erase_cell(0, cell + dict["base"])


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
		c = Callable(self,"selling_building")
	if expanse_mode:
		c = Callable(self,"buy_expansion")
		
	disconnect_dialog_buttons(c)


func paint_building(rects_array: Array,pos: Vector2i,color):
	for cell in rects_array:
		var cr = ColorRect.new()
		cr.size = Vector2i(32,32)
		cr.position = (cell + pos)*32
		cr.modulate = color
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$UI/ColoredRectangles.add_child(cr)
	has_painted_building = true


func load_from_buildings_data_file() :
	
	var content: Array = file_manager.load_from_file("buildings_data") as Array
	buildings_data_array.clear()
	buildings_data_array.append_array(content)
	
	content = file_manager.load_from_file("lands_data") as Array
	own_lands_array.clear()
	own_lands_array.append_array(content)
	
#	var file = FileAccess.open("user://map_data.txt", FileAccess.READ)
#	var land_file = FileAccess.open("user://land_data.txt", FileAccess.READ)
#	if file != null:
#		var content = file.get_var()
#		if content != null:
#			buildings_data_array.clear()
#			buildings_data_array.append_array(content)
#	if land_file != null:
#		var content = land_file.get_var()
#		if content != null:
#			own_lands_array.clear()
#			own_lands_array.append_array(content)



func save_to_map_data():
	var file = FileAccess.open("user://map_data.txt", FileAccess.WRITE)
	var land_file = FileAccess.open("user://land_data.txt", FileAccess.WRITE)
	file.store_var(buildings_data_array)
	land_file.store_var(own_lands_array)


func init_menu_mode(btn):
	match btn.name:
		"BuilderButton":
			$UI/HUD/BuildButtons.visible = true
			menu.visible = false
			$UI/HUD/DoneButton.visible = true
		"SellButton":
			DisplayServer.cursor_set_custom_image(sell_cursor)
			sell_mode = true
			menu.visible = false
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


func get_current_tile(pos):
	return $Buildings.local_to_map(pos)


func update_building_preview():
	var current_cell = get_current_tile(get_global_mouse_position())
	var current_cell_in_px = Vector2i($Buildings.map_to_local(current_cell))
	
	var atlas = _get_atlas_array($Buildings.tile_set.get_source(BUILDING_TYPE[build_type.to_upper()])) if build_type != "Road" else [Vector2i(0,0)]
	var count_cells = 0
	for cell in atlas:
		if $Buildings.get_cell_source_id(0,current_cell + cell) == -1 and cell_legal_to_place(current_cell + cell):
			count_cells += 1
	if count_cells == atlas.size():
		$UI.update_building_preview(current_cell_in_px,"33fd146b")
		place_valid = true
		build_location = current_cell
	else:
		$UI.update_building_preview(current_cell_in_px,"f600039c")
		place_valid = false
	
#	if build_type == "Expansion":
#		show_lands_for_sale()
#	elif build_type != "Road":
#		var atlas = _get_atlas_array(_get_atlas($Buildings, BUILDING_TYPE[build_type.to_upper()]))
#		var count_cells = 0
#		for cell in atlas:
#			if $Buildings.get_cell_source_id(0,current_tile + cell) == -1 and is_legal_to_place(current_tile + cell):
#				count_cells += 1
#		if count_cells == atlas.size():
#			$UI.update_building_preview(tile_pos,"33fd146b")
#			place_valid = true
#			build_location = tile_pos
#		else:
#			$UI.update_building_preview(tile_pos,"f600039c")
#			place_valid = false
#	else:
#		if $Buildings.get_cell_source_id(0,current_tile) == -1 and is_legal_to_place(current_tile):
#			$UI.update_building_preview(tile_pos,"33fd146b")
#			place_valid = true
#			build_location = tile_pos
#		else:
#			$UI.update_building_preview(tile_pos,"f600039c")
#			place_valid = false

#func get_atlas_type_for_tile(map: TileMap, tile: Vector2i) -> int:
#	return map.get_cell_source_id(0, tile)

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

func has_neighbor_road_connected_to_main_hall(pos):
	for neighbor in get_neighbors(pos):
		if get_type_from_buildings_data_array(neighbor) == "Main_Hall":
			return true
		elif get_type_from_buildings_data_array(neighbor) == "Road":
				if get_connected_from_map_data(neighbor):
					return true
#			if entry["base"] == neighbor:
#				if get_type_from_map_data(neighbor) == "Main_Hall":
#					return true
#				elif get_type_from_map_data(neighbor) == "Road":
#					if entry["connected"]:
#						return true
	return false


func get_type_from_buildings_data_array(pos):
	for item in buildings_data_array:
		for cell in get_atlas_positions_array_from_dims(item["dims"],item["base"]):
			if cell == pos:
				return item["type"]


func get_connected_from_map_data(pos):
	for item in buildings_data_array:
		if item["type"] == "Road":
			if item["base"] == pos:
				return item["connected"]
	return false
#		for cell in entry["atlas"]:
#			if cell + entry["base"] == pos:
#				return entry["connected"]

func has_neighbor_road_connected(base_pos,atlas) -> bool:
	for cell in atlas:
		for neighbor in get_neighbors(base_pos+cell):
			# if n "road" and "connected"
			
			if get_type_from_buildings_data_array(neighbor) == "Road":
				if get_connected_from_map_data(neighbor):
					return true
	return false


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


func place_building():
	if place_valid:
		# -1- prepare dictionary
		var dict = {}
		var dims = Vector2i(1,1) if build_type == "Road" else Vector2i(2,2)
		if build_type == "Main_Hall":
			dims = Vector2i(6,7)
		var connected = true # NB
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

 

func get_index_from_map_data(pos):
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


func get_neighbors(pos: Vector2i) -> Array:
	var result = []
	for dir in directions:
		result.append(dir+pos)
	return result

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

#func is_legal_to_place(tile: Vector2i) -> bool:
#	return $Land.get_used_cells(0).has(tile) and $Land.get_cell_source_id(0,tile) == 0

func cell_legal_to_place(cell: Vector2i) -> bool:
	return $Land.get_used_cells(0).has(cell) and $Land.get_cell_source_id(0, cell) == 0
