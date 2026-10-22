---
id: trends-insight-title-capitalizes-the-period-mid-sentence
status: backlog
priority: low
area: stats
created: 2026-10-03
updated: 2026-10-08
source: hallazgo de trends-insight-card-v2-bullets (simulador, 2026-10-03)
---

# El título del resumen de Tendencias pone el período con mayúscula en mitad de la frase

En la tarjeta de resumen del final de Tendencias (versión gratis) el título sale «Tu Mes pasado en
pocas palabras» / «Tu Todo el tiempo en pocas palabras». La clave es
`stats.trends.insightTitleFree %@` = «Tu %@ en pocas palabras», y el `%@` es
`DetailPeriod.displayName`, que es el rótulo del selector («Mes pasado», «Todo el tiempo»), pensado
para ir solo.

Medido en el simulador el 2026-10-03 (captura en `capturas/` del PR de
`trends-insight-card-v2-bullets`). Existía antes de ese cambio, que no lo toca.

Pide copy nuevo (una frase que no necesite meter el rótulo, o un rótulo propio en minúscula por
idioma): decisión de copy, no se inventa.

## Medido en 2.1 (triage 2026-10-08)

- `stats.trends.insightTitleFree %@` sigue siendo «Tu %@ en pocas palabras» y `TrendsTabView` le pasa `periodDisplayName`.
- Misma forma en Categorías: `stats.distribution.insightTitleFree %@` = «Tu %@ de un vistazo», que `CategoriesTabView` pinta igual. El arreglo de copy debería cubrir los dos.

Triage 2026-10-08: abierto · low → low · sigue igual y además en la tarjeta de Categorías; es copy que ve todo usuario gratis, sin efecto sobre sus datos.
