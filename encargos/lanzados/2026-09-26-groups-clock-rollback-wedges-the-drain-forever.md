# Arreglar groups-clock-rollback-wedges-the-drain-forever: si la hora del iPhone retrocede, los gastos de grupo no suben nunca y las salidas se bloquean con un «inténtalo en un rato» falso

## Contexto
Sale del cierre de PR #257 (groups-drain-failure-reads-as-nothing-pending): Cerrar sesión, desasociar y «Empezar de cero» ahora se paran si queda un gasto de grupo sin subir. Pero si el reloj del iPhone retrocede, el drain de grupos se queda encallado para siempre: los gastos no suben y esas tres salidas quedan bloqueadas con un copy que promete curarse esperando. Es Cola A de riesgo real (usuario atrapado sin salida, pérdida de datos, copy engañosa). El ticket está en backlog en tickets/; léelo primero. Ticket hermano: fresh-start-has-no-way-out-when-group-writes-can-never-upload (decidido: salida destructiva con confirmación y conteo solo cuando la subida sea imposible de forma definitiva) — no lo implementes aquí, pero que el diseño no lo bloquee.

## Qué se pide
Que un retroceso del reloj no encalle el drain de grupos: los gastos pendientes deben poder subir (orden/reloj robusto frente a retrocesos, sin depender de la hora de pared) y, mientras no puedan, el copy debe decir la causa real, no «inténtalo en un rato». Opción robusta y de buena práctica, no la mínima. Tests que reproduzcan el retroceso de reloj.

## Qué NO hay que tocar
No implementar la salida destructiva del ticket hermano. Nada de marketing/. Nada en Supabase prod. No tocar el documento de exploración del plugin de Claude (otra sesión en paralelo, solo docs).

## Cómo se sabe que está bien
Tests verdes que cubren retroceso de reloj con gastos de grupo pendientes: suben tras el retroceso y las salidas ya no quedan bloqueadas por esa causa; el copy nombra la causa real. PR mergeado a 2.1, ticket movido a qa con guion de device-QA, docs/TICKETS.md al día, cierre con /cerrar-total. Residuales nuevos como tickets propios.

MODO AUTÓNOMO: no preguntes «¿Sigo?» ni esperes aprobación por tocar más de 3 ficheros; implementa hasta PR, merge y /cerrar-total. De día (06:00–21:00 Lima) puedes preguntar a Jürgen con AskUserQuestion solo lo de producto o acceso; de noche, elige lo recomendado o aparca.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** El drain de Grupos estampa con `clock.send(now: tx.timestamp)`
(`GroupsSyncClient.appendRow`); la fecha de la transacción no cambia nunca, así que un reloj lógico persistido más de
5 min por delante corta en la misma transacción para siempre. El canal de Grupos no llama nunca a `receive`: el reloj
solo lo adelantan sus propias escrituras. El servidor (`apply_group_delta`, DDL de staging) hace LWW por HLC textual sin
guarda de futuro. La traducción solo puede lanzar desde `clock.send`. El drain personal (`CloudSyncEngine.appendRow`)
tiene el mismo patrón.

**D1 · ¿Cómo se estampa un cambio local cuyo reloj lógico va por delante?** → Primitiva nueva
`HLCClock.sendLocal(eventTime:)`: `l' = max(l, pt)` y contador como `send`, **sin** la guarda de deriva.
Por qué: esa guarda existe para no aceptar un reloj ajeno adelantado; aplicada a un evento propio y viejo solo puede
encallar, porque ni `l` baja ni la fecha de la transacción sube. Sigue estampando con la fecha de la transacción, así que
el re-drain tras un fallo produce los mismos HLC y el dedup `(syncID, hlc, op)` sigue valiendo. Alternativas
descartadas: `max(tx.timestamp, ahora)` rompe ese determinismo (un re-drain duplicaría filas) y además depende de la
hora de pared; estampar con la hora real sin `max` rompe la monotonía del propio teléfono (la edición posterior perdería
por LWW contra la anterior adelantada).

**D2 · ¿Y el desbordamiento del contador?** → En `sendLocal` avanza el milisegundo y pone el contador a 0.
Por qué: con `l` por delante el contador crece con cada cambio hasta que la hora real alcance `l`; con un reloj puesto
meses adelante, 65 536 cambios llegan, y lanzar ahí volvería a encallar. Sigue siendo monótono y determinista.

**D3 · ¿Se toca `send`?** → No. Lo usan el canal personal, las preferencias y el banco de vectores de conformidad.
Por qué: cambiar su contrato arrastra consumidores que tratan la deriva como pasajera a propósito (regla de la subida
del snapshot). Alternativa descartada: quitar la guarda de `send` para todos.

**D4 · ¿Copy nuevo para «la subida está encallada por el reloj»?** → No. Con D1+D2 la traducción ya no se corta por el
reloj: lo único que queda en ese `catch` es un año fuera de 0001–9999, inalcanzable en un iPhone. Las salidas dejan de
bloquearse por esta causa, que es lo que el copy falso anunciaba. Un texto para un estado inalcanzable sería código
muerto. El `catch` y su `false` se quedan (siguen siendo correctos) y se prueban con un seam.

**D5 · ¿Se arregla también el drain personal?** → No en este encargo: ticket propio con lo medido. El encargo acota a
Grupos, y el personal tiene más consumidores de la deriva (migración, snapshot). La primitiva de D1 le sirve tal cual.

**D6 · Coste aceptado.** Un teléfono cuyo reloj estuvo adelantado sigue ganando por LWW, en los campos que toque, hasta
que la hora real alcance su reloj lógico. Ya ganaba con el cambio que hizo adelantado; ahora además sube lo de después
en vez de encallar. Es el comportamiento estándar de un HLC.

**D7 · ¿Ticket hermano `fresh-start-has-no-way-out…`?** → No se toca; nada de lo anterior cambia las salidas.
