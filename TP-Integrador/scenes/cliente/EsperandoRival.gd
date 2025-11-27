# scenes/cliente/EsperandoRival.gd
extends Control

@onready var label_estado = $VBoxContainer/LblEstado

func _process(delta):
	var cantidad = multiplayer.get_peers().size()
	label_estado.text = "Jugadores conectados: " + str(cantidad) + "/2"
	
	if cantidad >= 2:
		label_estado.text = "¡Rival encontrado! Esperando al servidor..."
