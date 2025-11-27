# Sala.gd - Clase que representa una sala de juego con 2 jugadores
extends Node
class_name Sala

const ValorCartas = preload("res://scripts/juego/ValorCartas.gd")
const MAX_JUGADORES = 2

# Identificador único de la sala
var id: int = 0

# Jugadores en esta sala (máximo 2)
var jugadores := []  # [peer_id_1, peer_id_2]

# Estado del juego
var turno_actual := 0
var cartas_en_mesa := {}  # peer_id -> Vector2 (carta jugada)
var manos_ganadas_j1 := 0
var manos_ganadas_j2 := 0
var carta_actual := 1
var mano_quien_empieza := 0
var puntos_j1 := 0
var puntos_j2 := 0
var jugadores_listos_nueva_mano := []
var valor_truco_actual := 1  # 1 por defecto, 2 si se cantó truco (v1)
var apuesta_pendiente_nivel := 0  # 0 sin apuesta; 2 Truco; 3 Retruco; 4 Vale cuatro
var apuesta_cantor_id := 0

# Estado de la sala
var activa := false
var partida_iniciada := false

# Mutex para proteger el estado de esta sala
var mutex := Mutex.new()

# Referencia al servidor para enviar RPCs
var servidor_ref = null

func _init(sala_id: int, servidor):
	id = sala_id
	servidor_ref = servidor

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
		print("[SALA ", id, "] Jugador ", peer_id, " agregado (", jugadores.size(), "/", MAX_JUGADORES, ")")
		
		# Si la sala se llenó, iniciar partida
		if jugadores.size() == MAX_JUGADORES:
			activa = true
			print("[SALA ", id, "] ¡Sala llena! Iniciando partida...")
		
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
	print("[SALA ", id, "] Jugador ", peer_id, " removido (", jugadores.size(), "/", MAX_JUGADORES, ")")
	mutex.unlock()

func iniciar_partida():
	mutex.lock()
	if jugadores.size() != MAX_JUGADORES or partida_iniciada:
		print("[SALA ", id, "] No se puede iniciar partida - jugadores: ", jugadores.size(), " partida_iniciada: ", partida_iniciada)
		mutex.unlock()
		return
	
	partida_iniciada = true
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	mutex.unlock()
	
	print("[SALA ", id, "] ========== INICIANDO PARTIDA ==========")
	print("[SALA ", id, "] Jugador 1: ", j1)
	print("[SALA ", id, "] Jugador 2: ", j2)
	
	# Cambiar escena en clientes
	print("[SALA ", id, "] Enviando RPC iniciar_partida_cliente a ", j1, " y ", j2)
	servidor_ref.rpc_sala("iniciar_partida_cliente", id, j1, j2)
	
	# Pequeña espera para que cambien de escena
	await servidor_ref.get_tree().create_timer(1.0).timeout
	
	print("[SALA ", id, "] Repartiendo cartas...")
	# Repartir cartas
	repartir_cartas()

func repartir_cartas():
	mutex.lock()
	if jugadores.size() != MAX_JUGADORES:
		mutex.unlock()
		return
	
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	mutex.unlock()
	
	var mazo = Mazo.new()
	var mano1 = mazo.repartir_mano()
	var mano2 = mazo.repartir_mano()
	
	print("[SALA ", id, "] Repartiendo cartas a jugadores ", j1, " y ", j2)
	
	# Enviar manos
	servidor_ref.rpc_sala_id("recibir_mano", id, j1, mano1, mano2)
	servidor_ref.rpc_sala_id("recibir_mano", id, j2, mano2, mano1)
	
	# Iniciar turnos
	mutex.lock()
	turno_actual = j1
	mano_quien_empieza = j1
	reiniciar_mano_interno()
	mutex.unlock()
	
	servidor_ref.rpc_sala("actualizar_turno", id, j1, j2, turno_actual)

func reiniciar_mano_interno():
	# NO usar mutex aquí, ya está locked por el caller
	manos_ganadas_j1 = 0
	manos_ganadas_j2 = 0
	carta_actual = 1
	valor_truco_actual = 1
	apuesta_pendiente_nivel = 0
	apuesta_cantor_id = 0
	print("[SALA ", id, "] ========== NUEVA MANO ==========")

func procesar_carta_jugada(peer_id: int, carta: Vector2):
	mutex.lock()
	
	if not jugadores.has(peer_id):
		mutex.unlock()
		return
	
	if turno_actual != peer_id:
		print("[SALA ", id, "] ERROR: No es el turno de ", peer_id)
		mutex.unlock()
		return
	
	var info = ValorCartas.obtener_valor_truco(carta.y, carta.x)
	print("[SALA ", id, "] Jugador ", peer_id, " jugó: ", info["nombre"], " (valor: ", info["valor"], ")")
	
	# Guardar carta en mesa
	cartas_en_mesa[peer_id] = carta
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	mutex.unlock()
	
	# Notificar a clientes
	servidor_ref.rpc_sala("carta_jugada", id, j1, j2, peer_id, carta)
	
	mutex.lock()
	var cartas_count = cartas_en_mesa.size()
	mutex.unlock()
	
	# Si ambos jugaron, comparar
	if cartas_count == 2:
		comparar_cartas_jugadas()
	else:
		cambiar_turno()

