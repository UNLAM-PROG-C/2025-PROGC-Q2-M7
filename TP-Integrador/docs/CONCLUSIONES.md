# Conclusiones

## Dificultades principales (concretas)

- Estado en servidor vs. cliente: mantener turnos, puntajes y comparación de cartas sólo en servidor para evitar desincronización.
- Diseño de RPCs: definir parámetros mínimos y orden de eventos claro (solicitud → pendiente → respuesta → actualización).
- Desconexiones: limpiar cola/sala y notificar al rival sin dejar estados colgados.
- Apuestas de Truco: manejar "pendiente/aceptado/rechazado" sin permitir cantos simultáneos.

## Qué funcionó bien

- Autoload de red (`Red.gd`) centralizando RPCs.
- Servidor autoritativo con lógica en `Sala.gd`.
- Jerarquía de cartas y comparación simple en `ValorCartas.gd`.

## Próximos pasos

- Envido (simple/real/falta) con “quiero / no quiero”.
- Unificar cantos en una máquina de estados.
- Mejorar feedback de UI (historial y estado visible del Truco).

## Cierre

El objetivo de “hacerlo andar y que se entienda” se cumplió: las partidas fluyen, los cantos de Truco se resuelven y el servidor lleva la batuta. Falta sumar Envido y pulir la UX, pero la base es sólida para iterar sin romper todo.
