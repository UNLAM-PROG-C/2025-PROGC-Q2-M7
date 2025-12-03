# MenuInicial.gd
extends Control

@onready var btn_servidor = $VBoxContainer/BtnServidor
@onready var btn_cliente = $VBoxContainer/BtnCliente
@onready var lbl_info = $VBoxContainer/LblInfo

func _ready():
	btn_servidor.pressed.connect(_on_btn_servidor_pressed)
	btn_cliente.pressed.connect(_on_btn_cliente_pressed)
	
	lbl_info.text = "Truco - Menú Principal"

func _on_btn_servidor_pressed():
	lbl_info.text = "Iniciando servidor..."
	deshabilitar_botones()
	
	# Iniciar servidor multisala
	NetworkManager.iniciar_servidor_salas()

func _on_btn_cliente_pressed():
	lbl_info.text = "Conectando a 127.0.0.1..."
	deshabilitar_botones()
	
	# Iniciar cliente a través de RedGlobal (siempre localhost por ahora)
	NetworkManager.iniciar_cliente_con_ip("127.0.0.1")

func deshabilitar_botones():
	btn_servidor.disabled = true
	btn_cliente.disabled = true
