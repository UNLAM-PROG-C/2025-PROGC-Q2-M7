# TrucoScoring.gd - Sistema de puntos, truco, retruco y vale cuatro
class_name TrucoScoring

# Enum para identificar ganadores
enum GanadorMano { NINGUNO = 0, JUGADOR_1 = 1, JUGADOR_2 = 2, EMPATE = 3 }

# Referencia a la sala
var room = null

# Puntuación
var puntos_j1 := 0
var puntos_j2 := 0

# Sistema de apuestas
var valor_truco_actual := 1  # 1 por defecto, 2=Truco, 3=Retruco, 4=Vale Cuatro
var apuesta_pendiente_nivel := 0  # 0 sin apuesta; 2 Truco; 3 Retruco; 4 Vale cuatro
var apuesta_cantor_id := 0

# Envido
const ENVIDO := 1
const REAL_ENVIDO := 2
const FALTA_ENVIDO := 3
const PUNTOS_PARTIDA := 30
var envido_pendiente_tipo := 0
var envido_cantor_id := 0
var envido_resuelto := false
var envidos_acumulados := []  # Array de tipos de envido cantados en cadena

func _init(room_ref):
	room = room_ref

func sumar_puntos_j1(puntos: int):
	puntos_j1 += puntos

func sumar_puntos_j2(puntos: int):
	puntos_j2 += puntos

func reiniciar_valor_truco():
	valor_truco_actual = 1
	apuesta_pendiente_nivel = 0
	apuesta_cantor_id = 0
	# Reiniciar también estado de envido al comenzar cada mano
	envido_pendiente_tipo = 0
	envido_cantor_id = 0
	envido_resuelto = false
	envidos_acumulados.clear()
	envidos_acumulados.clear()

func jugador_se_rindio(peer_id: int):
	room.mutex.lock()
	if not room.jugadores.has(peer_id):
		room.mutex.unlock()
		return
	
	print("[Scoring ", room.id, "] ¡Jugador ", peer_id, " se rindió!")
	
	# Obtener el rival y determinar quién es J1 y J2
	var rival_id = 0
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	
	for jug in room.jugadores:
		if jug != peer_id:
			rival_id = jug
			break
	
	# Sumar un punto al rival
	if rival_id == j1:
		puntos_j1 += 1
		print("[Scoring ", room.id, "] Jugador 1 (", j1, ") gana 1 punto por rendición del rival")
	else:
		puntos_j2 += 1
		print("[Scoring ", room.id, "] Jugador 2 (", j2, ") gana 1 punto por rendición del rival")
	
	var pts_j1 = puntos_j1
	var pts_j2 = puntos_j2
	
	room.mutex.unlock()
	
	# Notificar resultado de la mano
	var ganador_mano = GanadorMano.JUGADOR_1 if rival_id == j1 else GanadorMano.JUGADOR_2
	room.notifier.notificar_resultado_mano(ganador_mano, pts_j1, pts_j2, j1, j2)
	
	print("[Scoring ", room.id, "] >>> PUNTOS: J1=", pts_j1, " | J2=", pts_j2, " <<<")
	
	# Limpiar estado de la mano pero mantener puntos
	room.mutex.lock()
	room.game_logic.manos_ganadas_j1 = 0
	room.game_logic.manos_ganadas_j2 = 0
	room.game_logic.jugadores_listos_nueva_mano.clear()
	room.game_logic.cartas_en_mesa.clear()
	room.game_logic.carta_actual = 1
	valor_truco_actual = 1
	apuesta_pendiente_nivel = 0
	apuesta_cantor_id = 0
	room.mutex.unlock()
	
	print("[Scoring ", room.id, "] Mano terminada por rendición, esperando jugadores para nueva mano")

func cantar_truco(peer_id: int):
	room.mutex.lock()
	if not room.jugadores.has(peer_id):
		room.mutex.unlock()
		return

	# En esta versión, si ya estaba en 2, no cambia.
	if valor_truco_actual < 2:
		valor_truco_actual = 2
		print("[Scoring ", room.id, "] Jugador ", peer_id, " cantó TRUCO. Valor actual: ", valor_truco_actual)
	else:
		print("[Scoring ", room.id, "] TRUCO ya activo. Valor actual: ", valor_truco_actual)

	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	var valor = valor_truco_actual
	room.mutex.unlock()

	# Notificar a ambos clientes el estado del truco
	room.notifier.estado_truco_actualizado(j1, j2, valor)

