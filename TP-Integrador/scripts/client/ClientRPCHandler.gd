# ClientRPCHandler.gd - Maneja todos los RPCs que procesa el cliente
extends Node

# Constantes
const TIMEOUT_DESCONEXION = 2.0

# ========== RPCS RECIBIDOS DEL SERVIDOR ==========

# Llamada del servidor a todos los clientes para entrar a la mesa
@rpc("any_peer", "reliable")
func iniciar_partida_cliente():
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	print("[CLIENTE] ¡Recibí RPC iniciar_partida_cliente! Cambiando a MesaJuego...")
	get_tree().change_scene_to_file("res://scenes/cliente/MesaJuego.tscn")

# El servidor envía a cada cliente su mano y la del rival
@rpc("any_peer", "reliable")
func recibir_mano(mi_mano: Array, mano_rival: Array):
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
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
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	Global.turno_actual = peer_id_turno
	print("Turno actualizado. Turno de:", peer_id_turno, " | Mi ID:", multiplayer.get_unique_id())

# Servidor notifica a todos que se jugó una carta
@rpc("any_peer", "reliable")
func carta_jugada(peer_id: int, carta: Vector2):
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	print("Carta jugada por", peer_id, ":", carta)
	# El cliente de MesaJuego manejará esto
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_carta_jugada"):
		mesa.mostrar_carta_jugada(peer_id, carta)

# Servidor notifica el resultado de la mano
@rpc("any_peer", "reliable")
func mostrar_resultado_mano(ganaste: bool, puntos_propios: int, puntos_rival: int):
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	print("Resultado mano - Ganaste:", ganaste, " | Puntos:", puntos_propios, "-", puntos_rival)
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_resultado_mano"):
		mesa.mostrar_resultado_mano(ganaste, puntos_propios, puntos_rival)

# Servidor notifica a clientes que el valor del truco cambió (1 o 2 por ahora)
@rpc("any_peer", "reliable")
func estado_truco_actualizado(valor_truco: int):
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	print("[CLIENTE] Estado truco actualizado a", valor_truco)
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("actualizar_estado_truco"):
		mesa.actualizar_estado_truco(valor_truco)

# Servidor avisa que hay una apuesta de truco pendiente y quién la cantó
@rpc("any_peer", "reliable")
func apuesta_truco_pendiente(nivel: int, cantor_peer: int):
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	print("[CLIENTE] Apuesta de truco pendiente nivel", nivel, "cantor", cantor_peer)
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_apuesta_truco_pendiente"):
		mesa.mostrar_apuesta_truco_pendiente(nivel, cantor_peer)

# ===== ENVIDO =====
@rpc("any_peer", "reliable")
func envido_pendiente(tipo: int, cantor_peer: int):
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	print("[CLIENTE] Envido pendiente tipo", tipo, "cantor", cantor_peer)
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_envido_pendiente"):
		mesa.mostrar_envido_pendiente(tipo, cantor_peer)

@rpc("any_peer", "reliable")
func resultado_envido(data):
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	var ganador_peer = data.get("ganador_peer", 0)
	var puntos = data.get("puntos", 0)
	var envido_j1 = data.get("envido_j1", 0)
	var envido_j2 = data.get("envido_j2", 0)
	print("[CLIENTE] Resultado envido: ganador", ganador_peer, "puntos +", puntos, "(J1=", envido_j1, ", J2=", envido_j2, ")")
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("mostrar_resultado_envido"):
		mesa.mostrar_resultado_envido(ganador_peer, puntos, envido_j1, envido_j2)

@rpc("any_peer", "reliable")
func actualizar_puntos(puntos_propios: int, puntos_rival: int):
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa and mesa.has_method("actualizar_puntos"):
		mesa.actualizar_puntos(puntos_propios, puntos_rival)

# Servidor notifica que el rival se desconectó
@rpc("any_peer", "reliable")
func rival_desconectado():
	var network_manager = get_node("/root/NetworkManager")
	if network_manager.es_servidor:
		return
	print("El rival se desconectó")
	# Mostrar mensaje y volver al menú
	var mesa = get_tree().root.get_node_or_null("MesaJuego")
	if mesa:
		# Aquí podrías mostrar un diálogo
		push_warning("Rival desconectado. Volviendo al menú...")
		await get_tree().create_timer(TIMEOUT_DESCONEXION).timeout
	get_tree().change_scene_to_file("res://scenes/menu/MenuInicial.tscn")
