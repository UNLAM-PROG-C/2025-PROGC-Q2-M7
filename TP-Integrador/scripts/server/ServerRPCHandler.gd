# ServerRPCHandler.gd - Maneja todos los RPCs que procesa el servidor
extends Node

# Solo usado por el servidor para llevar el control de jugadores "listos"
var _listos: Dictionary = {}   # peer_id -> true

func _on_peer_disconnected(id: int):
	_listos.erase(id)

# ========== RPCS RECIBIDOS DEL CLIENTE ==========

# Los clientes llaman esto en el servidor para avisar que están listos
@rpc("any_peer", "reliable")
func jugador_listo():
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	
	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		print("[ServerRPCHandler] Redirigiendo jugador_listo a ServerManager para peer ", peer_id)
		servidor_salas.call_deferred("_procesar_jugador_listo", peer_id)

# Cliente avisa al servidor que quiere jugar una carta
@rpc("any_peer", "reliable")
func solicitar_jugar_carta(carta: Vector2):
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "solicita jugar carta:", carta)
	
	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.procesar_carta_jugada(sender_id, carta)

# Cliente solicita subir apuesta de truco (2=Truco, 3=Retruco, 4=Vale cuatro)
@rpc("any_peer", "reliable")
func solicitar_apuesta_truco(nivel: int):
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "solicita apuesta truco nivel", nivel)
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.solicitar_apuesta_truco(sender_id, nivel)

# Respuesta del rival a la apuesta de truco (true=quiero, false=no quiero)
@rpc("any_peer", "reliable")
func respuesta_apuesta_truco(acepta: bool):
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "responde apuesta truco acepta=", acepta)
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.respuesta_apuesta_truco(sender_id, acepta)

# Cliente notifica al servidor que está listo para una nueva mano
@rpc("any_peer", "reliable")
func jugador_listo_nueva_mano():
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "listo para nueva mano")
	
	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.jugador_listo_para_nueva_mano(sender_id)

# Cliente notifica al servidor que se rinde (se fue al mazo)
@rpc("any_peer", "reliable")
func jugador_se_fue_al_mazo():
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "se fue al mazo (rendición)")
	
	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.jugador_se_rindio(sender_id)

# Cliente canta truco (solicita subir el valor de la mano)
@rpc("any_peer", "reliable")
func cantar_truco():
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "canta TRUCO")

	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.cantar_truco(sender_id)

# ====== ENVIDO ======
# Cliente canta envido (1=Envido, 2=Real Envido, 3=Falta Envido)
@rpc("any_peer", "reliable")
func cantar_envido(tipo: int):
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "canta ENVIDO tipo", tipo)
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.cantar_envido(sender_id, tipo)

# Respuesta al envido (true=quiero, false=no quiero)
@rpc("any_peer", "reliable")
func respuesta_envido(acepta: bool):
	var network_manager = get_node("/root/NetworkManager")
	if not network_manager.es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "responde ENVIDO acepta=", acepta)
	var servidor_salas := get_tree().root.get_node_or_null("ServerManager")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.responder_envido(sender_id, acepta)