func cantar_envido(peer_id: int, tipo: int):
	room.mutex.lock()
	if not room.jugadores.has(peer_id):
		room.mutex.unlock()
		return
	# Regla: luego de que ambos jugaron la primera carta, no se puede cantar envido
	var carta_actual = room.game_logic.carta_actual
	var jugadas_en_ronda = room.game_logic.cartas_en_mesa.size()
	if carta_actual > 1 or (carta_actual == 1 and jugadas_en_ronda >= 2):
		print("[Scoring ", room.id, "] Envido bloqueado: ya se jugaron las dos primeras cartas")
		room.mutex.unlock()
		return
	if envido_resuelto:
		print("[Scoring ", room.id, "] Envido ya fue resuelto esta mano")
		room.mutex.unlock()
		return
	# Validar tipo
	if not [ENVIDO, REAL_ENVIDO, FALTA_ENVIDO].has(tipo):
		room.mutex.unlock()
		return
	
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	
	# Si ya hay envido pendiente, permitir encadenamiento (debe ser del rival del último cantor)
	if envido_pendiente_tipo != 0:
		var rival_esperado = j1 if envido_cantor_id == j2 else j2
		if peer_id != rival_esperado:
			print("[Scoring ", room.id, "] No puedes encadenar tu propio envido")
			room.mutex.unlock()
			return
		# Agregar al encadenamiento
		envidos_acumulados.append(tipo)
		envido_pendiente_tipo = tipo  # Actualizar el tipo pendiente al último
		envido_cantor_id = peer_id  # Ahora el cantor es quien encadenó
		var t = envido_pendiente_tipo
		var cantor = envido_cantor_id
		room.mutex.unlock()
		room.notifier.envido_pendiente(j1, j2, t, cantor)
		return
	
	# Primer envido: iniciar la cadena
	envido_pendiente_tipo = tipo
	envido_cantor_id = peer_id
	envidos_acumulados = [tipo]
	var t = envido_pendiente_tipo
	var cantor = envido_cantor_id
	room.mutex.unlock()
	room.notifier.envido_pendiente(j1, j2, t, cantor)

func _puntos_por_envido_tipo(tipo: int, aceptado: bool, faltan: int) -> int:
	if aceptado:
		match tipo:
			ENVIDO:
				return 2
			REAL_ENVIDO:
				return 3
			FALTA_ENVIDO:
				return faltan
	else:
		# No quiero
		match tipo:
			ENVIDO:
				return 1
			REAL_ENVIDO:
				return 2
			FALTA_ENVIDO:
				return 3
	return 0

func _calcular_puntos_envido_acumulado(aceptado: bool, faltan: int) -> int:
	var total := 0
	for tipo_env in envidos_acumulados:
		total += _puntos_por_envido_tipo(tipo_env, aceptado, faltan)
	return total

func responder_envido(peer_id: int, acepta: bool):
	room.mutex.lock()
	if envido_pendiente_tipo == 0:
		room.mutex.unlock()
		return
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	var cantor = envido_cantor_id
	var tipo = envido_pendiente_tipo
	var rival = j1 if cantor == j2 else j2
	if peer_id != rival:
		room.mutex.unlock()
		return
	# Limpiar pendiente
	envido_pendiente_tipo = 0
	envido_cantor_id = 0
	envido_resuelto = true

	var ganador_peer := 0
	var puntos_otorgados := 0

	if acepta:
		# Calcular valores de envido
		var Envido = load("res://scripts/game/Envido.gd")
		var vj1 = Envido.calcular_envido(room.game_logic.mano_j1_servidor)
		var vj2 = Envido.calcular_envido(room.game_logic.mano_j2_servidor)
		# Desempate: gana el mano en caso de empate
		if vj1 == vj2:
			ganador_peer = room.game_logic.mano_quien_empieza
		else:
			ganador_peer = j1 if vj1 > vj2 else j2
		var faltan = PUNTOS_PARTIDA - max(puntos_j1, puntos_j2)
		puntos_otorgados = _calcular_puntos_envido_acumulado(true, faltan)
		if ganador_peer == j1:
			puntos_j1 += puntos_otorgados
		else:
			puntos_j2 += puntos_otorgados
		var pts_j1 = puntos_j1
		var pts_j2 = puntos_j2
		room.mutex.unlock()
		room.notifier.resultado_envido(j1, j2, ganador_peer, puntos_otorgados, vj1, vj2)
		room.notifier.actualizar_puntos(j1, j2, pts_j1, pts_j2)
	else:
		# No quiero: puntos para el cantor
		var faltan = PUNTOS_PARTIDA - max(puntos_j1, puntos_j2)
		puntos_otorgados = _calcular_puntos_envido_acumulado(false, faltan)
		if cantor == j1:
			puntos_j1 += puntos_otorgados
			ganador_peer = j1
		else:
			puntos_j2 += puntos_otorgados
			ganador_peer = j2
		var pts_j1b = puntos_j1
		var pts_j2b = puntos_j2
		room.mutex.unlock()
		room.notifier.resultado_envido(j1, j2, ganador_peer, puntos_otorgados, 0, 0)
		room.notifier.actualizar_puntos(j1, j2, pts_j1b, pts_j2b)

