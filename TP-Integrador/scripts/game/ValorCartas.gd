# scripts/juego/ValorCartas.gd
extends Node
class_name ValorCartas

# Enums para palos y números
enum Palo { ORO, COPA, ESPADA, BASTO }
enum Numero { 
	CUATRO = 4, CINCO = 5, SEIS = 6, SIETE = 7, 
	SOTA = 10, CABALLO = 11, REY = 12,
	ANCHO = 1, DOS = 2, TRES = 3
}

# Constantes de valores del Truco
const VALOR_ANCHO_ESPADA = 14
const VALOR_ANCHO_BASTO = 13
const VALOR_SIETE_ESPADA = 12
const VALOR_SIETE_ORO = 11
const VALOR_TRES = 10
const VALOR_DOS = 9
const VALOR_ANCHO_ORO = 8
const VALOR_ANCHO_COPA = 7
const VALOR_REY = 6
const VALOR_CABALLO = 5
const VALOR_SOTA = 4
const VALOR_SIETE = 3
const VALOR_SEIS = 2
const VALOR_CINCO = 1
const VALOR_CUATRO = 0

# Valores del Truco argentino
static func obtener_valor_truco(numero: int, palo: int) -> Dictionary:
	# Retorna {valor: int, nombre: String}
	
	# Ancho de espada (1 de espada) - Carta más alta
	if numero == Numero.ANCHO and palo == Palo.ESPADA:
		return {"valor": VALOR_ANCHO_ESPADA, "nombre": "Ancho de espada"}
	
	# Ancho de basto (1 de basto) - Segunda más alta
	if numero == Numero.ANCHO and palo == Palo.BASTO:
		return {"valor": VALOR_ANCHO_BASTO, "nombre": "Ancho de basto"}
	
	# Siete de espada
	if numero == Numero.SIETE and palo == Palo.ESPADA:
		return {"valor": VALOR_SIETE_ESPADA, "nombre": "Siete de espada"}
	
	# Siete de oro
	if numero == Numero.SIETE and palo == Palo.ORO:
		return {"valor": VALOR_SIETE_ORO, "nombre": "Siete de oro"}
	
	# Tres (cualquier palo)
	if numero == Numero.TRES:
		return {"valor": VALOR_TRES, "nombre": "Tres"}
	
	# Dos (cualquier palo)
	if numero == Numero.DOS:
		return {"valor": VALOR_DOS, "nombre": "Dos"}
	
	# Ancho de oro (1 de oro) - Falso
	if numero == Numero.ANCHO and palo == Palo.ORO:
		return {"valor": VALOR_ANCHO_ORO, "nombre": "Ancho de oro (falso)"}
	
	# Ancho de copa (1 de copa) - Falso
	if numero == Numero.ANCHO and palo == Palo.COPA:
		return {"valor": VALOR_ANCHO_COPA, "nombre": "Ancho de copa (falso)"}
	
	# Reyes (12)
	if numero == Numero.REY:
		return {"valor": VALOR_REY, "nombre": "Rey"}
	
	# Caballos (11)
	if numero == Numero.CABALLO:
		return {"valor": VALOR_CABALLO, "nombre": "Caballo"}
	
	# Sotas (10)
	if numero == Numero.SOTA:
		return {"valor": VALOR_SOTA, "nombre": "Sota"}
	
	# Siete de copa y basto
	if numero == Numero.SIETE and (palo == Palo.COPA or palo == Palo.BASTO):
		return {"valor": VALOR_SIETE, "nombre": "Siete"}
	
	# Seis
	if numero == Numero.SEIS:
		return {"valor": VALOR_SEIS, "nombre": "Seis"}
	
	# Cinco
	if numero == Numero.CINCO:
		return {"valor": VALOR_CINCO, "nombre": "Cinco"}
	
	# Cuatro
	if numero == Numero.CUATRO:
		return {"valor": VALOR_CUATRO, "nombre": "Cuatro"}
	
	return {"valor": VALOR_CUATRO, "nombre": "Carta inválida"}

static func comparar_cartas(carta1: Vector2, carta2: Vector2) -> int:
	# Retorna: 1 si carta1 gana, -1 si carta2 gana, 0 si empate (parda)
	var valor1 = obtener_valor_truco(carta1.y, carta1.x)["valor"]
	var valor2 = obtener_valor_truco(carta2.y, carta2.x)["valor"]
	
	if valor1 > valor2:
		return 1
	elif valor1 < valor2:
		return -1
	else:
		return 0  # Empate (parda)
