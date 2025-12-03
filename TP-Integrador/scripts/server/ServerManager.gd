# ServerManager.gd - Gestiona la inicialización y conexiones del servidor multisala
extends Node

const Matchmaking = preload("res://scripts/server/Matchmaking.gd")
const RoomPool = preload("res://scripts/server/RoomPool.gd")

# Configuración
const PUERTO = 7777
const MAX_SALAS = 10  # Máximo de salas simultáneas

# Componentes principales
var matchmaking: Matchmaking
var room_pool: RoomPool

func _ready():
	print("\n========================================")
	print("SERVIDOR MULTISALA INICIANDO")
	print("========================================")
	print("Puerto: ", PUERTO)
	print("Máximo de salas: ", MAX_SALAS)
	print("========================================\n")
	
	# Inicializar componentes
	matchmaking = Matchmaking.new()
	room_pool = RoomPool.new(MAX_SALAS, self)
	
	# Conectar señales
	multiplayer.peer_connected.connect(_on_jugador_conectado)
	multiplayer.peer_disconnected.connect(_on_jugador_desconectado)
	
	# Iniciar servidor
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PUERTO, MAX_SALAS * 2)  # Máximo clientes = salas * 2
	
	if error != OK:
		print("ERROR: No se pudo crear el servidor: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Servidor escuchando en puerto ", PUERTO)
	print("Esperando jugadores...\n")

func _on_jugador_conectado(id: int):
	print("\n[SERVIDOR] Jugador ", id, " conectado")
	print("[SERVIDOR] Jugador ", id, " esperando en bienvenida...")

func _on_jugador_desconectado(id: int):
	print("\n[SERVIDOR] Jugador ", id, " desconectado")
	
	# Remover de cola si está ahí
	matchmaking.remover_jugador(id)
	
	# Obtener otros jugadores de su sala antes de remover
	var otros_jugadores = room_pool.obtener_otros_jugadores_en_sala(id)
	
	# Remover de la sala
	room_pool.remover_jugador(id)
	
	# Notificar a otros jugadores
	for peer_id in otros_jugadores:
		ClientRPCHandler.rpc_id(peer_id, "rival_desconectado")
		print("[SERVIDOR] Notificando a jugador ", peer_id, " sobre desconexión")

func _procesar_jugador_listo(peer_id: int):
	print("[ServerManager] _procesar_jugador_listo de peer ", peer_id)
	
	# Agregar a cola de espera
	matchmaking.agregar_jugador(peer_id)
	
	# Intentar emparejar
	intentar_matchmaking()

func intentar_matchmaking():
	if not matchmaking.puede_emparejar():
		return
	
	# Obtener pareja de jugadores
	var pareja = matchmaking.obtener_pareja()
	if pareja.size() != 2:
		return
	
	var j1 = pareja[0]
	var j2 = pareja[1]
	
	print("\n[MATCHMAKING] Emparejando jugadores ", j1, " y ", j2)
	
	# Buscar sala disponible
	var sala_disponible = room_pool.obtener_sala_libre()
	
	if sala_disponible == null:
		print("[MATCHMAKING] ERROR: No hay salas disponibles")
		matchmaking.reintegrar_pareja(j1, j2)
		return
	
	# Asignar jugadores a la sala
	if room_pool.asignar_jugadores_a_sala(j1, j2, sala_disponible):
		print("[MATCHMAKING] Sala ", sala_disponible.id, " asignada a jugadores ", j1, " y ", j2)
		sala_disponible.iniciar_partida()

func obtener_sala_de_jugador(peer_id: int):
	return room_pool.obtener_sala_de_jugador(peer_id)

# ============================================
# RPCs enviados a clientes
# ============================================

func rpc_sala(metodo: String, sala_id: int, j1: int, j2: int, param1 = null, param2 = null):
	if param2 != null:
		ClientRPCHandler.rpc_id(j1, metodo, param1, param2)
		ClientRPCHandler.rpc_id(j2, metodo, param1, param2)
	elif param1 != null:
		ClientRPCHandler.rpc_id(j1, metodo, param1)
		ClientRPCHandler.rpc_id(j2, metodo, param1)
	else:
		ClientRPCHandler.rpc_id(j1, metodo)
		ClientRPCHandler.rpc_id(j2, metodo)

func rpc_sala_id(metodo: String, sala_id: int, peer_id: int, param1 = null, param2 = null):
	if param2 != null:
		ClientRPCHandler.rpc_id(peer_id, metodo, param1, param2)
	elif param1 != null:
		ClientRPCHandler.rpc_id(peer_id, metodo, param1)
	else:
		ClientRPCHandler.rpc_id(peer_id, metodo)

func _exit_tree():
	print("\n[SERVIDOR] Cerrando...")
