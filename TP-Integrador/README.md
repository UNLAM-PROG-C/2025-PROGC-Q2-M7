# TP-ProgConcurrente

Proyecto de Truco online construido con Godot, arquitectura cliente-servidor usando ENet y RPCs. Incluye un servidor multisala que empareja jugadores y coordina partidas, y un cliente con UI para jugar cartas y realizar cantos de Truco.

## Características
- Juego de Truco con baraja española (40 cartas).
- Arquitectura cliente-servidor sobre `ENetMultiplayerPeer` (UDP con fiabilidad configurable).
- Servidor multisala: empareja jugadores, gestiona turnos y resultados por sala.
- Flujo de juego básico: reparto de manos, turnos alternos, comparación de cartas y puntaje.
- Apuestas de Truco: Truco, Retruco, Vale Cuatro con “quiero / no quiero”.
- Manejo de desconexión del rival.

## Estructura del Proyecto
- `scripts/` lógica general
  - `Global.gd`: estado compartido de cliente (mano propia, mano rival, turno).
  - `Red.gd`: autoload de red. Define RPCs cliente<->servidor.
  - `juego/`
    - `Mazo.gd`: generación y barajado de mazo; reparto de manos.
    - `Sala.gd`: lógica de una sala (partida): turnos, comparación de cartas, puntaje y apuestas de Truco.
    - `ValorCartas.gd`: jerarquía de cartas y comparación (Truco argentino).
- `scenes/` interfaz y nodos de servidor/cliente
  - `cliente/` (`Bienvenida.tscn`, `EsperandoRival.tscn`, `MesaJuego.tscn`): UI de juego.
  - `common/` (`Carta.tscn`): presentación de cartas.
  - `servidor/` (`ServerManager.tscn`): servidor multisala con arquitectura modular (ServerManager.gd, RoomPool.gd, Matchmaking.gd).
  - `menu/` (`MenuInicial.tscn`, `MenuInicial.gd`): arranque de servidor/cliente.

## Requisitos
- Godot (4.x recomendado).
- Windows (probado) o cualquier SO soportado por Godot.

## Cómo Ejecutar
1. Abrir el proyecto en Godot (`project.godot`).
2. Desde `MenuInicial`:
   - Iniciar **Servidor**: crea el servidor multisala y queda escuchando en `puerto 7777`.
   - Iniciar **Cliente**: se conecta a `127.0.0.1:7777` por defecto.
3. En el cliente:
   - Ingresar y marcar “Listo” (escena Bienvenida) para entrar a la cola de emparejamiento.
   - Al haber dos clientes listos, el servidor inicia la partida y ambos pasan a `MesaJuego`.

Opcionalmente, puedes lanzar dos instancias del juego (dos clientes) en la misma máquina.

## Flujo de Juego
- Reparto: cada jugador recibe 3 cartas (`Mazo.gd`).
- Turnos: el servidor notifica el `peer_id` que tiene el turno y los clientes habilitan/deshabilitan su mano.
- Jugar carta: el cliente envía la carta al servidor; éste valida turno, notifica a ambos y compara cuando hay dos cartas en mesa.
- Bazas: se cuentan manos ganadas y se determina el ganador de la mano (2 de 3, con reglas de parda).
- Puntaje: se suma al ganador según `valor_truco_actual` (1 por defecto; 2/3/4 si se aceptó Truco/Retruco/Vale Cuatro).

## Apuestas de Truco
- `solicitar_apuesta_truco(nivel)`: 2=Truco, 3=Retruco, 4=Vale Cuatro.
- `apuesta_truco_pendiente`: servidor avisa al rival que debe responder.
- `respuesta_apuesta_truco(acepta)`: si acepta, sube `valor_truco_actual`; si no, el cantor suma `nivel-1` puntos y la mano termina.

## Mensajería (RPCs)
Cliente → Servidor:
- `solicitar_jugar_carta(Vector2 palo, numero)`
- `solicitar_apuesta_truco(int nivel)`
- `respuesta_apuesta_truco(bool acepta)`
- `jugador_listo()`
- `jugador_listo_nueva_mano()`
- `jugador_se_fue_al_mazo()`
- `cantar_truco()` (ruta antigua)

Servidor → Clientes:
- `iniciar_partida_cliente()`
- `recibir_mano(Array mi_mano, Array mano_rival)`
- `actualizar_turno(int peer_id_turno)`
- `carta_jugada(int peer_id, Vector2 carta)`
- `apuesta_truco_pendiente(int nivel, int cantor_peer)`
- `estado_truco_actualizado(int valor_truco)`
- `mostrar_resultado_mano(bool ganaste, int puntos_propios, int puntos_rival)`
- `rival_desconectado()`

Tipos enviados: `int`, `bool`, `Array`, `Vector2`. La serialización es automática de Godot.

## Concurrencia y Sincronización
- **Concurrencia de eventos**: Godot procesa señales y RPCs en el bucle principal; múltiples clientes pueden ser atendidos intercaladamente.
- **Paralelismo**: actualmente NO. `RoomPool.gd` y `Matchmaking.gd` declaran estructuras para un pool de hilos, pero no se crean `Thread`s.
- **Mutexes**: usados preventivamente para proteger estructuras compartidas (`Sala.gd`, `RoomPool.gd`, `Matchmaking.gd`). Hoy no son estrictamente necesarios sin multihilo real.

## Desarrollo
- Código en GDScript, con autoloads `NetworkManager`, `ServerRPCHandler`, `ClientRPCHandler` y `Global`.
- `ValorCartas.gd` contiene jerarquía y comparación de cartas del Truco argentino.
- UI desacoplada de red y lógica mediante RPCs y estados en `Global.gd`.
- Arquitectura modular: NetworkManager (conexiones), ServerManager (orquestación), RoomPool (gestión de salas), Matchmaking (emparejamiento).

## Próximas Mejoras (sugeridas)
- Envido (Envido/Real Envido/Falta) con “quiero / no quiero”.
- Unificar el flujo de apuestas (evitar camino alternativo `cantar_truco`).
- Implementar paralelismo real para tareas CPU intensivas seguras (no manipular el árbol de escenas fuera del main thread).
- Mejor feedback de UI (historial de cantos, estado visual del nivel de Truco).

## Troubleshooting
- Si los clientes no conectan, verifica el firewall y que el servidor esté escuchando en `7777`.
- En desarrollo local, inicia servidor y luego dos clientes en la misma máquina.

## Licencia
Proyecto académico/educativo. Uso libre para aprendizaje.

## Manual y Conclusiones
- Manual de Usuario: `docs/MANUAL_USUARIO.md`
- Conclusiones del trabajo: `docs/CONCLUSIONES.md`
