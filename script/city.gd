extends Node2D

@onready var label = $Label

func _ready():
	var index = get_index()
	
	if index < 26:
		label.text = char(65 + index)
	else:
		label.text = str(index)
	
