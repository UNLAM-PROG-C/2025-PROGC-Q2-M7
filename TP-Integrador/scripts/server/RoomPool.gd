# RoomPool.gd - Gestiona el pool de salas de juego
class_name RoomPool

const Room = preload("res://scripts/server/Room.gd")

var salas := []  # Array de objetos Room
var mutex_salas := Mutex.new()  # Protege el array de salas

# Mapeo de jugadores a salas
var jugador_a_sala := {}  # peer_id -> sala_id
var mutex_jugadores := Mutex.new()  # Protege el mapeo

# Referencia al servidor para RPCs
var servidor_ref = null

func _init(max_salas: int, servidor):
	servidor_ref = servidor
	mutex_salas.lock()
	for i in range(max_salas):
		var sala = Room.new(i + 1, servidor)
		salas.append(sala)
	mutex_salas.unlock()
	print("[RoomPool] Inicializado con ", max_salas, " salas")

func obtener_sala_libre() -> Room:
	# Debe llamarse sin lock (lo hace internamente)
	mutex_salas.lock()
	var sala_disponible = null
	for sala in salas:
		if sala.esta_vacia():
			sala_disponible = sala
			break
	mutex_salas.unlock()
	return sala_disponible

func obtener_sala_por_id(sala_id: int) -> Room:
	# Debe llamarse con mutex_salas locked externamente
	for sala in salas:
		if sala.id == sala_id:
			return sala
	return null

func obtener_sala_de_jugador(peer_id: int) -> Room:
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

func asignar_jugadores_a_sala(j1: int, j2: int, sala: Room) -> bool:
	if sala == null:
		return false
	
	# Asignar jugadores a la sala
	sala.agregar_jugador(j1)
	sala.agregar_jugador(j2)
	
	# Registrar en mapeo
	mutex_jugadores.lock()
	jugador_a_sala[j1] = sala.id
	jugador_a_sala[j2] = sala.id
	mutex_jugadores.unlock()
	
	return true

func remover_jugador(peer_id: int):
	mutex_jugadores.lock()
	if not jugador_a_sala.has(peer_id):
		mutex_jugadores.unlock()
		return
	
	var sala_id = jugador_a_sala[peer_id]
	jugador_a_sala.erase(peer_id)
	mutex_jugadores.unlock()
	
	# Remover de la sala
	mutex_salas.lock()
	var sala = obtener_sala_por_id(sala_id)
	if sala:
		sala.quitar_jugador(peer_id)
		print("[RoomPool] Jugador ", peer_id, " removido de sala ", sala_id)
	mutex_salas.unlock()

func obtener_otros_jugadores_en_sala(peer_id: int) -> Array:
	var sala = obtener_sala_de_jugador(peer_id)
	if sala:
		sala.mutex.lock()
		var otros = sala.jugadores.duplicate()
		sala.mutex.unlock()
		otros.erase(peer_id)
		return otros
	return []