func cambiar_turno():
	mutex.lock()
	var idx = jugadores.find(turno_actual)
	idx = (idx + 1) % jugadores.size()
	turno_actual = jugadores[idx]
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	var turno = turno_actual
	mutex.unlock()
	
	print("[SALA ", id, "] Cambio de turno a: ", turno)
	servidor_ref.rpc_sala("actualizar_turno", id, j1, j2, turno)

func comparar_cartas_jugadas():
	mutex.lock()
	var jugadores_ids = cartas_en_mesa.keys()
	var peer_id_1 = jugadores_ids[0]
	var peer_id_2 = jugadores_ids[1]
	var carta1 = cartas_en_mesa[peer_id_1]
	var carta2 = cartas_en_mesa[peer_id_2]
	
	var info1 = ValorCartas.obtener_valor_truco(carta1.y, carta1.x)
	var info2 = ValorCartas.obtener_valor_truco(carta2.y, carta2.x)
	var resultado = ValorCartas.comparar_cartas(carta1, carta2)
	
	print("[SALA ", id, "] --- Carta ", carta_actual, " ---")
	print("[SALA ", id, "] Jugador ", peer_id_1, ": ", info1["nombre"], " (", info1["valor"], ")")
	print("[SALA ", id, "] Jugador ", peer_id_2, ": ", info2["nombre"], " (", info2["valor"], ")")
	
	var j1 = jugadores[0]
	
	if resultado == 1:
		print("[SALA ", id, "] ¡", info1["nombre"], " GANA a ", info2["nombre"], "!")
		if peer_id_1 == j1:
			manos_ganadas_j1 += 1
			print("[SALA ", id, "] Gana J1 (peer ", peer_id_1, ")")
		else:
			manos_ganadas_j2 += 1
			print("[SALA ", id, "] Gana J2 (peer ", peer_id_1, ")")
		turno_actual = peer_id_1
		print("[SALA ", id, "] Manos ganadas: J1=", manos_ganadas_j1, " J2=", manos_ganadas_j2)
	elif resultado == -1:
		print("[SALA ", id, "] ¡", info2["nombre"], " GANA a ", info1["nombre"], "!")
		if peer_id_2 == j1:
			manos_ganadas_j1 += 1
			print("[SALA ", id, "] Gana J1 (peer ", peer_id_2, ")")
		else:
			manos_ganadas_j2 += 1
			print("[SALA ", id, "] Gana J2 (peer ", peer_id_2, ")")
		turno_actual = peer_id_2
		print("[SALA ", id, "] Manos ganadas: J1=", manos_ganadas_j1, " J2=", manos_ganadas_j2)
	else:
		print("[SALA ", id, "] ¡PARDA! (Empate)")
	
	cartas_en_mesa.clear()
	carta_actual += 1
	
	var j2 = jugadores[1]
	var turno = turno_actual
	mutex.unlock()
	
	# Verificar ganador
	verificar_ganador_mano()
	
	# Notificar turno
	servidor_ref.rpc_sala("actualizar_turno", id, j1, j2, turno)

func verificar_ganador_mano():
	mutex.lock()
	var ganador_mano_actual = 0
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	
	if manos_ganadas_j1 >= MAX_JUGADORES:
		print("[SALA ", id, "] ========================================")
		print("[SALA ", id, "] ¡JUGADOR 1 GANA LA MANO!")
		print("[SALA ", id, "] ========================================")
		puntos_j1 += valor_truco_actual
		ganador_mano_actual = 1
		print("[SALA ", id, "] >>> PUNTOS: J1=", puntos_j1, " | J2=", puntos_j2, " <<<")
		mano_quien_empieza = j2
		turno_actual = mano_quien_empieza
	elif manos_ganadas_j2 >= MAX_JUGADORES:
		print("[SALA ", id, "] ========================================")
		print("[SALA ", id, "] ¡JUGADOR 2 GANA LA MANO!")
		print("[SALA ", id, "] ========================================")
		puntos_j2 += valor_truco_actual
		ganador_mano_actual = 2
		print("[SALA ", id, "] >>> PUNTOS: J1=", puntos_j1, " | J2=", puntos_j2, " <<<")
		mano_quien_empieza = j1
		turno_actual = mano_quien_empieza
	elif carta_actual > 3:
		if manos_ganadas_j1 == manos_ganadas_j2:
			print("[SALA ", id, "] ========================================")
			print("[SALA ", id, "] ¡MANO EMPATADA! Gana mano: ", mano_quien_empieza)
			print("[SALA ", id, "] ========================================")
			if mano_quien_empieza == j1:
				puntos_j1 += valor_truco_actual
				ganador_mano_actual = 1
			else:
				puntos_j2 += valor_truco_actual
				ganador_mano_actual = 2
			print("[SALA ", id, "] >>> PUNTOS: J1=", puntos_j1, " | J2=", puntos_j2, " <<<")
		
		var idx = jugadores.find(mano_quien_empieza)
		idx = (idx + 1) % jugadores.size()
		mano_quien_empieza = jugadores[idx]
		turno_actual = mano_quien_empieza
	
	var pts_j1 = puntos_j1
	var pts_j2 = puntos_j2
	mutex.unlock()
	
	if ganador_mano_actual > 0:
		notificar_resultado_mano(ganador_mano_actual, pts_j1, pts_j2, j1, j2)

