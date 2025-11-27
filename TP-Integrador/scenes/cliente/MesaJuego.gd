# scenes/cliente/MesaJuego.gd
extends Control

@onready var mano_propia = $ManoPropia
@onready var mano_rival = $ManoRival
@onready var lbl_puntos = $Puntuacion
@onready var lbl_turno = $LblTurno
@onready var cartas_jugadas = $CartasJugadas
@onready var panel_resultado = $PanelResultado
@onready var lbl_resultado = $PanelResultado/VBoxContainer/LblResultado
@onready var btn_volver_jugar = $PanelResultado/VBoxContainer/BtnVolverJugar
@onready var btn_irse_al_mazo = $BtnIrseAlMazo
@onready var btn_cantar_truco = $BtnCantarTruco
@onready var btn_quiero = $BtnQuiero
@onready var btn_no_quiero = $BtnNoQuiero

var escena_carta = preload("res://scenes/common/Carta.tscn")
var mis_cartas := []  # Referencias a mis cartas en la mano
var valor_truco_actual := 1

func _ready():
	# Ocultar panel de resultado inicialmente
	if panel_resultado:
		panel_resultado.visible = false
	
	# Conectar botones
	if btn_volver_jugar:
		btn_volver_jugar.pressed.connect(_on_btn_volver_jugar_pressed)
	
	if btn_irse_al_mazo:
		btn_irse_al_mazo.pressed.connect(_on_btn_irse_al_mazo_pressed)

	if btn_cantar_truco:
		btn_cantar_truco.pressed.connect(_on_btn_cantar_truco_pressed)

	if btn_quiero:
		btn_quiero.pressed.connect(_on_btn_quiero_pressed)

	if btn_no_quiero:
		btn_no_quiero.pressed.connect(_on_btn_no_quiero_pressed)
	
	await get_tree().create_timer(0.5).timeout
	mostrar_manos()

func _process(delta):
	var mi_id = multiplayer.get_unique_id()
	if Global.turno_actual == mi_id:
		lbl_turno.text = "¡ES TU TURNO! - Click en una carta para jugarla"
		lbl_turno.modulate = Color.YELLOW
		habilitar_mis_cartas(true)
	else:
		lbl_turno.text = "Turno del rival..."
		lbl_turno.modulate = Color.WHITE
		habilitar_mis_cartas(false)

func habilitar_mis_cartas(habilitar: bool):
	for carta in mis_cartas:
		if habilitar:
			carta.habilitar_click()
		else:
			carta.deshabilitar_click()

func _on_carta_clickeada(carta: Carta):
	print("Jugando carta:", carta.numero, " de ", ["oro","copa","espada","basto"][carta.palo])
	# Enviar al servidor
	RedGlobal.rpc_id(1, "solicitar_jugar_carta", Vector2(carta.palo, carta.numero))
	# Deshabilitar todas las cartas mientras esperamos respuesta
	habilitar_mis_cartas(false)

func mostrar_carta_jugada(peer_id: int, carta_vec: Vector2):
	var mi_id = multiplayer.get_unique_id()
	print("Mostrando carta jugada por", peer_id, ":", carta_vec)
	
	# Si es mi carta, quitarla de mi mano
	if peer_id == mi_id:
		quitar_carta_de_mano(carta_vec)
	else:
		# Si es del rival, quitar una carta de dorso
		quitar_carta_rival()
	
	# Mostrar la carta en el centro
	var carta = escena_carta.instantiate()
	carta.palo = carta_vec.x
	carta.numero = carta_vec.y
	cartas_jugadas.add_child(carta)  # Agregar al árbol PRIMERO
	carta.mostrar_carta()  # Luego mostrar

func quitar_carta_de_mano(carta_vec: Vector2):
	for i in range(mis_cartas.size()):
		var carta = mis_cartas[i]
		if carta.palo == carta_vec.x and carta.numero == carta_vec.y:
			mis_cartas.remove_at(i)
			carta.queue_free()
			# Actualizar Global.mi_mano
			for j in range(Global.mi_mano.size()):
				if Global.mi_mano[j] == carta_vec:
					Global.mi_mano.remove_at(j)
					break
			break

func quitar_carta_rival():
	# Quitar la primera carta del rival (todas son dorsos)
	if mano_rival.get_child_count() > 0:
		mano_rival.get_child(0).queue_free()
		if Global.mano_rival.size() > 0:
			Global.mano_rival.remove_at(0)

