# GameStateHandler.gd - Procesa RPCs del servidor y actualiza estado local
extends Node

# Referencias necesarias
var card_manager = null
var game_table_ui = null

# Estado del juego
var valor_truco_actual := 1
var apuesta_pendiente := false
var ultimo_cantor_peer := 0
var proximo_quien_puede_subir := 0
var envido_pendiente := false
var envido_tipo_pendiente := 0
var envido_habilitado := true
var cartas_primera_ronda := 0
var mensaje_canto_pendiente := ""
var espera_respuesta_canto := false
var cantor_pendiente_peer := 0

func _actualizar_botones_canto(mi_id: int):
	var es_mi_turno = (Global.turno_actual == mi_id)
	# Permitir envido si: está habilitado, no hay espera de respuesta O si hay envido pendiente y soy el rival del cantor (para encadenar)
	var puedo_encadenar_envido = envido_pendiente and (mi_id != cantor_pendiente_peer)
	var envido_enabled = envido_habilitado and (not espera_respuesta_canto or puedo_encadenar_envido)
	if game_table_ui and game_table_ui.has_method("set_envido_habilitado"):
		game_table_ui.set_envido_habilitado(envido_enabled)

	if game_table_ui and game_table_ui.btn_cantar_truco:
		var habilitar_truco = es_mi_turno and not espera_respuesta_canto
		if not habilitar_truco:
			game_table_ui.btn_cantar_truco.disabled = true
			return
		# Respeta límites de nivel y alternancia del último cantor
		var puede_subir = (valor_truco_actual < 4)
		if ultimo_cantor_peer != 0:
			puede_subir = puede_subir and (mi_id != ultimo_cantor_peer)
		game_table_ui.btn_cantar_truco.disabled = not puede_subir

func setup(card_mgr, ui):
	card_manager = card_mgr
	game_table_ui = ui

func procesar_turno_actualizado(mi_id: int):
	# Llamado desde _process para actualizar UI de turno
	if espera_respuesta_canto:
		game_table_ui.lbl_turno.text = mensaje_canto_pendiente
		var soy_quien_responde = (mi_id != cantor_pendiente_peer)
		game_table_ui.lbl_turno.modulate = Color.YELLOW if soy_quien_responde else Color.WHITE
		card_manager.habilitar_mis_cartas(false)
	else:
		if Global.turno_actual == mi_id:
			game_table_ui.lbl_turno.text = "¡ES TU TURNO! - Click en una carta para jugarla"
			game_table_ui.lbl_turno.modulate = Color.YELLOW
			card_manager.habilitar_mis_cartas(true)
		else:
			game_table_ui.lbl_turno.text = "Turno del rival..."
			game_table_ui.lbl_turno.modulate = Color.WHITE
			card_manager.habilitar_mis_cartas(false)
	_actualizar_botones_canto(mi_id)

func procesar_carta_jugada(peer_id: int, carta_vec: Vector2):
	var mi_id = multiplayer.get_unique_id()
	card_manager.mostrar_carta_jugada(peer_id, carta_vec, mi_id)
	# Contar cartas de la primera ronda para bloquear envido cuando ambos jugaron
	if cartas_primera_ronda < 2:
		cartas_primera_ronda += 1
		if cartas_primera_ronda >= 2 and envido_habilitado:
			envido_habilitado = false
			if game_table_ui and game_table_ui.has_method("set_envido_habilitado"):
				game_table_ui.set_envido_habilitado(false)