func solicitar_apuesta_truco(peer_id: int, nivel: int):
	room.mutex.lock()
	if not room.jugadores.has(peer_id):
		room.mutex.unlock()
		return
	
	# Validar que no haya apuesta pendiente
	if apuesta_pendiente_nivel != 0:
		print("[Scoring ", room.id, "] Ya hay apuesta pendiente")
		room.mutex.unlock()
		return
	
	# Validar niveles (2=Truco, 3=Retruco, 4=Vale Cuatro)
	var niveles_validos = [2, 3, 4]
	if not niveles_validos.has(nivel):
		print("[Scoring ", room.id, "] Nivel inválido de truco:", nivel)
		room.mutex.unlock()
		return
	
	# No permitir bajar el nivel respecto a valor actual
	if nivel <= valor_truco_actual:
		print("[Scoring ", room.id, "] Nivel ", nivel, " no supera valor actual ", valor_truco_actual)
		room.mutex.unlock()
		return
	
	apuesta_pendiente_nivel = nivel
	apuesta_cantor_id = peer_id
	
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	var pend_nivel = apuesta_pendiente_nivel
	var cantor = apuesta_cantor_id
	room.mutex.unlock()
	
	print("[Scoring ", room.id, "] Jugador ", cantor, " canta nivel ", pend_nivel)
	
	# Avisar a ambos que hay apuesta pendiente
	room.notifier.apuesta_truco_pendiente(j1, j2, pend_nivel, cantor)

func respuesta_apuesta_truco(peer_id: int, acepta: bool):
	room.mutex.lock()
	
	# peer_id debe ser el rival del cantor
	if apuesta_pendiente_nivel == 0:
		room.mutex.unlock()
		return
	
	var j1 = room.jugadores[0]
	var j2 = room.jugadores[1]
	var cantor = apuesta_cantor_id
	var nivel = apuesta_pendiente_nivel
	
	# Rival esperado
	var rival = j1 if j1 != cantor else j2
	
	if peer_id != rival:
		print("[Scoring ", room.id, "] Respuesta no válida: no es el rival")
		room.mutex.unlock()
		return
	
	# Limpiar pendiente
	apuesta_pendiente_nivel = 0
	apuesta_cantor_id = 0
	
	if acepta:
		valor_truco_actual = nivel
		print("[Scoring ", room.id, "] Apuesta aceptada. Valor truco ahora ", valor_truco_actual)
		var nuevo_valor = valor_truco_actual
		room.mutex.unlock()
		
		# Notificar nuevo valor a clientes
		room.notifier.estado_truco_actualizado(j1, j2, nuevo_valor)
	else:
		# No quiero: sumar puntos al cantor según nivel-1 (Truco->1, Retruco->2, Vale4->3)
		var puntos_no_quiero = nivel - 1
		if cantor == j1:
			puntos_j1 += puntos_no_quiero
		else:
			puntos_j2 += puntos_no_quiero
		
		var pts_j1 = puntos_j1
		var pts_j2 = puntos_j2
		print("[Scoring ", room.id, "] NO QUIERO. Cantor ", cantor, " suma ", puntos_no_quiero, " | Puntos J1=", pts_j1, " J2=", pts_j2)
		
		# Termina la mano por no quiero: notificar resultado inmediato (ganador = cantor)
		var ganador_mano = GanadorMano.JUGADOR_1 if cantor == j1 else GanadorMano.JUGADOR_2
		room.mutex.unlock()
		
		room.notifier.notificar_resultado_mano(ganador_mano, pts_j1, pts_j2, j1, j2)
		
		# Preparar siguiente mano
		room.mutex.lock()
		room.game_logic.manos_ganadas_j1 = 0
		room.game_logic.manos_ganadas_j2 = 0
		room.game_logic.cartas_en_mesa.clear()
		room.game_logic.carta_actual = 1
		valor_truco_actual = 1
		room.mutex.unlock()
