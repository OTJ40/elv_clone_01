extends Node2D


enum BUILDING_TYPE{
	MAIN_HALL,
	ROAD,
	HOUSE,
	WORKSHOP
}

var is_first = true
var is_red = false
var has_lands_preview = false

var build_mode = false
var sell_mode = false
var move_mode = false
var drag_mode = false

var build_valid = false
var build_type
var build_location

var sell_cursor
var move_cursor
var default_cursor
#var mouse_position

var map_data = []

@onready var buildings_map = $Buildings
@onready var menu = $UI/HUD/Menu
@onready var done_btn = $UI/HUD/DoneButton
@onready var color_rects = $UI/ColorRects
#@onready var road_btn = $UI/HUD/BuildButtons/MarginContainer/Road

var own_lands = []
var for_sale_lands = []
var directions = [Vector2i(0,5),Vector2i(0,-5),Vector2i(5,0),Vector2i(-5,0)]



func _ready() -> void:
	
	

	load_config()
	if is_first:
		build_main_hall()
	else:
		load_from_map_data()
		refresh_map()
	default_cursor = load("res://assets/ui/default_cursor_32.png")
	move_cursor = load("res://assets/ui/move_cursor_32.png")
	sell_cursor = load("res://assets/ui/sell_cursor_32.png")
	DisplayServer.cursor_set_custom_image(default_cursor)
	for b in get_tree().get_nodes_in_group("menu_buttons"):
		b.pressed.connect(init_menu_mode.bind(b))
	connect_builder_buttons()


func show_lands_for_sale():
	var all_lands = $Land.get_used_cells(0)
	for cell in all_lands:
		if cell.x % 5 == 0 and cell.y % 5 == 0:
			if !own_lands.has(cell):
				own_lands.append(cell)
#	print(own_lands)
	for l in own_lands:
		for dir in directions:
			var c = l + dir
			if c.x >= 0 and c.x < 40 and c.y >= 0 and c.y < 30 and !own_lands.has(c):
				if !for_sale_lands.has(c):
					for_sale_lands.append(c)
#	print(for_sale_lands)
	
#	var for_sale_atlas = _get_atlas_array(_get_atlas($Land,1))
#	print(for_sale_atlas)
	for cell in for_sale_lands:
		$UI.set_lands_for_sale_preview("expansion",(cell)*32)
#		for tile in for_sale_atlas:
#			$Land.set_cell(0,cell + tile,1,Vector2i(0,0)+ tile)

func load_config():
	var content = FileAccess.open("user://config.txt", FileAccess.READ).get_as_text()
	if int(content) == 0:
		is_first = false


func is_legal_to_place(tile: Vector2i) -> bool:
	return $Land.get_used_cells(0).has(tile) and get_atlas_type_for_tile($Land,tile) == 0


func build_main_hall():
	# build main hall
	var main_hall_dict = {}
	var main_hall_atlas = _get_atlas_array(_get_atlas(buildings_map, BUILDING_TYPE.MAIN_HALL))
	for tile in main_hall_atlas:
		buildings_map.set_cell(0,Vector2i(15,0) + tile,BUILDING_TYPE.MAIN_HALL,Vector2i(0,0) + tile)
		
	main_hall_dict = {
				"id": str(Time.get_unix_time_from_system()).split(".")[0],
				"type": "Main_Hall",
				"base": Vector2i(15,0),
				"level": 1,
				"atlas": main_hall_atlas,
				"last_coll": str(Time.get_unix_time_from_system()).split(".")[0]
			}
	map_data.append(main_hall_dict)
	
	# build 1 road
	var road_dict = {}
	road_dict = {
		"id": str(Time.get_unix_time_from_system()).split(".")[0],
		"type": "Road",
		"base": Vector2i(17,7),
		"level": 1,
		"atlas": [Vector2i(0,0)],
		"last_coll": 0
	}
	buildings_map.set_cells_terrain_connect(0,[Vector2i(17,7)],0,0,false)
	map_data.append(road_dict)
	
	# save mh and road to []
	save_to_map_data()
	
	# change config
	var config_file = FileAccess.open("user://config.txt", FileAccess.WRITE)
	config_file.store_string(str(0))
	


func _process(_delta: float) -> void:
	print(build_type)
	if build_mode or drag_mode:
		update_building_preview()


