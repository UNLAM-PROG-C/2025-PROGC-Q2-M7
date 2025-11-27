extends Node

var es_servidor := false
var conexion: ENetMultiplayerPeer = null

# Solo usado por el servidor para llevar el control de jugadores "listos"
var _listos: Dictionary = {}   # peer_id -> true

func _ready():
	# Ya no iniciamos automáticamente
	# El menú inicial llamará a iniciar_servidor_salas() o iniciar_cliente_con_ip()
	pass

func iniciar_servidor_salas():
	es_servidor = true
	# El servidor de salas no usa ENetMultiplayerPeer aquí,
	# lo crea internamente en ServidorSalas.gd
	print("SERVIDOR MULTISALA INICIANDO...")
	call_deferred("_cambiar_a_servidor_salas")

func _cambiar_a_servidor_salas():
	get_tree().change_scene_to_file("res://scenes/servidor/ServidorSalas.tscn")

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

func _peer_se_fue(id:int):
	if es_servidor:
		_listos.erase(id)

# ========== RPCS ==========

# Los clientes llaman esto en el servidor para avisar que están listos
@rpc("any_peer", "reliable")
func jugador_listo():
	if not es_servidor:
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	
	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServidorSalas")
	if servidor_salas:
		# Llamar directamente al método del servidor multisala
		print("[Red.gd] Redirigiendo jugador_listo a ServidorSalas para peer ", peer_id)
		# Simular que llegó el RPC al servidor multisala
		servidor_salas.call_deferred("_procesar_jugador_listo", peer_id)
		return
	
	# Servidor simple
	_listos[peer_id] = true
	print("Jugador LISTO:", peer_id, " | Total listos:", _listos.size())

	# Cuando hay 2 listos, pedimos al nodo Servidor repartir
	if _listos.size() >= 2:
		var servidor := get_tree().root.get_node_or_null("Servidor")
		if servidor and servidor.has_method("_repartir_cartas"):
			print("Todos listos. Repartiendo...")
			servidor._repartir_cartas()
		else:
			push_warning("No se encontró el servidor simple")

# Llamada del servidor a todos los clientes para entrar a la mesa
@rpc("any_peer", "reliable")
func iniciar_partida_cliente():
	if es_servidor:
		return
	print("[CLIENTE] ¡Recibí RPC iniciar_partida_cliente! Cambiando a MesaJuego...")
	get_tree().change_scene_to_file("res://scenes/cliente/MesaJuego.tscn")

# El servidor envía a cada cliente su mano y la del rival
@rpc("any_peer", "reliable")
func recibir_mano(mi_mano: Array, mano_rival: Array):
	if es_servidor:
		return
	Global.mi_mano = mi_mano
	Global.mano_rival = mano_rival
	print("Recibí mi mano:", mi_mano)
	
	# Si estamos en la mesa de juego, actualizar las cartas mostradas
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_manos"):
		mesa.mostrar_manos()

# El servidor notifica a todos quién tiene el turno
@rpc("any_peer", "reliable")
func actualizar_turno(peer_id_turno: int):
	if es_servidor:
		return
	Global.turno_actual = peer_id_turno
	print("Turno actualizado. Turno de:", peer_id_turno, " | Mi ID:", multiplayer.get_unique_id())

# Cliente avisa al servidor que quiere jugar una carta
@rpc("any_peer", "reliable")
func solicitar_jugar_carta(carta: Vector2):
	if not es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "solicita jugar carta:", carta)
	
	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServidorSalas")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.procesar_carta_jugada(sender_id, carta)
		return
	
	# Servidor simple
	var servidor := get_tree().root.get_node_or_null("Servidor")
	if servidor and servidor.turno_actual == sender_id:
		servidor.procesar_carta_jugada(sender_id, carta)
	else:
		print("ERROR: No es el turno de", sender_id)

# Servidor notifica a todos que se jugó una carta
@rpc("any_peer", "reliable")
func carta_jugada(peer_id: int, carta: Vector2):
	if es_servidor:
		return
	print("Carta jugada por", peer_id, ":", carta)
	# El cliente de MesaJuego manejará esto
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_carta_jugada"):
		mesa.mostrar_carta_jugada(peer_id, carta)

