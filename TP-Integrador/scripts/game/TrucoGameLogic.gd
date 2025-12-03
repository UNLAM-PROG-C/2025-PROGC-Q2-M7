# TrucoGameLogic.gd - Lógica de manos, turnos y comparación de cartas
class_name TrucoGameLogic

# Enum para identificar ganadores
enum GanadorMano { NINGUNO = 0, JUGADOR_1 = 1, JUGADOR_2 = 2, EMPATE = 3 }

# Constantes
const CARTAS_POR_MANO = 3

const ValorCartas = preload("res://scripts/game/ValorCartas.gd")
const Mazo = preload("res://scripts/game/Mazo.gd")

# Referencia a la sala
var room = null

# Estado del juego
var turno_actual := 0
var cartas_en_mesa := {}  # peer_id -> Vector2 (carta jugada)
var manos_ganadas_j1 := 0
var manos_ganadas_j2 := 0
var carta_actual := 1
var mano_quien_empieza := 0
var jugadores_listos_nueva_mano := []
var mano_j1_servidor: Array = []
var mano_j2_servidor: Array = []

func _init(room_ref):
	room = room_ref

func repartir_cartas():
	room.mutex.lock()
	if room.jugadores.size() != room.MAX_JUGADORES:
		room.mutex.unlock()
		return
	
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	room.mutex.unlock()
	
	var mazo = Mazo.new()
	var mano1 = mazo.repartir_mano()
	var mano2 = mazo.repartir_mano()
	# Guardar manos en servidor para cálculos de envido
	mano_j1_servidor = mano1.duplicate(true)
	mano_j2_servidor = mano2.duplicate(true)
	
	print("[GameLogic ", room.id, "] Repartiendo cartas a jugadores ", j1, " y ", j2)
	
	# Enviar manos a través del notifier
	room.notifier.recibir_mano(j1, mano1, mano2)
	room.notifier.recibir_mano(j2, mano2, mano1)

	# Reiniciar valor de truco al iniciar cada mano
	room.scoring.reiniciar_valor_truco()
	
	# Iniciar turnos
	room.mutex.lock()
	turno_actual = j1
	mano_quien_empieza = j1
	reiniciar_mano_interno()
	room.mutex.unlock()
	
	room.notifier.actualizar_turno(j1, j2, turno_actual)

func reiniciar_mano_interno():
	# NO usar mutex aquí, ya está locked por el caller
	manos_ganadas_j1 = 0
	manos_ganadas_j2 = 0
	carta_actual = 1
	print("[GameLogic ", room.id, "] ========== NUEVA MANO ==========")

func procesar_carta_jugada(peer_id: int, carta: Vector2):
	room.mutex.lock()
	
	if not room.jugadores.has(peer_id):
		room.mutex.unlock()
		return
	
	if turno_actual != peer_id:
		print("[GameLogic ", room.id, "] ERROR: No es el turno de ", peer_id)
		room.mutex.unlock()
		return
	
	var info = ValorCartas.obtener_valor_truco(carta.y, carta.x)
	print("[GameLogic ", room.id, "] Jugador ", peer_id, " jugó: ", info["nombre"], " (valor: ", info["valor"], ")")
	
	# Guardar carta en mesa
	cartas_en_mesa[peer_id] = carta
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	room.mutex.unlock()
	
	# Notificar a clientes
	room.notifier.carta_jugada(j1, j2, peer_id, carta)
	
	room.mutex.lock()
	var cartas_count = cartas_en_mesa.size()
	room.mutex.unlock()
	
	# Si ambos jugaron, comparar
	if cartas_count == 2:
		comparar_cartas_jugadas()
	else:
		cambiar_turno()

func cambiar_turno():
	room.mutex.lock()
	var idx = room.jugadores.find(turno_actual)
	idx = (idx + 1) % room.jugadores.size()
	turno_actual = room.jugadores[idx]
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	var turno = turno_actual
	room.mutex.unlock()
	
	print("[GameLogic ", room.id, "] Cambio de turno a: ", turno)
	room.notifier.actualizar_turno(j1, j2, turno)