func notificar_resultado_mano(ganador_mano: int, pts_j1: int, pts_j2: int, j1: int, j2: int):
	var j1_gano = (ganador_mano == 1)
	# Enviar a J1: ganó?, puntos_propios, puntos_rival
	RedGlobal.rpc_id(j1, "mostrar_resultado_mano", j1_gano, pts_j1, pts_j2)
	
	var j2_gano = (ganador_mano == 2)
	# Enviar a J2: ganó?, puntos_propios, puntos_rival
	RedGlobal.rpc_id(j2, "mostrar_resultado_mano", j2_gano, pts_j2, pts_j1)

func jugador_listo_para_nueva_mano(peer_id: int):
	mutex.lock()
	if not jugadores_listos_nueva_mano.has(peer_id):
		jugadores_listos_nueva_mano.append(peer_id)
		print("[SALA ", id, "] Jugador ", peer_id, " listo para nueva mano (", jugadores_listos_nueva_mano.size(), "/", MAX_JUGADORES, ")")
	
	var listos = jugadores_listos_nueva_mano.size()
	mutex.unlock()
	
	if listos >= MAX_JUGADORES:
		print("[SALA ", id, "] Ambos jugadores listos. Repartiendo nuevas cartas...")
		mutex.lock()
		jugadores_listos_nueva_mano.clear()
		mutex.unlock()
		repartir_cartas()

func jugador_se_rindio(peer_id: int):
	mutex.lock()
	if not jugadores.has(peer_id):
		mutex.unlock()
		return
	
	print("[SALA ", id, "] ¡Jugador ", peer_id, " se rindió!")
	
	# Obtener el rival y determinar quién es J1 y J2
	var rival_id = 0
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	
	for jug in jugadores:
		if jug != peer_id:
			rival_id = jug
			break
	
	# Sumar un punto al rival
	if rival_id == j1:
		puntos_j1 += 1
		print("[SALA ", id, "] Jugador 1 (", j1, ") gana 1 punto por rendición del rival")
	else:
		puntos_j2 += 1
		print("[SALA ", id, "] Jugador 2 (", j2, ") gana 1 punto por rendición del rival")
	
	var pts_j1 = puntos_j1
	var pts_j2 = puntos_j2
	
	mutex.unlock()
	
	# Notificar al jugador que se rindió con los puntos actualizados
	if peer_id == j1:
		# El que se rindió es J1, enviar sus puntos (propios) y los del rival
		RedGlobal.rpc_id(peer_id, "mostrar_resultado_mano", false, pts_j1, pts_j2)
	else:
		# El que se rindió es J2
		RedGlobal.rpc_id(peer_id, "mostrar_resultado_mano", false, pts_j2, pts_j1)
	
	print("[SALA ", id, "] Notificando derrota a jugador ", peer_id)
	
	if rival_id > 0:
		# Notificar al rival que ganó por rendición con los puntos actualizados
		if rival_id == j1:
			RedGlobal.rpc_id(rival_id, "mostrar_resultado_mano", true, pts_j1, pts_j2)
		else:
			RedGlobal.rpc_id(rival_id, "mostrar_resultado_mano", true, pts_j2, pts_j1)
		
		print("[SALA ", id, "] Notificando victoria a jugador ", rival_id)
		print("[SALA ", id, "] >>> PUNTOS: J1=", pts_j1, " | J2=", pts_j2, " <<<")
	
	# Limpiar estado de la mano pero mantener puntos
	mutex.lock()
	manos_ganadas_j1 = 0
	manos_ganadas_j2 = 0
	jugadores_listos_nueva_mano.clear()
	cartas_en_mesa.clear()
	carta_actual = 1
	valor_truco_actual = 1
	apuesta_pendiente_nivel = 0
	apuesta_cantor_id = 0
	mutex.unlock()
	
	print("[SALA ", id, "] Mano terminada por rendición, esperando jugadores para nueva mano")

