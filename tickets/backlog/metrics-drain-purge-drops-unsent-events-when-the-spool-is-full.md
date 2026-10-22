---
id: metrics-drain-purge-drops-unsent-events-when-the-spool-is-full
status: backlog
priority: low
area: "métricas, canarios"
created: 2026-09-26
updated: 2026-10-08
source: "review adversarial de `prefs-push-purge-drops-a-change-made-during-the-upload` (2026-09-26), lente de gemelos"
---

# Con la cola de métricas llena, un envío borra canarios que nunca salieron

## El problema, en lenguaje de usuario

No lo ve el usuario. Lo ve quien lee el dashboard de canarios del Modo Nube: tras un rato sin red, los canarios que se
emiten justo mientras se vacía la cola pueden perderse sin rastro, y la racha que el gate mira sale más baja de lo real.

## Por qué pasa (leído el 2026-09-26; la carrera, inferida y sin ejecutar)

- `MetricsService.kickDrain` lee los primeros 25 eventos, hace `await client.send` (suelta el main actor) y con
  `.delivered` o `.dropped` purga con `MetricsSpool.removeFirst(batch.count)`: **por posición, no por identidad**.
- El docblock de `removeFirst` dice que es seguro porque «los appends concurrentes van al final». Es verdad salvo con la
  cola en su tope (50): `MetricsSpool.enqueue` recorta por el FRENTE, que es justo lo que está en vuelo.
- Con la cola llena y k eventos encolados durante el envío, el tope retira k de los enviados y la purga corta 25 desde la
  cabeza nueva: se lleva k eventos que no salieron nunca.
- Variante: si el spool no decodifica durante el `await`, `pending()` lo borra entero y la purga se come lo encolado
  después (hasta 25).

## Criterios de aceptación

- [ ] La purga tras el envío retira exactamente los eventos que viajaron (identidad del evento, no posición).
- [ ] Test con la cola en su tope y eventos encolados durante el envío; control sin encolar.

## Notas

- Molde: `PrefsOutbox.removeEntries(pushed:)` (compara la identidad de lo que viajó). `MetricsEvent` puede necesitar un id
  si no lo tiene.

## Medido en 2.1 (triage 2026-10-08)

- Sin cambios: `MetricsService` purga con `MetricsSpool.removeFirst(batch.count, …)` en las ramas `.delivered` y `.dropped`, y `MetricsSpool.enqueue` recorta con `queue.removeFirst(queue.count - capacity)`. Los commits posteriores al fichero añaden canarios (`84c3c3b3e`, `d9462c742`), no tocan la purga.

Triage 2026-10-08: abierto · low → low · `MetricsService.kickDrain` sigue purgando con `MetricsSpool.removeFirst(batch.count)` por posición, y `MetricsSpool.enqueue` sigue recortando por el frente al llegar a `capacity = 50`.
