# Tope en el servidor: un teléfono con la hora adelantada ya no gana todos los conflictos (personal y grupos)

## Contexto
Cola autónoma bypass de Yala (rama `2.1`). Sale tras el PR #381 (cerrar la sesión privada tras una migración fallida), que está en cola de auto-merge. Tarjeta del board `tablero-decidir-un-telefono-con-la-hora-adelanta-4nvh`.

Tickets (léelos enteros, son la fuente):
- `tickets/backlog/personal-clock-ahead-wins-every-conflict-until-real-time-catches-up.md`
- `tickets/backlog/groups-clock-ahead-wins-every-conflict-until-real-time-catches-up.md`

En lenguaje de usuario: si alguien adelanta la hora de su iPhone y la devuelve, mientras la hora real no lo alcanza todo lo que cambie ese teléfono gana los conflictos, en sus datos de la nube y en sus grupos. Lo que edita otro dispositivo u otro miembro desaparece sin aviso, y el otro dispositivo puede quedarse divergente.

## Decisión de Jürgen (2026-10-04)
**A. Tope en el servidor.** Un teléfono con la hora adelantada no gana todos los conflictos. Los detalles finos (rechazar o recortar, cuánto margen sobre `now()`, cómo conserva el teléfono el orden de sus propios cambios) los decides tú en un Paso 0 escrito en el encargo, con la opción más robusta y medida en el código, sin despertar a Jürgen. Prefiere lo que no pierda datos ni deje filas atascadas en dead-letter. Los tickets listan las preguntas abiertas: contéstalas en ese Paso 0.

MODO AUTÓNOMO HASTA TERMINAR: Paso 0, implementación, review adversarial, gate, commit, PR a `2.1`, board y `docs/TICKETS.md`, `/cerrar-total`. Bugs nuevos van a ticket `--solo-crear`. Lo que solo se pueda probar con dos teléfonos reales va a `tickets/qa/`.

## Servidor y producción (es de noche en Lima)
La migración SQL vive en el repo y se prueba en local o en una rama/staging de Supabase. **No apliques nada a la base de producción** ni despliegues funciones a producción. Si para cerrar hace falta tocar producción, deja la migración lista en el PR y escribe en «Necesita de ti» el paso exacto para Jürgen por la mañana. Si el RPC personal no está en el repo, dilo y mídelo desde staging, sin inventarlo.

## Que se pide
1. Paso 0 con el árbol de decisiones medido (coordenadas actuales, no las del ticket).
2. Tope en el servidor para el canal personal y el de grupos, con el cliente adaptado a lo que el servidor devuelva.
3. Tests del tope y de los casos de los tickets (incluido el otro dispositivo divergente). PR a `2.1`.

## Que NO hay que tocar
`marketing/`. La base y las funciones de producción. Otras sesiones o worktrees.

## Mac Mini: pipeline serial y limpieza
Pipeline serial: (1) limpiar sims muertos, basura previa, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; (2) build con `xcodebuild -jobs 2` sin simulador encendido; (3) encender 1 simulador; (4) tests; (5) apagar y borrar ese simulador. Prohibido solapar swift-frontend, SpringBoard, app y UITests.

Gate después del CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR #381 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

Al lanzar y al cerrar borra tú el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin pedir aprobación. No toques las de un worktree vivo. Si el borrado falla, dilo en el cierre.

Al cerrar: simulador apagado y borrado, worktree retirado si ya no hace falta, Mini lo más limpia posible. Si creas algún secreto en el Llavero, dilo en el cierre. Si hay cambio visible, deja `antes.png` y `despues.png` en `capturas/` y lista las rutas; si no lo hay, no inventes capturas.

No lances la siguiente sesión: Frank encadena.

## Como se sabe que esta bien
Criterios de los dos tickets cumplidos; tests verdes en el gate; PR a `2.1` en cola de auto-merge; tickets movidos; `/cerrar-total` hecho.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, de noche). Se discuten en el PR.

**Hechos medidos antes de decidir** (árbol en `0a5ad85c6`; staging por REST con el usuario de test A el 2026-10-07
hacia las 06:18 UTC, fila desechable `tags` y key `zz_hlc_probe_20261007`):