func _unhandled_input(event: InputEvent) -> void:
#	print(event)
	if build_mode:
		$Ground.modulate = Color(1,1,1,0.5)
		if event.is_action_pressed("ui_accept"):
			verify_and_build()
			if build_type != "Road":
				cancel_build_mode()
		if event.is_action_pressed("ui_cancel"):
			cancel_build_mode()

	if sell_mode:
		if event.is_action_pressed("ui_accept"):
			var current_tile = get_current_tile(get_global_mouse_position())
			if get_atlas_type_for_tile(buildings_map,current_tile) == BUILDING_TYPE.MAIN_HALL:
				print("You can`t!")
			else:
				if buildings_map.get_used_cells(0).has(current_tile):
					for entry in map_data:
						for cell in entry["atlas"]:
							if current_tile == cell + entry["base"]:
								if !is_red:
		#							print(typeof(entry))
									$UI/HUD/SellContainer/VBoxContainer/Label.text = "Sell "+ entry["type"]+"?"
									paint_building(entry,Color(1,0,0,0.5))
									$UI/HUD/SellContainer.visible = true
									menu.visible = false
									connect_sell_buttons(entry)

	if move_mode:
		$Ground.modulate = Color(1,1,1,0.5)
		if !has_lands_preview:
			show_lands_for_sale()
			has_lands_preview = true
		if event.is_action_pressed("ui_accept"):
			var current_tile = get_current_tile(get_global_mouse_position())
			if buildings_map.get_used_cells(0).has(current_tile):
				if get_atlas_type_for_tile(buildings_map,current_tile) == BUILDING_TYPE.ROAD:
					for entry in map_data:
						if current_tile == entry["base"]:
							selling_building("Yes",entry)
							get_node("UI").set_building_preview(entry["type"], get_global_mouse_position())
							build_type = entry["type"]
#							$Mesh.visible = true
							drag_mode = true
				else:
					for entry in map_data:
						for v in entry["atlas"]:
							if current_tile == v + entry["base"]:
								paint_building(entry,Color(0,0,1,0.5))
								selling_building("Yes",entry)
								get_node("UI").set_building_preview(entry["type"], get_global_mouse_position())
								build_type = entry["type"]
								$Mesh.visible = true
								drag_mode = true

	if drag_mode:
		done_btn.visible = false
		move_mode = false
		if build_valid:
			if event.is_action_pressed("ui_accept"):
				verify_and_build()
				cancel_drag_mode()


func connect_sell_buttons(b_dict):
	for b in get_tree().get_nodes_in_group("sell_buttons"):
		if !b.pressed.is_connected(selling_building):
			b.pressed.connect(selling_building.bind(b.name,b_dict))


func disconnect_sell_buttons():
	for b in get_tree().get_nodes_in_group("sell_buttons"):
		if b.pressed.is_connected(selling_building):
			b.pressed.disconnect(selling_building)


func selling_building(b_name,b_dict):
	if b_name == "Yes":
		if b_dict["type"] == "Road":
			map_data.erase(b_dict)
		else:
			map_data.erase(b_dict)
		erase_building(b_dict)
		save_to_map_data()
		load_from_map_data()
		refresh_map()
		desactivate_sell_btns()
	elif b_name == "No":
		desactivate_sell_btns()


func erase_building(dict):
	for cell in dict["atlas"]:
		buildings_map.erase_cell(0, cell + dict["base"])


func desactivate_sell_btns():
	$UI/HUD/SellContainer.visible = false
	var color_rect_array = color_rects.get_children()
	if color_rect_array.size() > 0:
		for i in color_rect_array:
			i.queue_free()
	if is_red:
		is_red = false
	disconnect_sell_buttons()


func paint_building(dict: Dictionary,color):
	for cell in dict["atlas"]:
		var cr = ColorRect.new()
		cr.size = Vector2i(32,32)
		cr.position = (cell + dict["base"])*32
		cr.modulate = color
		color_rects.add_child(cr)
	is_red = true


func load_from_map_data() :
	var file = FileAccess.open("user://map_data.txt", FileAccess.READ)
	if file != null:
		var content = file.get_var()
		if content != null:
			map_data.clear()
			map_data.append_array(content)


func refresh_map():
	var roads_tiles_array = []
	for entry in map_data:
		if entry["type"] == "Road":
			roads_tiles_array.append(entry["base"])
		else:
			for v in entry["atlas"]:
				buildings_map.set_cell(0,entry["base"]+v,BUILDING_TYPE[entry["type"].to_upper()],Vector2i(0,0)+v)
		buildings_map.set_cells_terrain_connect(0,roads_tiles_array,0,0,false)


func save_to_map_data():
	var file = FileAccess.open("user://map_data.txt", FileAccess.WRITE)
	file.store_var(map_data)


func init_menu_mode(btn):
	match btn.name:
		"BuilderButton":
			$UI/HUD/BuildButtons.visible = true
			menu.visible = false
			done_btn.visible = true
		"SellButton":
			DisplayServer.cursor_set_custom_image(sell_cursor)
			sell_mode = true
			menu.visible = false
			done_btn.visible = true
		"MoveButton":
			move_mode = true
