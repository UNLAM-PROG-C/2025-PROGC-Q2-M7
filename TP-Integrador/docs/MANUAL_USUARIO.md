# Manual de Usuario - Truco Online

Guía rápida para jugar al Truco multijugador en red.

## Requisitos

- **Godot 4.x** instalado
- Red local (misma PC o LAN)

## Cómo Jugar

### 1. Iniciar el Servidor

1. Abre el proyecto en Godot
2. Presiona **F5** o el botón Play
3. En el menú, clickea **"Servidor"**
4. El servidor queda esperando jugadores en el puerto **7777**

### 2. Conectar Clientes

1. Abre otra instancia del juego (puede ser en la misma PC u otra en la red)
2. Presiona **F5**
3. Clickea **"Cliente"**
4. Se conectará automáticamente al servidor (localhost por defecto)

**Para jugar en LAN:** edita `scripts/client/MenuInicial.gd` línea 26 y cambia `"127.0.0.1"` por la IP del servidor.

### 3. Emparejar y Jugar

1. Ambos clientes verán la pantalla de bienvenida
2. Presionen **"Listo"**
3. El servidor los emparejará automáticamente
4. ¡Comienza la partida!

## Controles de Juego

### Durante tu turno
- **Click en una carta** → la juegas
- **Cantar Truco** → propone subir la apuesta
- **Irse al Mazo** → te rendís (rival gana 1 punto)

### Cuando el rival canta Truco
- **Quiero** → aceptás la apuesta
- **No Quiero** → rechazás (rival gana)

### Después de cada mano
- **Volver a Jugar** → preparado para la siguiente mano

## Reglas Básicas

- Cada jugador recibe **3 cartas**
- Gana quien gane **2 de 3 bazas**
- Primera mano al llegar a **15 puntos**
- El Truco sube el valor de la mano (1 → 2 → 3 → 4 puntos)
- Si te rendís o no querés el Truco, el rival gana los puntos actuales

## Solución de Problemas

**El cliente no conecta:**
- Verificá que el servidor esté ejecutándose
- En Windows, abrí el puerto 7777 UDP en el firewall:
  ```powershell
  New-NetFirewallRule -DisplayName "Godot Truco" -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow
  ```

**Las cartas no se ven:**
- Cerrá y volvé a abrir el proyecto en Godot para regenerar los imports

**Las cartas no se habilitan:**
- Solo podés jugar en tu turno (mirá el label superior)
