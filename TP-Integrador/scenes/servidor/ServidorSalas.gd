# ServidorSalas.gd - Servidor que gestiona múltiples salas de juego concurrentes
extends Node

const Mazo = preload("res://scripts/juego/Mazo.gd")
const Sala = preload("res://scripts/juego/Sala.gd")

# Configuración
const PUERTO = 7777
const MAX_SALAS = 10  # Máximo de salas simultáneas

# Salas de juego
var salas := []  # Array de objetos Sala
var mutex_salas := Mutex.new()  # Protege el array de salas

# Mapeo de jugadores a salas
var jugador_a_sala := {}  # peer_id -> sala_id
var mutex_jugadores := Mutex.new()  # Protege el mapeo

# Cola de espera para matchmaking
var cola_espera := []  # [peer_id, peer_id, ...]
var mutex_cola := Mutex.new()  # Protege la cola

# Thread pool para procesar salas
var threads := []
var max_threads := 4  # Usar hasta 4 threads para procesar salas
var thread_activo := true

# Contador de sala
var siguiente_id_sala := 1
var mutex_id := Mutex.new()

func _ready():
	print("\n========================================")
	print("SERVIDOR MULTISALA INICIANDO")
	print("========================================")
	print("Puerto: ", PUERTO)
	print("Máximo de salas: ", MAX_SALAS)
	print("Threads: ", max_threads)
	print("========================================\n")
	
	# Inicializar salas
	mutex_salas.lock()
	for i in range(MAX_SALAS):
		var sala = Sala.new(i + 1, self)
		salas.append(sala)
	mutex_salas.unlock()
	
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
	
	# NO agregar a cola automáticamente
	# Esperar a que el jugador presione "Listo" en Bienvenida
	print("[SERVIDOR] Jugador ", id, " esperando en bienvenida...")

func _on_jugador_desconectado(id: int):
	print("\n[SERVIDOR] Jugador ", id, " desconectado")
	
	# Remover de cola si está ahí
	mutex_cola.lock()
	cola_espera.erase(id)
	mutex_cola.unlock()
	
	# Buscar su sala y removerlo
	mutex_jugadores.lock()
	if jugador_a_sala.has(id):
		var sala_id = jugador_a_sala[id]
		jugador_a_sala.erase(id)
		mutex_jugadores.unlock()
		
		# Remover de la sala
		mutex_salas.lock()
		var sala = obtener_sala_por_id(sala_id)
		if sala:
			sala.quitar_jugador(id)
			print("[SERVIDOR] Jugador ", id, " removido de sala ", sala_id)
			
			# Notificar al otro jugador si existe
			sala.mutex.lock()
			var otros_jugadores = sala.jugadores.duplicate()
			sala.mutex.unlock()
			
			for peer_id in otros_jugadores:
				if peer_id != id:
					RedGlobal.rpc_id(peer_id, "rival_desconectado")
					print("[SERVIDOR] Notificando a jugador ", peer_id, " sobre desconexión")
		mutex_salas.unlock()
	else:
		mutex_jugadores.unlock()

func intentar_matchmaking():
	mutex_cola.lock()
	
	# Verificar si hay al menos 2 jugadores en cola
	if cola_espera.size() < 2:
		mutex_cola.unlock()
		return
	
	# Tomar los primeros 2 jugadores
	var j1 = cola_espera.pop_front()
	var j2 = cola_espera.pop_front()
	mutex_cola.unlock()
	
	print("\n[MATCHMAKING] Emparejando jugadores ", j1, " y ", j2)
	
	# Buscar sala disponible
	mutex_salas.lock()
	var sala_disponible = null
	for sala in salas:
		if sala.esta_vacia():
			sala_disponible = sala
			break
	mutex_salas.unlock()
	
	if sala_disponible == null:
		print("[MATCHMAKING] ERROR: No hay salas disponibles")
		# Reintegrar a la cola
		mutex_cola.lock()
		cola_espera.push_front(j2)
		cola_espera.push_front(j1)
		mutex_cola.unlock()
		return
	
	# Asignar jugadores a la sala
	sala_disponible.agregar_jugador(j1)
	sala_disponible.agregar_jugador(j2)
	
	# Registrar en mapeo
	mutex_jugadores.lock()
	jugador_a_sala[j1] = sala_disponible.id
	jugador_a_sala[j2] = sala_disponible.id
	mutex_jugadores.unlock()
	
	print("[MATCHMAKING] Sala ", sala_disponible.id, " asignada a jugadores ", j1, " y ", j2)
	
	# Iniciar partida en la sala
	sala_disponible.iniciar_partida()

func obtener_sala_por_id(sala_id: int) -> Sala:
	# Debe llamarse con mutex_salas locked
	for sala in salas:
		if sala.id == sala_id:
			return sala
	return null

func obtener_sala_de_jugador(peer_id: int) -> Sala:
	mutex_jugadores.lock()
	if not jugador_a_sala.has(peer_id):
		mutex_jugadores.unlock()
		return null
	var sala_id = jugador_a_sala[peer_id]
	mutex_jugadores.unlock()
	
	mutex_salas.lock()
	var sala = obtener_sala_por_id(sala_id)
	mutex_salas.unlock()
	return sala

# ============================================
# RPCs recibidos de clientes
# ============================================

func _procesar_jugador_listo(peer_id: int):
	# Método llamado desde Red.gd cuando recibe el RPC jugador_listo
	print("[ServidorSalas] _procesar_jugador_listo de peer ", peer_id)
	
	# Agregar a cola de espera
	mutex_cola.lock()
	if not cola_espera.has(peer_id):
		cola_espera.append(peer_id)
		var en_cola = cola_espera.size()
		mutex_cola.unlock()
		print("[MATCHMAKING] Jugador ", peer_id, " agregado a cola (", en_cola, " en espera)")
	else:
		mutex_cola.unlock()
	
	# Intentar emparejar
	intentar_matchmaking()

# Nota: Los RPCs ahora se manejan en Red.gd (autoload global)
# y desde ahí se llama a los métodos de ServidorSalas

# ============================================
# RPCs enviados a clientes
# ============================================

# Envía RPC a todos los jugadores de una sala
func rpc_sala(metodo: String, sala_id: int, j1: int, j2: int, param1 = null, param2 = null):
	# Los RPCs están en RedGlobal, no en ServidorSalas
	if param2 != null:
		RedGlobal.rpc_id(j1, metodo, param1, param2)
		RedGlobal.rpc_id(j2, metodo, param1, param2)
	elif param1 != null:
		RedGlobal.rpc_id(j1, metodo, param1)
		RedGlobal.rpc_id(j2, metodo, param1)
	else:
		RedGlobal.rpc_id(j1, metodo)
		RedGlobal.rpc_id(j2, metodo)

# Envía RPC a un jugador específico de una sala
func rpc_sala_id(metodo: String, sala_id: int, peer_id: int, param1 = null, param2 = null):
	# Los RPCs están en RedGlobal, no en ServidorSalas
	if param2 != null:
		RedGlobal.rpc_id(peer_id, metodo, param1, param2)
	elif param1 != null:
		RedGlobal.rpc_id(peer_id, metodo, param1)
	else:
		RedGlobal.rpc_id(peer_id, metodo)

# Nota: Los RPCs (iniciar_partida_cliente, recibir_mano, actualizar_turno, etc.)
# están definidos en Red.gd (autoload) para que funcionen en todos los peers

func _exit_tree():
	# Detener threads si los hubiera
	thread_activo = false
	for thread in threads:
		if thread.is_alive():
			thread.wait_to_finish()
	
	print("\n[SERVIDOR] Cerrando...")
