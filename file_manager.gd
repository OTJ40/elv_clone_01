extends Node

class_name FileManager

func save_to_file(filename: String, content: Variant):
	var file = FileAccess.open("user://" + filename + ".txt", FileAccess.WRITE)
#	var_to_str(content)
	file.store_string(var_to_str(content))
	file = null


func load_from_file(filename: String) -> Variant:
	var file = FileAccess.open("user://" + filename + ".txt", FileAccess.READ)
	var content = file.get_as_text() #.get_var()
#	print(typeof(content),content,file)
	file = null
	return str_to_var(content)