- **El backend personal no pone tope a un HLC futuro.** `apply_delta` aceptó un upsert con HLC +10 min
  (`applied`); el de «ahora» salió `noop/all_units_stale`, un tombstone de ahora `stale_tombstone`, y un upsert sobre
  un tombstone futuro `stale_over_tombstone`. **Ninguno movió `server_seq`** (3475 antes y después): la fila perdedora no
  se vuelve a bajar, que es la mitad de la divergencia del ticket. `apply_pref`: igual (`noop/stale`, sin mover
  `server_seq`).
- **El cuerpo de `apply_delta` y `apply_pref` NO está en el repo**, y esta noche no se puede leer: el token de gestión de
  `~/Secrets/yala-supabase-mgmt/pat` da 401 en los dos proyectos y el conector Supabase de Claude pide OAuth. La firma sí
  se midió por errores de tipo: `apply_delta(p_entity, p_sync_id uuid, p_op, p_fields, p_field_hlcs, p_row_hlc,
  p_schema_version integer)`.
- **`apply_pref` acepta cualquier texto como HLC**: `'zz'` se aplicó y ahora gana a todo (comparación de texto). Queda
  esa key en staging, de la sonda. Ticket aparte.
- `apply_group_delta` (en `supabase-groups-staging.ddl:970`) compara el HLC entrante como texto con el guardado y escribe
  el entrante tal cual. Las 5 tablas de Grupos y las 17 personales tienen trigger `BEFORE INSERT OR UPDATE` de
  `server_seq`.
- Cliente: el pull personal integra el HLC de cada fila (`SyncApplyEngine.applyPage` → `receiveRemoteClock`, con la
  guarda de 5 min). **El pull de Grupos no integra nada** (`GroupsSyncClient.applyPulledPage`), y el de preferencias
  tampoco (`CloudSyncRuntime.syncPrefsOnce` → `PreferenceSyncService.applyPulledPrefs`; el reloj vive en
  `PrefsOutbox.lastIssuedHLC`).
- El apply de Grupos no tiene guarda de pendientes: pisa lo local con lo que baja. Cada fila re-bajada entra en
  `notify.modifiedExpenses` y acaba en una notificación local de «gasto modificado».
- `SyncCursor.clockLatestHLC` no lo borra ninguna línea que lo nombre: muere con el archivo sync-meta entero, que el
  cierre de sesión borra (`CloudSessionSignOut.swift:13-19`). El Merkle canal 1 no lleva HLC
  (`SyncMerkle.swift:12`), así que recortar el HLC guardado no descuadra la verificación.

**D1. ¿Rechazar o recortar?** → **Recortar**, nunca rechazar. Rechazar devuelve al teléfono adelantado al atasco de
`*-clock-rollback-wedges-the-drain-forever`, ahora con dead-letters. Recortar no pierde el valor: el cambio entra y solo
su HLC queda acotado.

**D2. ¿Dónde se recorta?** → **En un trigger `BEFORE INSERT OR UPDATE` en las 22 tablas sincronizadas** (17 personales
+ 5 de Grupos), no dentro de los RPC. Tres razones medidas: el cuerpo de `apply_delta`/`apply_pref` no se puede leer esta
noche y no se reescribe a ciegas; el trigger alcanza también a quien escribe por `PATCH` directo (las columnas de HLC
tienen grant de UPDATE en las tablas de Grupos, `supabase-groups-staging.ddl:916-940`); y no cambia ninguna respuesta,
así que el cliente viejo sigue funcionando igual. El RPC decide con el HLC entrante y el trigger guarda
`least(entrante, now() + margen)`. Como todo lo guardado ya cumple `≤ hora de su escritura + margen`, decidir con el
entrante y guardar recortado da el mismo ganador que recortar antes de comparar.

**D3. ¿Qué valor se guarda?** → `least(hlc, <now()+margen>-<contador entrante>-<nodo entrante>)`: el instante se acota y
se conservan contador y nodo. Acotar a `now() + margen` (y no a `now()`) es lo que lo hace **monótono**: un teléfono que
cruza el umbral entre dos cambios no ve su segundo cambio guardado por debajo del primero. Un valor mal formado que
ordene por encima del tope se guarda como `<tope>-0000-0000000000000000`.

