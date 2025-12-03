# scenes/cliente/Bienvenida.gd
extends Control

@onready var btn_solicitar = $VBoxContainer/BtnSolicitarPartidaMaM  # ajustá el path si es distinto
@onready var btn_salir = $VBoxContainer/BtnSalir

func _ready():
	btn_solicitar.pressed.connect(_on_solicitar_pressed)
	btn_salir.pressed.connect(get_tree().quit)

func _on_solicitar_pressed():
	# Avisamos al servidor que este jugador YA QUIERE JUGAR
	ServerRPCHandler.rpc_id(1, "jugador_listo")
	get_tree().change_scene_to_file("res://scenes/cliente/EsperandoRival.tscn")