func procesar_estado_truco(valor: int):
	valor_truco_actual = valor
	apuesta_pendiente = false
	espera_respuesta_canto = false
	mensaje_canto_pendiente = ""
	cantor_pendiente_peer = 0
	# Tras una aceptación, el derecho a subir pasa al rival del último cantor
	if ultimo_cantor_peer != 0:
		var mi_id = multiplayer.get_unique_id()
		var rival = mi_id
		# Determinar rival desde Global si está disponible
		if Global.mano_rival.size() > 0:
			rival = mi_id  # placeholder: desconocemos peer rival exacto aquí
		# Si conocemos el último cantor, alternamos turno de subida
		proximo_quien_puede_subir = 0 if mi_id == ultimo_cantor_peer else mi_id
	# Feedback visual en LblTurno
	if game_table_ui.lbl_turno and valor_truco_actual > 1:
		var texto_actual = game_table_ui.lbl_turno.text
		if not texto_actual.contains("TRUCO"):
			game_table_ui.lbl_turno.text = texto_actual + "  | TRUCO! (vale " + str(valor_truco_actual) + ")"
	# Actualizar texto del botón de canto/subida
	if game_table_ui.btn_cantar_truco:
		var mi_id_btn = multiplayer.get_unique_id()
		var puede_subir = false
		# Regla: el que NO cantó la última subida es quien puede pedir la siguiente
		if ultimo_cantor_peer != 0:
			puede_subir = (mi_id_btn != ultimo_cantor_peer)
		else:
			# Si no hubo cantor aún (valor=1), cualquiera puede iniciar Truco
			puede_subir = (valor_truco_actual == 1)

		if valor_truco_actual == 1:
			game_table_ui.btn_cantar_truco.text = "TRUCO"
			game_table_ui.btn_cantar_truco.disabled = not puede_subir
		elif valor_truco_actual == 2:
			game_table_ui.btn_cantar_truco.text = "RETRUCO"
			game_table_ui.btn_cantar_truco.disabled = not puede_subir
		elif valor_truco_actual == 3:
			game_table_ui.btn_cantar_truco.text = "VALE CUATRO"
			game_table_ui.btn_cantar_truco.disabled = not puede_subir
		else:
			game_table_ui.btn_cantar_truco.text = "VALE CUATRO"
			game_table_ui.btn_cantar_truco.disabled = true
	_actualizar_botones_canto(multiplayer.get_unique_id())

func procesar_apuesta_truco_pendiente(nivel: int, cantor_peer: int):
	# Mostrar UI de respuesta si me toca responder
	var mi_id = multiplayer.get_unique_id()
	var texto_nivel = "TRUCO" if nivel == 2 else ("RETRUCO" if nivel == 3 else "VALE CUATRO")
	apuesta_pendiente = true
	ultimo_cantor_peer = cantor_peer
	cantor_pendiente_peer = cantor_peer
	if mi_id != cantor_peer:
		game_table_ui.mostrar_botones_respuesta(true)
		mensaje_canto_pendiente = "¡Es tu turno! ¡Y te cantaron " + texto_nivel + "!"
		espera_respuesta_canto = true
	else:
		mensaje_canto_pendiente = "Cantaste " + texto_nivel + ". Esperando respuesta..."
		espera_respuesta_canto = true
	if game_table_ui.btn_cantar_truco:
		game_table_ui.btn_cantar_truco.disabled = true
	_actualizar_botones_canto(mi_id)

func procesar_envido_pendiente(tipo: int, cantor_peer: int):
	envido_pendiente = true
	envido_tipo_pendiente = tipo
	var mi_id = multiplayer.get_unique_id()
	cantor_pendiente_peer = cantor_peer
	var texto_nivel = "ENVIDO" if tipo == 1 else ("REAL ENVIDO" if tipo == 2 else "FALTA ENVIDO")
	if mi_id != cantor_peer:
		game_table_ui.mostrar_botones_respuesta(true)
		mensaje_canto_pendiente = "¡Es tu turno! ¡Y te cantaron " + texto_nivel + "!"
		espera_respuesta_canto = true
	else:
		mensaje_canto_pendiente = "Cantaste " + texto_nivel + ". Esperando respuesta..."
		espera_respuesta_canto = true
	_actualizar_botones_canto(mi_id)

func solicitar_envido(tipo: int):
	print("[GameStateHandler] Cantar envido tipo: ", tipo)
	ServerRPCHandler.rpc_id(1, "cantar_envido", tipo)

func responder_envido(acepta: bool):
	print("[GameStateHandler] Responder envido: ", acepta)
	ServerRPCHandler.rpc_id(1, "respuesta_envido", acepta)
	game_table_ui.mostrar_botones_respuesta(false)
	envido_pendiente = false
	espera_respuesta_canto = false
	mensaje_canto_pendiente = ""
	cantor_pendiente_peer = 0
	_actualizar_botones_canto(multiplayer.get_unique_id())

