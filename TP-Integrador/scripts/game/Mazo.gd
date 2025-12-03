# scripts/juego/Mazo.gd
extends Node
class_name Mazo

# Constantes
const PALOS_BARAJA = 4
const CARTAS_POR_MANO = 3

var cartas := []

func _init():
	generar_mazo()
	barajar()

func generar_mazo():
	cartas.clear()
	for palo in range(PALOS_BARAJA):
		for num in [1,2,3,4,5,6,7,10,11,12]:
			cartas.append(Vector2(palo, num))

func barajar():
	cartas.shuffle()

func repartir_mano() -> Array:
	var mano = []
	for i in range(CARTAS_POR_MANO):
		if cartas.size() > 0:
			mano.append(cartas.pop_front())
	return mano
