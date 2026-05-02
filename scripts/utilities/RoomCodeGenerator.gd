class_name RoomCodeGenerator

const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no 0/O or 1/I ambiguity


static func generate(length: int = 4) -> String:
	var code := ""
	for _i in length:
		code += CHARS[randi() % CHARS.length()]
	return code
