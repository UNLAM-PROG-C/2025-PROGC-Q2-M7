# Room.gd - Estado básico de sala y jugadores
extends Node
class_name Room

const MAX_JUGADORES = 2

# Identificador único de la sala
var id: int = 0

# Jugadores en esta sala (máximo 2)
var jugadores := []  # [peer_id_1, peer_id_2]

# Estado de la sala
var activa := false
var partida_iniciada := false

# Mutex para proteger el estado de esta sala
var mutex := Mutex.new()

# Componentes de juego
var game_logic = null
var scoring = null
var notifier = null

func _init(sala_id: int, servidor_ref):
	id = sala_id
	
	# Lazy loading: los componentes se inicializan cuando se necesitan
	var TrucoGameLogic = load("res://scripts/game/TrucoGameLogic.gd")
	var TrucoScoring = load("res://scripts/game/TrucoScoring.gd")
	var TrucoNotifier = load("res://scripts/game/TrucoNotifier.gd")
	
	game_logic = TrucoGameLogic.new(self)
	scoring = TrucoScoring.new(self)
	notifier = TrucoNotifier.new(self, servidor_ref)

func esta_llena() -> bool:
	mutex.lock()
	var llena = jugadores.size() >= MAX_JUGADORES
	mutex.unlock()
	return llena

func esta_vacia() -> bool:
	mutex.lock()
	var vacia = jugadores.size() == 0
	mutex.unlock()
	return vacia

func agregar_jugador(peer_id: int) -> bool:
	mutex.lock()
	if jugadores.size() < MAX_JUGADORES and not jugadores.has(peer_id):
		jugadores.append(peer_id)
		print("[ROOM ", id, "] Jugador ", peer_id, " agregado (", jugadores.size(), "/", MAX_JUGADORES, ")")
		
		# Si la sala se llenó, marcar como activa
		if jugadores.size() == MAX_JUGADORES:
			activa = true
			print("[ROOM ", id, "] ¡Sala llena! Lista para iniciar partida...")
		
		mutex.unlock()
		return true
	mutex.unlock()
	return false

func quitar_jugador(peer_id: int):
	mutex.lock()
	jugadores.erase(peer_id)
	if jugadores.size() == 0:
		activa = false
		partida_iniciada = false
	print("[ROOM ", id, "] Jugador ", peer_id, " removido (", jugadores.size(), "/", MAX_JUGADORES, ")")
	mutex.unlock()

func iniciar_partida():
	mutex.lock()
	if jugadores.size() != MAX_JUGADORES or partida_iniciada:
		print("[ROOM ", id, "] No se puede iniciar partida - jugadores: ", jugadores.size(), " partida_iniciada: ", partida_iniciada)
		mutex.unlock()
		return
	
	partida_iniciada = true
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	mutex.unlock()
	
	print("[ROOM ", id, "] ========== INICIANDO PARTIDA ==========")
	print("[ROOM ", id, "] Jugador 1: ", j1)
	print("[ROOM ", id, "] Jugador 2: ", j2)
	
	# Cambiar escena en clientes
	notifier.iniciar_partida_cliente(j1, j2)
	
	# Pequeña espera para que cambien de escena
	await notifier.servidor_ref.get_tree().create_timer(1.0).timeout
	
	print("[ROOM ", id, "] Repartiendo cartas...")
	game_logic.repartir_cartas()

func procesar_carta_jugada(peer_id: int, carta: Vector2):
	game_logic.procesar_carta_jugada(peer_id, carta)

func jugador_listo_para_nueva_mano(peer_id: int):
	game_logic.jugador_listo_para_nueva_mano(peer_id)

func jugador_se_rindio(peer_id: int):
	scoring.jugador_se_rindio(peer_id)

func cantar_truco(peer_id: int):
	scoring.cantar_truco(peer_id)

func solicitar_apuesta_truco(peer_id: int, nivel: int):
	scoring.solicitar_apuesta_truco(peer_id, nivel)

func respuesta_apuesta_truco(peer_id: int, acepta: bool):
	scoring.respuesta_apuesta_truco(peer_id, acepta)

func cantar_envido(peer_id: int, tipo: int):
	scoring.cantar_envido(peer_id, tipo)

func responder_envido(peer_id: int, acepta: bool):
	scoring.responder_envido(peer_id, acepta)