**D4. ¿Cuánto margen?** → **60 segundos.** Por encima de la deriva de un iPhone con hora automática (segundos), y por
debajo de la guarda de 5 min con la que los otros teléfonos integran lo que bajan: con 60 s, cualquier HLC guardado se
puede integrar aunque el receptor vaya hasta 4 min atrasado. El teléfono adelantado gana como mucho durante un minuto, y
solo a lo que se escriba en ese minuto.

**D5. ¿Cómo conserva el teléfono el orden de sus propios cambios?** → `sendLocal` sigue al reloj lógico adelantado y
no se toca. El servidor compara con ese HLC sin recortar, así que el segundo cambio del teléfono gana al primero aunque
los dos se guarden recortados, **siempre que llegue después**. *Corregido tras la review:* Grupos subía por `createdAt`
(hora de drenado), que se invierte justo cuando la hora vuelve; los dos clientes suben ahora en orden de HLC. El
reintento de un fallo parcial queda con ticket (`clock-ahead-retried-older-change-beats-the-newer-one`). Frente a los
demás cuenta el orden de llegada.

**D6. Lo ya guardado con HLC futuro** → la migración lo normaliza: tras crear los triggers, re-escribe (`set hlc = hlc`)
las filas con algún HLC por encima del tope y el trigger las recorta. Mueve su `server_seq`, así que los teléfonos las
vuelven a bajar una vez. Solo toca metadatos de HLC, nunca valores.

**D7. ¿El otro dispositivo divergente?** → Lo cierra el tope **más** que los tres pulls integren el HLC que bajan.
La divergencia exige que B vea la fila y luego estampe por debajo de ella. Con el tope, lo guardado nunca pasa de
`now()+60 s`, así que B lo integra y su edición siguiente gana. Personal ya integraba (y fallaba por la deriva); Grupos y
preferencias pasan a integrar con la misma guarda de 5 min. Si B edita **sin** haber visto la fila, pierde contra un
cambio más nuevo y su pull siguiente le baja el ganador, que es la convergencia de siempre.
Se descartó que el servidor «toque» la fila perdedora para forzar la re-bajada: en Grupos cada re-bajada notifica
«gasto modificado» a todos los miembros, y en el canal personal exigiría reescribir un RPC que no se puede leer.

**D8. ¿Que el pull de Grupos haga avanzar el reloj?** (pregunta del ticket de Grupos) → **Sí, con guarda de deriva**, no
sin ella. Sin guarda, un cliente nuevo frente a un servidor sin la migración aplicada copiaría el adelanto de otro
miembro. Con guarda y con el tope aplicado, todo lo que baja pasa. Tras un cierre de sesión, el reloj se reconstruye con
el pull, que vuelve a bajar todo.

**D9. ¿Silenciar el canario de `receive` cuando la deriva es propia?** → **Sí.** Si el HLC remoto no supera al reloj
propio, integrarlo no cambia el orden (`sendLocal` ya emite por encima): se salta sin canario. El canario queda para un
remoto de verdad adelantado.

**D10. ¿Avisar a quien pierde un conflicto por `noop`?** → **No.** Perder contra un cambio más nuevo es el contrato LWW.
Lo que no puede pasar es seguir mostrando un valor que el servidor no tiene, y eso lo cierra D7.

**D11. ¿Qué borra `SyncCursor.clockLatestHLC`?** → Medido arriba: el borrado del archivo sync-meta al cerrar sesión. El
reloj en memoria del motor puede sobrevivir al cierre sin relanzar. Con el tope, ese adelanto heredado ya no da ventaja.
No se toca.

**D12. Producción y staging.** → No se aplica nada: no hay credencial de escritura esta noche, y producción es de
Jürgen. La migración se prueba en un Postgres local con el DDL real de Grupos y las tablas personales, y queda en el PR
con su sonda de staging. Orden para Jürgen: staging → sonda → producción. El cliente es compatible en los dos sentidos:
sin la migración se comporta como hoy, y con ella mejora.

**Asumido:** el nombre de la migración es `qa/cloud/hlc01_cap_future_hlc.sql` (toca los dos canales, así que no lleva
prefijo `g`/`i`).