func comparar_cartas_jugadas():
	room.mutex.lock()
	var jugadores_ids = cartas_en_mesa.keys()
	var peer_id_1 = jugadores_ids[0]
	var peer_id_2 = jugadores_ids[1]
	var carta1 = cartas_en_mesa[peer_id_1]
	var carta2 = cartas_en_mesa[peer_id_2]
	
	var info1 = ValorCartas.obtener_valor_truco(carta1.y, carta1.x)
	var info2 = ValorCartas.obtener_valor_truco(carta2.y, carta2.x)
	var resultado = ValorCartas.comparar_cartas(carta1, carta2)
	
	print("[GameLogic ", room.id, "] --- Carta ", carta_actual, " ---")
	print("[GameLogic ", room.id, "] Jugador ", peer_id_1, ": ", info1["nombre"], " (", info1["valor"], ")")
	print("[GameLogic ", room.id, "] Jugador ", peer_id_2, ": ", info2["nombre"], " (", info2["valor"], ")")
	
	var j1 = room.jugadores[0]
	
	if resultado == 1:
		print("[GameLogic ", room.id, "] ¡", info1["nombre"], " GANA a ", info2["nombre"], "!")
		if peer_id_1 == j1:
			manos_ganadas_j1 += 1
			print("[GameLogic ", room.id, "] Gana J1 (peer ", peer_id_1, ")")
		else:
			manos_ganadas_j2 += 1
			print("[GameLogic ", room.id, "] Gana J2 (peer ", peer_id_1, ")")
		turno_actual = peer_id_1
		print("[GameLogic ", room.id, "] Manos ganadas: J1=", manos_ganadas_j1, " J2=", manos_ganadas_j2)
	elif resultado == -1:
		print("[GameLogic ", room.id, "] ¡", info2["nombre"], " GANA a ", info1["nombre"], "!")
		if peer_id_2 == j1:
			manos_ganadas_j1 += 1
			print("[GameLogic ", room.id, "] Gana J1 (peer ", peer_id_2, ")")
		else:
			manos_ganadas_j2 += 1
			print("[GameLogic ", room.id, "] Gana J2 (peer ", peer_id_2, ")")
		turno_actual = peer_id_2
		print("[GameLogic ", room.id, "] Manos ganadas: J1=", manos_ganadas_j1, " J2=", manos_ganadas_j2)
	else:
		print("[GameLogic ", room.id, "] ¡PARDA! (Empate)")
	
	cartas_en_mesa.clear()
	carta_actual += 1
	
	var j2 = room.jugadores[1]
	var turno = turno_actual
	room.mutex.unlock()
	
	# Verificar ganador
	verificar_ganador_mano()
	
	# Notificar turno
	room.notifier.actualizar_turno(j1, j2, turno)

func verificar_ganador_mano():
	room.mutex.lock()
	var ganador_mano_actual = 0
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	
	if manos_ganadas_j1 >= room.MAX_JUGADORES:
		print("[GameLogic ", room.id, "] ========================================")
		print("[GameLogic ", room.id, "] ¡JUGADOR 1 GANA LA MANO!")
		print("[GameLogic ", room.id, "] ========================================")
		room.scoring.sumar_puntos_j1(room.scoring.valor_truco_actual)
		ganador_mano_actual = GanadorMano.JUGADOR_1
		print("[GameLogic ", room.id, "] >>> PUNTOS: J1=", room.scoring.puntos_j1, " | J2=", room.scoring.puntos_j2, " <<<")
		mano_quien_empieza = j2
		turno_actual = mano_quien_empieza
	elif manos_ganadas_j2 >= room.MAX_JUGADORES:
		print("[GameLogic ", room.id, "] ========================================")
		print("[GameLogic ", room.id, "] ¡JUGADOR 2 GANA LA MANO!")
		print("[GameLogic ", room.id, "] ========================================")
		room.scoring.sumar_puntos_j2(room.scoring.valor_truco_actual)
		ganador_mano_actual = GanadorMano.JUGADOR_2
		print("[GameLogic ", room.id, "] >>> PUNTOS: J1=", room.scoring.puntos_j1, " | J2=", room.scoring.puntos_j2, " <<<")
		mano_quien_empieza = j1
		turno_actual = mano_quien_empieza
	elif carta_actual > CARTAS_POR_MANO:
		if manos_ganadas_j1 == manos_ganadas_j2:
			print("[GameLogic ", room.id, "] ========================================")
			print("[GameLogic ", room.id, "] ¡MANO EMPATADA! Gana mano: ", mano_quien_empieza)
			print("[GameLogic ", room.id, "] ========================================")
			if mano_quien_empieza == j1:
				room.scoring.sumar_puntos_j1(room.scoring.valor_truco_actual)
				ganador_mano_actual = GanadorMano.JUGADOR_1
			else:
				room.scoring.sumar_puntos_j2(room.scoring.valor_truco_actual)
				ganador_mano_actual = GanadorMano.JUGADOR_2
			print("[GameLogic ", room.id, "] >>> PUNTOS: J1=", room.scoring.puntos_j1, " | J2=", room.scoring.puntos_j2, " <<<")
		
		var idx = room.jugadores.find(mano_quien_empieza)
		idx = (idx + 1) % room.jugadores.size()
		mano_quien_empieza = room.jugadores[idx]
		turno_actual = mano_quien_empieza
	
	var pts_j1 = room.scoring.puntos_j1
	var pts_j2 = room.scoring.puntos_j2
	room.mutex.unlock()
	
	if ganador_mano_actual > GanadorMano.NINGUNO:
		room.notifier.notificar_resultado_mano(ganador_mano_actual, pts_j1, pts_j2, j1, j2)

func jugador_listo_para_nueva_mano(peer_id: int):
	room.mutex.lock()
	if not jugadores_listos_nueva_mano.has(peer_id):
		jugadores_listos_nueva_mano.append(peer_id)
		print("[GameLogic ", room.id, "] Jugador ", peer_id, " listo para nueva mano (", jugadores_listos_nueva_mano.size(), "/", room.MAX_JUGADORES, ")")
	
	var listos = jugadores_listos_nueva_mano.size()
	room.mutex.unlock()
	
	if listos >= room.MAX_JUGADORES:
		print("[GameLogic ", room.id, "] Ambos jugadores listos. Repartiendo nuevas cartas...")
		room.mutex.lock()
		jugadores_listos_nueva_mano.clear()
		room.mutex.unlock()
		repartir_cartas()
