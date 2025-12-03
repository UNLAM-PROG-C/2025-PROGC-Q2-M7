# Envido.gd - Cálculo de envido según reglas de Truco argentino
class_name Envido

static func valor_envido_de_numero(n: int) -> int:
	if n >= 10:
		return 0
	return n

static func calcular_envido(mano: Array) -> int:
	# mano: Array[Vector2] donde x=palo (0..3), y=numero (1..12)
	if mano.size() != 3:
		# Asegurar robustez: si no hay 3 cartas, calcula mejor posible
		return _calcular_envido_generico(mano)
	return _calcular_envido_generico(mano)

static func _calcular_envido_generico(mano: Array) -> int:
	# Sin combinación del mismo palo: máximo individual
	var max_individual := 0
	for c in mano:
		var v := valor_envido_de_numero(int(c.y))
		if v > max_individual:
			max_individual = v
	# Con combinación: elegir mejor par del mismo palo y sumar +20
	var mejor_combinacion := 0
	for i in range(mano.size()):
		for j in range(i + 1, mano.size()):
			var c1: Vector2 = mano[i]
			var c2: Vector2 = mano[j]
			if int(c1.x) == int(c2.x):
				var v := valor_envido_de_numero(int(c1.y)) + valor_envido_de_numero(int(c2.y)) + 20
				if v > mejor_combinacion:
					mejor_combinacion = v
	# Elegir mejor resultado
	return max(mejor_combinacion, max_individual)