#			show_lands_for_sale()
			$Mesh.visible = true
			DisplayServer.cursor_set_custom_image(move_cursor)
			menu.visible = false
			done_btn.visible = true
		"ResearchButton":
			pass
		"WorldMapButton":
			pass
		"InventoryButton":
			pass
		

func init_build_mode(type):
	build_mode = true
	build_type = type.name
	$Mesh.visible = true
	$UI/HUD/BuildButtons.visible = false
	done_btn.visible = false
	if build_type != "Expansion":
		get_node("UI").set_building_preview(build_type, get_global_mouse_position())


func get_current_tile(pos):
	return buildings_map.local_to_map(pos)


func update_building_preview():
	var current_tile = get_current_tile(get_global_mouse_position())
	var tile_pos = buildings_map.map_to_local(current_tile)
	if build_type == "Expansion":
		move_mode = true
		build_mode = false
	elif build_type != "Road":
		var build_type_atlas_coords = _get_atlas_array(_get_atlas(buildings_map, BUILDING_TYPE[build_type.to_upper()]))
		var count_free = 0
		for tile in build_type_atlas_coords:
			if get_atlas_type_for_tile(buildings_map,current_tile + tile) == -1 and is_legal_to_place(current_tile + tile):
				count_free += 1
		if count_free == build_type_atlas_coords.size():
			$UI.update_building_preview(tile_pos,"33fd146b")
			build_valid = true
			build_location = tile_pos
		else:
			$UI.update_building_preview(tile_pos,"f600039c")
			build_valid = false
	else:
		if get_atlas_type_for_tile(buildings_map,current_tile) == -1 and is_legal_to_place(current_tile):
			$UI.update_building_preview(tile_pos,"33fd146b")
			build_valid = true
			build_location = tile_pos
		else:
			$UI.update_building_preview(tile_pos,"f600039c")
			build_valid = false

func get_atlas_type_for_tile(map: TileMap, tile: Vector2i) -> int:
	return map.get_cell_source_id(0, tile)

func cancel_drag_mode():
	$Mesh.visible = false
	build_valid = false
	drag_mode = false
	move_mode = true
	$Mesh.visible = true
	done_btn.visible = true
	get_node("UI/BuildingPreview").queue_free()

func cancel_build_mode():
	$Mesh.visible = false
	build_valid = false
	build_mode = false
	get_node("UI/BuildingPreview").queue_free()
	$UI/HUD/BuildButtons.visible = true
	done_btn.visible = true

func verify_and_build():
	if build_valid:
		var dict = {}
		var building_atlas = [Vector2i(0,0)] if build_type == "Road" else _get_atlas_array(_get_atlas(buildings_map, BUILDING_TYPE[build_type.to_upper()]))
		dict = {
				"id": str(Time.get_unix_time_from_system()).split(".")[0],
				"type": build_type,
				"base": Vector2i(build_location)/32,
				"level": 1,
				"atlas": building_atlas,
				"last_coll": str(0) if build_type == "Road" else str(Time.get_unix_time_from_system()).split(".")[0]
			}
		if build_type == "Road":
			buildings_map.set_cells_terrain_connect(0,[Vector2i(build_location)/32],0,0,false)
		else:
			for tile in building_atlas:
				buildings_map.set_cell(0,Vector2i(build_location)/32+tile,BUILDING_TYPE[build_type.to_upper()],Vector2i(0,0)+tile)
		map_data.append(dict)
		save_to_map_data()


func connect_builder_buttons():
	for b in get_tree().get_nodes_in_group("builder_buttons"):
		b.pressed.connect(init_build_mode.bind(b))


func _get_atlas(map: TileMap, type: int):
	return map.tile_set.get_source(type)


func _get_atlas_array(atlas: TileSetAtlasSource) -> Array:
	var result = []
	var tiles = atlas.get_atlas_grid_size()
	for t in tiles.x * tiles.y:
		result.append(atlas.get_tile_id(t))
	return result


func _on_done_button_pressed() -> void:
	#return to menu
	if has_lands_preview:
		for l in get_node("UI/LandPreviews").get_children():
			l.queue_free()
	$Ground.modulate = Color(1,1,1,1)
	sell_mode = false
	move_mode = false
	build_mode = false
	drag_mode = false
	is_red = false
	has_lands_preview = false
	$Mesh.visible = false
	DisplayServer.cursor_set_custom_image(default_cursor)
	$UI/HUD/BuildButtons.visible = false
	menu.visible = true
	done_btn.visible = false
	$UI/HUD/SellContainer.visible = false
	var color_rect_array = color_rects.get_children()
	if color_rect_array.size() > 0:
		for i in color_rect_array:
			i.queue_free()