# Cantar truco: sube el valor de la mano a 2 (v1). Futuras mejoras: retruco, vale cuatro.
func cantar_truco(peer_id: int):
	mutex.lock()
	if not jugadores.has(peer_id):
		mutex.unlock()
		return

	# En esta versión, si ya estaba en 2, no cambia.
	if valor_truco_actual < 2:
		valor_truco_actual = 2
		print("[SALA ", id, "] Jugador ", peer_id, " cantó TRUCO. Valor actual: ", valor_truco_actual)
	else:
		print("[SALA ", id, "] TRUCO ya activo. Valor actual: ", valor_truco_actual)

	var j1 = jugadores[0]
	var j2 = jugadores[1]
	var valor = valor_truco_actual
	mutex.unlock()

	# Notificar a ambos clientes el estado del truco (puede mostrar un banner)
	servidor_ref.rpc_sala("estado_truco_actualizado", id, j1, j2, valor)

# Flujo de apuesta: solicitar (cantor) y respuesta (rival)
func solicitar_apuesta_truco(peer_id: int, nivel: int):
	mutex.lock()
	if not jugadores.has(peer_id):
		mutex.unlock()
		return
	# Validar niveles ascendentes y sólo si no hay pendiente
	if apuesta_pendiente_nivel != 0:
		print("[SALA ", id, "] Ya hay apuesta pendiente")
		mutex.unlock()
		return
	var niveles_validos = [2,3,4]
	if not niveles_validos.has(nivel):
		print("[SALA ", id, "] Nivel inválido de truco:", nivel)
		mutex.unlock()
		return
	# No permitir bajar el nivel respecto a valor actual
	if nivel <= valor_truco_actual:
		print("[SALA ", id, "] Nivel", nivel, "no supera valor actual", valor_truco_actual)
		mutex.unlock()
		return
	apuesta_pendiente_nivel = nivel
	apuesta_cantor_id = peer_id
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	var pend_nivel = apuesta_pendiente_nivel
	var cantor = apuesta_cantor_id
	mutex.unlock()
	print("[SALA ", id, "] Jugador", cantor, "canta nivel", pend_nivel)
	# Avisar a ambos que hay apuesta pendiente
	servidor_ref.rpc_sala("apuesta_truco_pendiente", id, j1, j2, pend_nivel, cantor)

func respuesta_apuesta_truco(peer_id: int, acepta: bool):
	mutex.lock()
	# peer_id debe ser el rival del cantor
	if apuesta_pendiente_nivel == 0:
		mutex.unlock()
		return
	var j1 = jugadores[0]
	var j2 = jugadores[1]
	var cantor = apuesta_cantor_id
	var nivel = apuesta_pendiente_nivel
	# Rival esperado
	var rival = j1
	if j1 == cantor:
		rival = j2
	if peer_id != rival:
		print("[SALA ", id, "] Respuesta no válida: no es el rival")
		mutex.unlock()
		return
	# Limpiar pendiente
	apuesta_pendiente_nivel = 0
	apuesta_cantor_id = 0
	if acepta:
		valor_truco_actual = nivel
		print("[SALA ", id, "] Apuesta aceptada. Valor truco ahora", valor_truco_actual)
		var nuevo_valor = valor_truco_actual
		mutex.unlock()
		# Notificar nuevo valor a clientes
		servidor_ref.rpc_sala("estado_truco_actualizado", id, j1, j2, nuevo_valor)
	else:
		# No quiero: sumar puntos al cantor según nivel-1 (Truco->1, Retruco->2, Vale4->3)
		var puntos_no_quiero = nivel - 1
		if cantor == j1:
			puntos_j1 += puntos_no_quiero
		else:
			puntos_j2 += puntos_no_quiero
		var pts_j1 = puntos_j1
		var pts_j2 = puntos_j2
		print("[SALA ", id, "] NO QUIERO. Cantor", cantor, "suma", puntos_no_quiero, "| Puntos J1=", pts_j1, "J2=", pts_j2)
		# Termina la mano por no quiero: notificar resultado inmediato (ganador = cantor)
		var ganador_mano = 1
		if cantor != j1:
			ganador_mano = 2
		mutex.unlock()
		notificar_resultado_mano(ganador_mano, pts_j1, pts_j2, j1, j2)
		# Preparar siguiente mano (manteniendo quién empieza próxima lógica)
		mutex.lock()
		manos_ganadas_j1 = 0
		manos_ganadas_j2 = 0
		cartas_en_mesa.clear()
		carta_actual = 1
		valor_truco_actual = 1
		mutex.unlock()





