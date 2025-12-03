# TrucoNotifier.gd - Envío de RPCs a clientes
class_name TrucoNotifier

# Referencia a la sala y al servidor
var room = null
var servidor_ref = null

func _init(room_ref, servidor):
	room = room_ref
	servidor_ref = servidor

func iniciar_partida_cliente(j1: int, j2: int):
	print("[Notifier ", room.id, "] Enviando RPC iniciar_partida_cliente a ", j1, " y ", j2)
	servidor_ref.rpc_sala("iniciar_partida_cliente", room.id, j1, j2)

func recibir_mano(peer_id: int, mi_mano: Array, mano_rival: Array):
	servidor_ref.rpc_sala_id("recibir_mano", room.id, peer_id, mi_mano, mano_rival)

func actualizar_turno(j1: int, j2: int, turno: int):
	servidor_ref.rpc_sala("actualizar_turno", room.id, j1, j2, turno)

func carta_jugada(j1: int, j2: int, peer_id: int, carta: Vector2):
	servidor_ref.rpc_sala("carta_jugada", room.id, j1, j2, peer_id, carta)

func estado_truco_actualizado(j1: int, j2: int, valor: int):
	servidor_ref.rpc_sala("estado_truco_actualizado", room.id, j1, j2, valor)

func apuesta_truco_pendiente(j1: int, j2: int, nivel: int, cantor: int):
	servidor_ref.rpc_sala("apuesta_truco_pendiente", room.id, j1, j2, nivel, cantor)

func notificar_resultado_mano(ganador_mano: int, pts_j1: int, pts_j2: int, j1: int, j2: int):
	var j1_gano = (ganador_mano == 1)
	# Enviar a J1: ganó?, puntos_propios, puntos_rival
	ClientRPCHandler.rpc_id(j1, "mostrar_resultado_mano", j1_gano, pts_j1, pts_j2)
	
	var j2_gano = (ganador_mano == 2)
	# Enviar a J2: ganó?, puntos_propios, puntos_rival
	ClientRPCHandler.rpc_id(j2, "mostrar_resultado_mano", j2_gano, pts_j2, pts_j1)

func envido_pendiente(j1: int, j2: int, tipo: int, cantor: int):
	servidor_ref.rpc_sala("envido_pendiente", room.id, j1, j2, tipo, cantor)

func resultado_envido(j1: int, j2: int, ganador_peer: int, puntos: int, envido_j1: int, envido_j2: int):
	var payload := {
		"ganador_peer": ganador_peer,
		"puntos": puntos,
		"envido_j1": envido_j1,
		"envido_j2": envido_j2,
	}
	servidor_ref.rpc_sala("resultado_envido", room.id, j1, j2, payload)

func actualizar_puntos(j1: int, j2: int, pts_j1: int, pts_j2: int):
	# Enviar a cada cliente su perspectiva
	ClientRPCHandler.rpc_id(j1, "actualizar_puntos", pts_j1, pts_j2)
	ClientRPCHandler.rpc_id(j2, "actualizar_puntos", pts_j2, pts_j1)
