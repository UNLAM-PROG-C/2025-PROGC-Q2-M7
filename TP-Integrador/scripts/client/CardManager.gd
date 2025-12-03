# CardManager.gd - Gestión de cartas en mano y mesa del cliente
extends Node

const Carta = preload("res://scripts/client/Carta.gd")

var escena_carta = preload("res://scenes/cliente/Carta.tscn")
var mis_cartas := []  # Referencias a mis cartas en la mano

# Referencias a contenedores de UI
var mano_propia_container = null
var mano_rival_container = null
var cartas_jugadas_container = null

# Callback para clicks en cartas
var on_carta_clickeada_callback: Callable

func setup(mano_propia, mano_rival, cartas_jugadas):
	mano_propia_container = mano_propia
	mano_rival_container = mano_rival
	cartas_jugadas_container = cartas_jugadas

func set_carta_click_callback(callback: Callable):
	on_carta_clickeada_callback = callback

func mostrar_manos(mi_mano: Array, mano_rival: Array):
	print("[CardManager] Mostrando manos. Mi mano: ", mi_mano)
	print("[CardManager] Mano rival: ", mano_rival)
	
	limpiar_manos()
	
	# Mis cartas (visibles)
	for carta_vec in mi_mano:
		var carta = escena_carta.instantiate()
		carta.palo = carta_vec.x
		carta.numero = carta_vec.y
		mano_propia_container.add_child(carta)
		carta.mostrar_carta()
		if on_carta_clickeada_callback:
			carta.carta_clickeada.connect(on_carta_clickeada_callback)
		mis_cartas.append(carta)
	
	# Cartas del rival (dorso)
	for carta_vec in mano_rival:
		var carta = escena_carta.instantiate()
		carta.palo = carta_vec.x
		carta.numero = carta_vec.y
		mano_rival_container.add_child(carta)
		carta.mostrar_dorso()

func limpiar_manos():
	for child in mano_propia_container.get_children():
		child.queue_free()
	for child in mano_rival_container.get_children():
		child.queue_free()
	
	mis_cartas.clear()

func habilitar_mis_cartas(habilitar: bool):
	for carta in mis_cartas:
		if habilitar:
			carta.habilitar_click()
		else:
			carta.deshabilitar_click()

func mostrar_carta_jugada(peer_id: int, carta_vec: Vector2, mi_id: int):
	print("[CardManager] Mostrando carta jugada por ", peer_id, ": ", carta_vec)
	
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
	cartas_jugadas_container.add_child(carta)
	carta.mostrar_carta()

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
	if mano_rival_container.get_child_count() > 0:
		mano_rival_container.get_child(0).queue_free()
		if Global.mano_rival.size() > 0:
			Global.mano_rival.remove_at(0)

func limpiar_cartas_jugadas():
	for child in cartas_jugadas_container.get_children():
		child.queue_free()
