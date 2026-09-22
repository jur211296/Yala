# reverse-verify-network-bucket-hides-a-definitive-server-no — un 403/401 del Merkle en la vuelta a iCloud ya no se lee como «sin red» ni espera 72 h

## Contexto
Cola A autónoma (restore / callejones de nube). Acaba de mergear a 2.1 el PR #208 (discard-gate apaga ventana huérfana). Este ticket es residual medido de `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`: SyncMerkle aplana 401/403/transient a `fetch-failed` → VerifyProbeMapping → `.networkTimeout` → techo LARGO 72 h. El usuario se queda en «Comprobando que todo llegó…» tres días ante un «no» definitivo del servidor.

Ticket: `tickets/backlog/reverse-verify-network-bucket-hides-a-definitive-server-no.md` (medium). Rama base 2.1.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge a 2.1 y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) antes de cerrar. Solo parar ante decisión/acceso real que no puedas asumir. Board de producto Yala = `tickets/` + `docs/TICKETS.md` (no inbox Tim).

## NOCTURNO (America/Lima, antes de las 6:00)
NO uses AskUserQuestion. Elige lo recomendado y sigue. Si algo es demasiado grave para asumir, aparca con ticket propio y cierra el alcance que sí puedas.

## Decisiones de producto YA TOMADAS (noche Frank, 2026-09-22)
1. **Dónde se tipa:** `SyncMerkle` deja de aplanar: propaga `.sessionExpired` / `.accountUnavailable` como hacen push y pull.
2. **IDA:** el comportamiento de la ida **no cambia** en este ticket. Si el tipado llega a consumidores de la ida, mantén el agrupado actual (red/sesión/blocked) con adaptador/tests que lo fijen; el ticket hermano `forward-verify-reads-an-expired-session-as-network` sigue aparte.
3. **Fallos LOCALES** (`outbox-fetch-failed`, `quarantine-fetch-failed`): techo **CORTO** + desenlace visible (no 72 h silenciosas). No inventes un terminal nuevo si ya hay uno reutilizable.
4. **`default` de reason desconocido:** techo **CORTO** (fail visible > esperar tres días).
5. **401 solo visto por Merkle en la vuelta:** debe encender el aviso de «vuelve a entrar» de la vuelta (`lastReverseSessionExpiry` / rama `.sessionExpired` de `driveReverseVerify`).
6. **403 solo visto por Merkle en la vuelta:** techo CORTO o el terminal de cuenta no disponible que ya exista en la vuelta — nunca el presupuesto largo de red.

## Qué se pide
- Cerrar el ticket según AC del fichero + las decisiones de arriba.
- Medir la cadena entera (Merkle → mapping → driveReverseVerify) antes de tocar; no arreglar solo el mapping si el aplanado sigue aguas arriba.
- Tests + mutantes del tramo tocado; gate completo del repo.
- Mover ticket a `qa` (o `done` si no hace falta device-QA) con guion si aplica; actualizar `docs/TICKETS.md` y `docs/ESTADO.md`.
- Abrir PR a 2.1, mergear cuando CI OK (UI tests advisory), `/cerrar-total`.

## Qué NO hay que tocar
- `marketing/`
- Comportamiento de la IDA (solo fijarlo).
- Relanzar tickets ya en `qa/` del pack restore.
- Secrets en git.

## Como se sabe que esta bien
- AC del ticket + decisiones 1–6 cumplidos y medidos.
- Un 403/401 que solo ve el Merkle ya no cae en techo 72 h ni en silencio eterno.
- Gate verde; PR mergeado a 2.1; board/índice al día; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo que vas a reclasificar, build que vas a reintentar, ni ruido de CI advisory.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

El encargo llegó con seis decisiones de producto ya tomadas por Jürgen (noche del 22-sep). Lo que sigue es su
resolución medida contra la cadena real, más las que la review obligó a reabrir. El texto largo, con su porqué, vive
en el ticket `tickets/qa/reverse-verify-network-bucket-hides-a-definitive-server-no.md`, sección `## Paso 0`.

1. **Dónde se tipa: en `SyncMerkle`.** `MerkleVerdict` gana `.sessionExpired` y `.accountUnavailable`; el compilador
   obliga a cada consumidor a contestar, cosa que un `reason` string no puede exigir.
2. **La IDA no cambia.** `driveVerify` ya agrupaba `.networkTimeout, .sessionExpired, .blocked`, así que el tipado
   llega y no mueve nada. Fijado con test.
3. **Fallos LOCALES → `.blocked(.localFailure)`**: techo corto (900 s), sin terminal nuevo.
4. **`default` → `.blocked(.unknownVerdict)`**: techo corto. «Conservador» dejó de significar «espera» el día en que
   detrás había 72 h.
5. **El 401 enciende el aviso de «vuelve a entrar»**, y conserva el techo LARGO: a la sesión la renueva la persona.
   Lo que se le quitó fue el silencio, no la espera.
6. **El 403 elige el techo corto** por la vía del `blocked` que ya existía.
7. **Grupos no se toca** (sigue aplanando; su caller solo agrega `.diverged`) y el runtime periódico tampoco (solo
   mira `if case .diverged`).

**Reabiertas por la review adversarial, y decididas aquí:**

8. **El `abortReason` se elige por quién PRODUJO el motivo, no por el techo.** `.unknownVerdict` salía con
   `preMountRefused`, cuyo copy dice «tu cuenta en la nube no lo permitió» y da el correo de soporte — y ese motivo
   lo escribe una función LOCAL. Pasa a `preMountStalled`; el techo corto se queda. La decisión 4 de Jürgen era
   sobre el techo, no sobre el copy: asumí que iban juntos y no van.
9. **El Merkle recibe `canRenewSession` y la rama de `yala_attest_required`.** No estaba en el encargo, y es
   consecuencia directa de la decisión 5: en cuanto su 401 mueve una pantalla, confundir los dos 401 pide firmar a
   quien no le sirve.
10. **El prefijo del canario pasa de `server_` a `stop_`.** Dos de los cinco motivos dejaron de ser la palabra del
    servidor; la serie `cloudReversePreMountWaiting` cambia de valores con este build, y se dice en su docblock.
11. **Los dos residuales de la review van a ticket propio, no a este alcance**: la histéresis del techo
    (`reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`) toca las cuatro fases y las cinco causas,
    y la asimetría del `fetch` local (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`) es anterior a este
    cambio.
