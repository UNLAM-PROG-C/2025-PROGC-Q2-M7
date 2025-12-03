# Matchmaking.gd - Gestiona la cola de espera y emparejamiento de jugadores
class_name Matchmaking

# Constantes
const JUGADORES_POR_PARTIDA = 2

var cola_espera := []  # [peer_id, peer_id, ...]
var mutex_cola := Mutex.new()  # Protege la cola

func agregar_jugador(peer_id: int) -> int:
	mutex_cola.lock()
	if not cola_espera.has(peer_id):
		cola_espera.append(peer_id)
		var en_cola = cola_espera.size()
		mutex_cola.unlock()
		print("[Matchmaking] Jugador ", peer_id, " agregado a cola (", en_cola, " en espera)")
		return en_cola
	mutex_cola.unlock()
	return cola_espera.size()

func remover_jugador(peer_id: int):
	mutex_cola.lock()
	cola_espera.erase(peer_id)
	mutex_cola.unlock()

func puede_emparejar() -> bool:
	mutex_cola.lock()
	var puede = cola_espera.size() >= JUGADORES_POR_PARTIDA
	mutex_cola.unlock()
	return puede

func obtener_pareja() -> Array:
	# Retorna [j1, j2] o array vacío si no hay suficientes jugadores
	mutex_cola.lock()
	
	if cola_espera.size() < JUGADORES_POR_PARTIDA:
		mutex_cola.unlock()
		return []
	
	var j1 = cola_espera.pop_front()
	var j2 = cola_espera.pop_front()
	mutex_cola.unlock()
	
	return [j1, j2]

func reintegrar_pareja(j1: int, j2: int):
	# Vuelve a poner jugadores en la cola si falla el emparejamiento
	mutex_cola.lock()
	cola_espera.push_front(j2)
	cola_espera.push_front(j1)
	mutex_cola.unlock()
	print("[Matchmaking] Pareja ", j1, "/", j2, " reintegrada a la cola")

func obtener_cantidad_en_cola() -> int:
	mutex_cola.lock()
	var cantidad = cola_espera.size()
	mutex_cola.unlock()
	return cantidad
