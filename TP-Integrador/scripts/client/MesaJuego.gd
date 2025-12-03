# GameTable.gd - UI de la mesa de juego (antes MesaJuego.gd)
extends Control

# Constantes
const DELAY_INICIALIZACION = 0.5

# Precargar clases
const CardManager = preload("res://scripts/client/CardManager.gd")
var GameStateHandler = load("res://scripts/client/GameStateHandler.gd")

# Componentes del cliente
var card_manager
var state_handler

# Referencias a nodos de UI
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
@onready var btn_envido = $BtnEnvido if has_node("BtnEnvido") else null
@onready var btn_real_envido = $BtnRealEnvido if has_node("BtnRealEnvido") else null
@onready var btn_falta_envido = $BtnFaltaEnvido if has_node("BtnFaltaEnvido") else null
@onready var btn_quiero = $BtnQuiero
@onready var btn_no_quiero = $BtnNoQuiero

func _ready():
	# Inicializar componentes (usar setup() en lugar de constructor con args)
	card_manager = CardManager.new()
	add_child(card_manager)
	card_manager.setup(mano_propia, mano_rival, cartas_jugadas)
	card_manager.set_carta_click_callback(_on_carta_clickeada)

	state_handler = GameStateHandler.new()
	add_child(state_handler)
	state_handler.setup(card_manager, self)
	
	# Ocultar panel de resultado inicialmente
	if panel_resultado:
		panel_resultado.visible = false
	
	# Ocultar botones de respuesta inicialmente
	mostrar_botones_respuesta(false)
	
	# Conectar botones
	if btn_volver_jugar:
		btn_volver_jugar.pressed.connect(_on_btn_volver_jugar_pressed)
	
	if btn_irse_al_mazo:
		btn_irse_al_mazo.pressed.connect(_on_btn_irse_al_mazo_pressed)

	if btn_cantar_truco:
		btn_cantar_truco.pressed.connect(_on_btn_cantar_truco_pressed)

	if btn_envido:
		btn_envido.pressed.connect(_on_btn_envido_pressed)

	if btn_real_envido:
		btn_real_envido.pressed.connect(_on_btn_real_envido_pressed)

	if btn_falta_envido:
		btn_falta_envido.pressed.connect(_on_btn_falta_envido_pressed)

	if btn_quiero:
		btn_quiero.pressed.connect(_on_btn_quiero_pressed)

	if btn_no_quiero:
		btn_no_quiero.pressed.connect(_on_btn_no_quiero_pressed)
	
	await get_tree().create_timer(DELAY_INICIALIZACION).timeout
	if state_handler:
		state_handler.procesar_manos_recibidas()

func mostrar_manos():
	# Wrapper para compatibilidad con ClientRPCHandler
	if state_handler:
		state_handler.procesar_manos_recibidas()

func _process(_delta):
	var mi_id = multiplayer.get_unique_id()
	if state_handler != null:
		state_handler.procesar_turno_actualizado(mi_id)

# ========== CALLBACKS DE UI ==========

func _on_carta_clickeada(carta):
	var carta_vec = Vector2(carta.palo, carta.numero)
	state_handler.solicitar_jugar_carta(carta_vec)

func _on_btn_volver_jugar_pressed():
	if panel_resultado:
		panel_resultado.visible = false
	
	# Limpiar cartas jugadas
	card_manager.limpiar_cartas_jugadas()
	
	# Notificar al servidor
	state_handler.jugador_listo_nueva_mano()

func _on_btn_irse_al_mazo_pressed():
	state_handler.jugador_se_fue_al_mazo()

func _on_btn_cantar_truco_pressed():
	# Solo el que NO cantó la última subida puede escalar
	var mi_id = multiplayer.get_unique_id()
	if state_handler.ultimo_cantor_peer != 0 and mi_id == state_handler.ultimo_cantor_peer:
		return
	# Según el valor actual, subir la apuesta: Truco->Retruco->Vale Cuatro
	var nivel_siguiente = 0
	match state_handler.valor_truco_actual:
		1:
			nivel_siguiente = 2
		2:
			nivel_siguiente = 3
		3:
			nivel_siguiente = 4
		_:
			nivel_siguiente = 0
	if nivel_siguiente > 0:
		state_handler.solicitar_apuesta_truco(nivel_siguiente)

func _on_btn_quiero_pressed():
	if state_handler.envido_pendiente:
		state_handler.responder_envido(true)
	else:
		state_handler.responder_apuesta_truco(true)

func _on_btn_no_quiero_pressed():
	if state_handler.envido_pendiente:
		state_handler.responder_envido(false)
	else:
		state_handler.responder_apuesta_truco(false)

# Envido botones
func _on_btn_envido_pressed():
	state_handler.solicitar_envido(1)

func _on_btn_real_envido_pressed():
	state_handler.solicitar_envido(2)

func _on_btn_falta_envido_pressed():
	state_handler.solicitar_envido(3)

# ========== MÉTODOS PÚBLICOS LLAMADOS POR ClientRPCHandler ==========

func mostrar_carta_jugada(peer_id: int, carta_vec: Vector2):
	state_handler.procesar_carta_jugada(peer_id, carta_vec)

func actualizar_estado_truco(valor: int):
	state_handler.procesar_estado_truco(valor)

func mostrar_apuesta_truco_pendiente(nivel: int, cantor_peer: int):
	state_handler.procesar_apuesta_truco_pendiente(nivel, cantor_peer)

func mostrar_envido_pendiente(tipo: int, cantor_peer: int):
	state_handler.procesar_envido_pendiente(tipo, cantor_peer)

func mostrar_resultado_mano(ganaste: bool, puntos_propios: int, puntos_rival: int):
	state_handler.procesar_resultado_mano(ganaste, puntos_propios, puntos_rival)

func mostrar_resultado_envido(ganador_peer: int, puntos: int, envido_j1: int, envido_j2: int):
	state_handler.mostrar_resultado_envido(ganador_peer, puntos, envido_j1, envido_j2)

func actualizar_puntos(puntos_propios: int, puntos_rival: int):
	state_handler.actualizar_puntos(puntos_propios, puntos_rival)

func mostrar_botones_respuesta(visible: bool):
	if btn_quiero:
		btn_quiero.visible = visible
	if btn_no_quiero:
		btn_no_quiero.visible = visible
	if btn_cantar_truco:
		# Ocultar el botón de subir apuesta mientras hay respuesta pendiente
		btn_cantar_truco.visible = not visible

func set_envido_habilitado(habilitado: bool):
	if btn_envido:
		btn_envido.disabled = not habilitado
	if btn_real_envido:
		btn_real_envido.disabled = not habilitado
	if btn_falta_envido:
		btn_falta_envido.disabled = not habilitado