# Cliente solicita subir apuesta de truco (2=Truco, 3=Retruco, 4=Vale cuatro)
@rpc("any_peer", "reliable")
func solicitar_apuesta_truco(nivel: int):
	if not es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "solicita apuesta truco nivel", nivel)
	var servidor_salas := get_tree().root.get_node_or_null("ServidorSalas")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.solicitar_apuesta_truco(sender_id, nivel)
		return
	var servidor := get_tree().root.get_node_or_null("Servidor")
	if servidor and servidor.has_method("solicitar_apuesta_truco"):
		servidor.solicitar_apuesta_truco(sender_id, nivel)

# Respuesta del rival a la apuesta de truco (true=quiero, false=no quiero)
@rpc("any_peer", "reliable")
func respuesta_apuesta_truco(acepta: bool):
	if not es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "responde apuesta truco acepta=", acepta)
	var servidor_salas := get_tree().root.get_node_or_null("ServidorSalas")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.respuesta_apuesta_truco(sender_id, acepta)
		return
	var servidor := get_tree().root.get_node_or_null("Servidor")
	if servidor and servidor.has_method("respuesta_apuesta_truco"):
		servidor.respuesta_apuesta_truco(sender_id, acepta)

# Servidor notifica el resultado de la mano
@rpc("any_peer", "reliable")
func mostrar_resultado_mano(ganaste: bool, puntos_propios: int, puntos_rival: int):
	if es_servidor:
		return
	print("Resultado mano - Ganaste:", ganaste, " | Puntos:", puntos_propios, "-", puntos_rival)
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_resultado_mano"):
		mesa.mostrar_resultado_mano(ganaste, puntos_propios, puntos_rival)

# Servidor notifica a clientes que el valor del truco cambió (1 o 2 por ahora)
@rpc("any_peer", "reliable")
func estado_truco_actualizado(valor_truco: int):
	if es_servidor:
		return
	print("[CLIENTE] Estado truco actualizado a", valor_truco)
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("actualizar_estado_truco"):
		mesa.actualizar_estado_truco(valor_truco)

# Servidor avisa que hay una apuesta de truco pendiente y quién la cantó
@rpc("any_peer", "reliable")
func apuesta_truco_pendiente(nivel: int, cantor_peer: int):
	if es_servidor:
		return
	print("[CLIENTE] Apuesta de truco pendiente nivel", nivel, "cantor", cantor_peer)
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_apuesta_truco_pendiente"):
		mesa.mostrar_apuesta_truco_pendiente(nivel, cantor_peer)

# Cliente notifica al servidor que está listo para una nueva mano
@rpc("any_peer", "reliable")
func jugador_listo_nueva_mano():
	if not es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "listo para nueva mano")
	
	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServidorSalas")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.jugador_listo_para_nueva_mano(sender_id)
		return
	
	# Servidor simple
	var servidor := get_tree().root.get_node_or_null("Servidor")
	if servidor and servidor.has_method("jugador_listo_para_nueva_mano"):
		servidor.jugador_listo_para_nueva_mano(sender_id)

# Cliente notifica al servidor que se rinde (se fue al mazo)
@rpc("any_peer", "reliable")
func jugador_se_fue_al_mazo():
	if not es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "se fue al mazo (rendición)")
	
	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServidorSalas")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.jugador_se_rindio(sender_id)
		return
	
	# Servidor simple
	var servidor := get_tree().root.get_node_or_null("Servidor")
	if servidor and servidor.has_method("jugador_se_rindio"):
		servidor.jugador_se_rindio(sender_id)

# Cliente canta truco (solicita subir el valor de la mano)
@rpc("any_peer", "reliable")
func cantar_truco():
	if not es_servidor:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Jugador", sender_id, "canta TRUCO")

	# Verificar si es servidor multisala
	var servidor_salas := get_tree().root.get_node_or_null("ServidorSalas")
	if servidor_salas:
		var sala = servidor_salas.obtener_sala_de_jugador(sender_id)
		if sala:
			sala.cantar_truco(sender_id)
		return

	# Servidor simple
	var servidor := get_tree().root.get_node_or_null("Servidor")
	if servidor and servidor.has_method("cantar_truco"):
		servidor.cantar_truco(sender_id)

# Servidor notifica que el rival se desconectó
@rpc("any_peer", "reliable")
func rival_desconectado():
	if es_servidor:
		return
	print("El rival se desconectó")
	# Mostrar mensaje y volver al menú
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa:
		# Aquí podrías mostrar un diálogo
		push_warning("Rival desconectado. Volviendo al menú...")
		await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/menu/MenuInicial.tscn")
