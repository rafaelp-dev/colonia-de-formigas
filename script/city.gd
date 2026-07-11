extends Node2D

@onready var label = $Label

func _ready():
	var index = get_index()
	
	if index < 26:
		label.text = char(65 + index)
	else:
		label.text = str(index)
	
	# Não precisa mexer na label.position aqui por código! 
	# Deixe o valor fixo que você configurou no Inspetor.