func procesar_resultado_mano(ganaste: bool, puntos_propios: int, puntos_rival: int):
	if game_table_ui.panel_resultado:
		game_table_ui.panel_resultado.visible = true
	
	if game_table_ui.lbl_resultado:
		if ganaste:
			game_table_ui.lbl_resultado.text = "¡GANASTE LA MANO!\n\nPuntos: " + str(puntos_propios) + " - " + str(puntos_rival)
			game_table_ui.lbl_resultado.modulate = Color.GREEN
		else:
			game_table_ui.lbl_resultado.text = "PERDISTE LA MANO\n\nPuntos: " + str(puntos_propios) + " - " + str(puntos_rival)
			game_table_ui.lbl_resultado.modulate = Color.RED
	
	# Actualizar label de puntos
	if game_table_ui.lbl_puntos:
		game_table_ui.lbl_puntos.text = str(puntos_propios) + " – " + str(puntos_rival)

func mostrar_resultado_envido(ganador_peer: int, puntos: int, envido_j1: int, envido_j2: int):
	# Feedback ligero en LblTurno; los puntos se actualizan por RPC aparte
	var mi_id = multiplayer.get_unique_id()
	var yo_gane = (ganador_peer == mi_id)
	var resultado := "¡GANASTE!" if yo_gane else "Perdiste"
	var texto := "Envido: %s vs %s | %s (+%s)" % [str(envido_j1), str(envido_j2), resultado, str(puntos)]
	game_table_ui.lbl_turno.text = texto
	espera_respuesta_canto = false
	mensaje_canto_pendiente = ""
	cantor_pendiente_peer = 0
	# Deshabilitar envido después de resolverse (ya sea quiero o no quiero)
	envido_habilitado = false
	_actualizar_botones_canto(multiplayer.get_unique_id())

func actualizar_puntos(puntos_propios: int, puntos_rival: int):
	if game_table_ui.lbl_puntos:
		game_table_ui.lbl_puntos.text = str(puntos_propios) + " – " + str(puntos_rival)

func procesar_manos_recibidas():
	# Reiniciar estado de apuesta en cliente al comenzar cada mano
	valor_truco_actual = 1
	apuesta_pendiente = false
	envido_pendiente = false
	envido_habilitado = true
	cartas_primera_ronda = 0
	mensaje_canto_pendiente = ""
	espera_respuesta_canto = false
	cantor_pendiente_peer = 0
	card_manager.mostrar_manos(Global.mi_mano, Global.mano_rival)
	# NO reiniciar label de puntos - mantener acumulado entre manos
	# Resetear botones de UI
	game_table_ui.mostrar_botones_respuesta(false)
	if game_table_ui.btn_cantar_truco:
		game_table_ui.btn_cantar_truco.text = "TRUCO"
		game_table_ui.btn_cantar_truco.disabled = false
	if game_table_ui and game_table_ui.has_method("set_envido_habilitado"):
		game_table_ui.set_envido_habilitado(true)
	_actualizar_botones_canto(multiplayer.get_unique_id())

func solicitar_jugar_carta(carta_vec: Vector2):
	print("[GameStateHandler] Jugando carta: ", carta_vec.y, " de ", ["oro","copa","espada","basto"][carta_vec.x])
	ServerRPCHandler.rpc_id(1, "solicitar_jugar_carta", carta_vec)
	# Deshabilitar cartas mientras esperamos respuesta
	card_manager.habilitar_mis_cartas(false)

func solicitar_apuesta_truco(nivel: int):
	print("[GameStateHandler] Solicitando apuesta truco nivel: ", nivel)
	ServerRPCHandler.rpc_id(1, "solicitar_apuesta_truco", nivel)
	apuesta_pendiente = true
	# Al cantar, yo paso a ser el último cantor
	ultimo_cantor_peer = multiplayer.get_unique_id()

func responder_apuesta_truco(acepta: bool):
	print("[GameStateHandler] Respondiendo apuesta truco: ", acepta)
	ServerRPCHandler.rpc_id(1, "respuesta_apuesta_truco", acepta)
	game_table_ui.mostrar_botones_respuesta(false)

func jugador_listo_nueva_mano():
	print("[GameStateHandler] Jugador listo para nueva mano")
	ServerRPCHandler.rpc_id(1, "jugador_listo_nueva_mano")

func jugador_se_fue_al_mazo():
	print("[GameStateHandler] Jugador se fue al mazo (rendición)")
	ServerRPCHandler.rpc_id(1, "jugador_se_fue_al_mazo")
