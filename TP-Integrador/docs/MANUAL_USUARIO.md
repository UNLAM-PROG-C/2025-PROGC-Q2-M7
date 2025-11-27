# Manual de Usuario

Este manual explica cómo instalar, ejecutar y utilizar el juego de Truco online incluido en este proyecto.

## Requisitos

- Godot 4.x instalado.
- Conectividad local (para pruebas en la misma máquina) o en red LAN.

## Instalación

1. Descarga o clona el repositorio.
2. Abre `project.godot` con Godot.
3. (Opcional) Si reinstalaste o limpiaste el proyecto, al abrir Godot se regenerará la carpeta `.godot/`.

## Ejecución

- Abre una instancia de Godot y ejecuta el **Servidor**.
- Abre una segunda instancia de Godot y ejecuta el **Cliente**.


## Paso a Paso

1. **Menú Inicial** (`MenuInicial.tscn`):
   - Botón "Servidor": inicia el servidor multisala en puerto `7777`.
   - Botón "Cliente": conecta al servidor en `127.0.0.1:7777` (localhost). Para otra IP, ajusta en `Red.gd` si hiciste cambios.
2. **Bienvenida** (`Bienvenida.tscn`):
   - Pulsa el botón "Listo". El servidor te agregará a la cola de emparejamiento.
3. **Emparejamiento**:
   - Cuando haya dos jugadores listos, el servidor los asigna a una sala y ambos pasan a **Mesa de Juego**.
4. **Mesa de Juego** (`MesaJuego.tscn`):
   - Verás tu mano (3 cartas) y el dorso del rival.
   - El label de turno indica si es tu turno. Si es tu turno, tus cartas se habilitan: haz clic en una para jugarla.
   - Se mostrará la carta jugada en el centro y se irá resolviendo la baza cuando ambos jueguen.
   - Puntajes se actualizan al finalizar cada mano.
   - Botones:
     - "Cantar Truco": envía propuesta de truco (sube el valor de la mano). El rival verá "¿Quiero?" y podrá aceptar o rechazar.
     - "Quiero / No Quiero": responden a un canto de truco pendiente.
     - "Irse al Mazo": rendirse (el rival gana 1 punto) y se reinicia la mano.
     - "Volver a Jugar": tras mostrar resultado de mano, oculta el panel y notifica al servidor que estás listo para una nueva mano.
5. **Desconexión**:
   - Si el rival se desconecta, el cliente mostrará aviso y volverá al menú.

## Consejos de Juego

- Guarda cartas altas para segundas/terceras bazas si tu mano lo permite.
- Usa el Truco para presionar cuando sientas ventaja o para bluff cuando el rival muestra debilidad.

## Problemas Frecuentes

- **Cliente no conecta**: valida firewall/puerto `7777`, que el servidor esté corriendo, y la IP correcta.
- **No se habilitan cartas**: asegúrate de que el turno te pertenece (label "¡ES TU TURNO!").
- **No se ven cartas**: verifica rutas de imágenes en `assets/cartas` y que Godot regeneró `.godot/`.