func mostrar_manos():
	print("Mostrando manos. Mi mano: ", Global.mi_mano)
	print("Mano rival: ", Global.mano_rival)
	for child in mano_propia.get_children():
		child.queue_free()
	for child in mano_rival.get_children():
		child.queue_free()
	
	mis_cartas.clear()
	
	# Mis cartas (visibles)
	for carta_vec in Global.mi_mano:
		var carta = escena_carta.instantiate()
		carta.palo = carta_vec.x
		carta.numero = carta_vec.y
		mano_propia.add_child(carta)  # Agregar al árbol PRIMERO
		carta.mostrar_carta()  # Luego mostrar (ahora @onready está inicializado)
		carta.carta_clickeada.connect(_on_carta_clickeada)
		mis_cartas.append(carta)
	
	# Cartas del rival (dorso)
	for carta_vec in Global.mano_rival:
		var carta = escena_carta.instantiate()
		carta.palo = carta_vec.x
		carta.numero = carta_vec.y
		mano_rival.add_child(carta)  # Agregar al árbol PRIMERO
		carta.mostrar_dorso()  # Luego mostrar
	
	lbl_puntos.text = "0 – 0"

func actualizar_estado_truco(valor: int):
	valor_truco_actual = valor
	# Opcional: feedback visual simple en LblTurno
	if lbl_turno:
		if valor_truco_actual > 1:
			lbl_turno.text = lbl_turno.text + "  | TRUCO! (vale " + str(valor_truco_actual) + ")"

func mostrar_resultado_mano(ganaste: bool, puntos_propios: int, puntos_rival: int):
	if panel_resultado:
		panel_resultado.visible = true
	
	if lbl_resultado:
		if ganaste:
			lbl_resultado.text = "¡GANASTE LA MANO!\n\nPuntos: " + str(puntos_propios) + " - " + str(puntos_rival)
			lbl_resultado.modulate = Color.GREEN
		else:
			lbl_resultado.text = "PERDISTE LA MANO\n\nPuntos: " + str(puntos_propios) + " - " + str(puntos_rival)
			lbl_resultado.modulate = Color.RED
	
	# Actualizar label de puntos
	if lbl_puntos:
		lbl_puntos.text = str(puntos_propios) + " – " + str(puntos_rival)

func _on_btn_volver_jugar_pressed():
	if panel_resultado:
		panel_resultado.visible = false
	
	# Limpiar cartas jugadas
	for child in cartas_jugadas.get_children():
		child.queue_free()
	
	# Notificar al servidor que estamos listos para otra mano
	RedGlobal.rpc_id(1, "jugador_listo_nueva_mano")

func _on_btn_irse_al_mazo_pressed():
	print("Jugador se fue al mazo (rendición)")
	# Notificar al servidor que nos rendimos
	RedGlobal.rpc_id(1, "jugador_se_fue_al_mazo")

func _on_btn_cantar_truco_pressed():
	print("Jugador canta TRUCO")
	# Notificar al servidor que cantamos truco
	RedGlobal.rpc_id(1, "solicitar_apuesta_truco", 2)

func _on_btn_quiero_pressed():
	print("Jugador dice QUIERO al canto")
	RedGlobal.rpc_id(1, "respuesta_apuesta_truco", true)
	mostrar_botones_respuesta(false)

func _on_btn_no_quiero_pressed():
	print("Jugador dice NO QUIERO al canto")
	RedGlobal.rpc_id(1, "respuesta_apuesta_truco", false)
	mostrar_botones_respuesta(false)

func mostrar_botones_respuesta(visible: bool):
	if btn_quiero:
		btn_quiero.visible = visible
	if btn_no_quiero:
		btn_no_quiero.visible = visible

func mostrar_apuesta_truco_pendiente(nivel: int, cantor_peer: int):
	# Mostrar UI de respuesta si me toca responder
	var mi_id = multiplayer.get_unique_id()
	if mi_id != cantor_peer:
		mostrar_botones_respuesta(true)
		var texto_nivel = "Truco" if nivel == 2 else ("Retruco" if nivel == 3 else "Vale Cuatro")
		lbl_turno.text = "Rival cantó " + texto_nivel + ". ¿Quiero?"
