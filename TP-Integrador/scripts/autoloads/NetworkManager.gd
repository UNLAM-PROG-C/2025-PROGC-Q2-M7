# NetworkManager.gd - Gestión básica de conexión de red
extends Node

var es_servidor := false
var conexion: ENetMultiplayerPeer = null

func _ready():
	pass

func iniciar_servidor_salas():
	es_servidor = true
	print("SERVIDOR MULTISALA INICIANDO...")
	call_deferred("_cambiar_a_servidor_salas")

func _cambiar_a_servidor_salas():
	get_tree().change_scene_to_file("res://scenes/servidor/ServerManager.tscn")

func iniciar_cliente_con_ip(ip: String):
	conexion = ENetMultiplayerPeer.new()
	var error := conexion.create_client(ip, 7777)
	if error != OK:
		print("ERROR al conectar cliente a", ip, ":", error)
		get_tree().quit()
		return

	multiplayer.multiplayer_peer = conexion
	print("Intentando conectar al servidor en", ip, ":7777...")

	multiplayer.connected_to_server.connect(_al_conectar)
	multiplayer.connection_failed.connect(_fallo_conexion)
	multiplayer.server_disconnected.connect(_servidor_desconectado)
	multiplayer.peer_disconnected.connect(_peer_se_fue)

func _al_conectar():
	print("¡Conectado al servidor! Mi id:", multiplayer.get_unique_id())
	get_tree().change_scene_to_file("res://scenes/cliente/Bienvenida.tscn")

func _fallo_conexion():
	print("No se pudo conectar al servidor")
	get_tree().quit()

func _servidor_desconectado():
	print("El servidor se desconectó")
	get_tree().quit()

func _peer_se_fue(id: int):
	if es_servidor:
		var server_handler = get_node_or_null("/root/ServerRPCHandler")
		if server_handler:
			server_handler._on_peer_disconnected(id)
