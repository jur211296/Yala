# El borrado de iCloud de la puerta privada ya no deja a la persona en un spinner eterno

## Contexto
Cola A autónoma (riesgo real · wipe / onboarding): usuario atrapado sin salida. Ticket `tickets/backlog/private-gate-remote-wipe-can-strand-its-arm.md` (medium). Residual de la review de `groups-only-private-restart-skips-the-wipe-alert` (lente de camino F2).

En «Es mi primera vez → privado», si la puerta encuentra datos en iCloud y la persona confirma el borrado, `WelcomePrivateICloudGateView.wipe()` (camino iCloud, no el del teléfono) tiene un `guard !Task.isCancelled else { return }` **después** de `await performWipe()`. Cuando el wipe local borra `hasCompletedOnboarding`, el `onChange` de `ContentView` puede cancelar el `.task(id: phase)` con el borrado ya committeado: el arm `icloudCorpusWipeArmed` queda puesto, `onProceed()` no corre y la fase se queda en `.wiping` — spinner eterno sobre datos que ya no están. Se auto-cura en dos arranques, pero la sesión en curso es un callejón.

Es el gemelo del defecto ya corregido en `wipeDevice` (mismo día): un borrado consumado tiene que terminar su trabajo. El camino iCloud no puede perder el guard a secas (sí puede cancelarse legítimamente mientras habla con CloudKit). Corte natural del ticket: distinguir «cancelado ANTES de tocar nada» (vuelve) de «cancelado DESPUÉS de borrar» (termina). `performWipe` ya devuelve veredicto; el llamador tiene que saber si llegó a escribir.

Rama base: `2.1` (lleva #275). Device-QA opcional del cierre anterior (E2 / D7) NO pausa este lanzamiento.

Horario Lima nocturno (21:00–6:00; ahora ~04:25): elige la opción robusta / recomendada sin AskUserQuestion. Solo aparca en ticket propio si la decisión es demasiado irreversible para asumirla.

## Que se pide
- Que un wipe de iCloud de la puerta privada consumado termine su trabajo aunque el `.task` se cancele después: arm cerrado / `onProceed` / salida de `.wiping` según el criterio del ticket.
- Distinguir cancelación previa (sin tocar) de cancelación posterior al borrado; no quitar el guard a ciegas.
- Tests del orden (source-scan / mutante que reintroduzca el guard post-wipe) + controles del camino sano.
- Hallazgo residual → ticket propio.
- Mover el ticket en `tickets/` y actualizar `docs/TICKETS.md`.
- Gate, mutantes del área, review adversarial de tres lentes, PR a `2.1`, merge cuando CI verde, board al día, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Implementa de punta a punta sin pedir «¿Sigo?» ni parar por la regla de «>3 files → wait for approval». La lista de ficheros es una nota, no un gate. Sigue hasta gate / commit / PR / merge a `2.1` / board / `/cerrar-total`. No dejes el PR abierto «para que Jürgen mire». No preguntes por continuar tras el plan.

Norma día/noche (vigente): entre 06:00–21:00 Lima, AskUserQuestion solo si hay decisión real de producto o acceso; de 21:00–6:00 Lima decide lo recomendado/robusto sin AskUserQuestion y solo aparca si es demasiado consequential para asumir.

## Que NO hay que tocar
- marketing/, store, tags, releases.
- clinicas-dentales-bi ni datos de salud.
- No relanzar encargos [EN CURSO].
- No ampliar a `private-gate-wipe-failure-copy-claims-icloud-is-intact` (hermano de copy; ticket propio) ni a `late-icloud-wipe-can-re-export-between-its-two-halves` (espera pieza del rediseño de sesiones) ni a Cola B / rediseño UI.
- No reabrir el molde de pendientes de #275 ni el cierre con migración de #274 salvo un predicado imprescindible compartido.
- No prod Supabase.

## Como se sabe que esta bien
- Criterios del ticket: wipe iCloud consumado + cancelación del task no deja `.wiping` eterno ni arm huérfano sin salida; cancelación antes de tocar sigue abortando limpio.
- Gate verde del área; mutantes del cambio cazados o justificados.
- Review adversarial sin altos/medios abiertos sobre el diff (o con ticket).
- PR mergeado a `2.1`, ticket fuera de backlog, `docs/TICKETS.md` al día, `/cerrar-total` limpio.

## Paso 0

Decidido en la sesión (noche Lima, autocontestado):

1. **Qué es «llegó a escribir».** `failure == nil` (todo camino con `nil` cruzó la zona) o la marca durable
   `isICloudCorpusWipeZoneDone()`, que escribe quien cruza la zona con el arm puesto. No se deduce del motivo del fallo.
   Los tres montajes de la puerta pasan por `performICloudCorpusWipe`, así que la marca vale para todos.
2. **Tabla tras `await performWipe()`:** sin cancelación → como hoy. Cancelado + éxito → termina (prefs residuales,
   desarma, `onProceed`), gemelo de `wipeDevice`. Cancelado + fallo con la zona ya ida → enseña el fallo (solo `@State`,
   sin efectos). Cancelado + fallo sin tocar → vuelve sin hacer nada (arm puesto: kill-safety de siempre).
3. **Forma:** decisión pura en `WelcomePrivateICloudGateLogic` + un `guard` que la consulta; se conserva el
   `guard failure == nil` que fijan los tests existentes.
4. **Fuera:** el copy del fallo (`private-gate-wipe-failure-copy-claims-icloud-is-intact`), la re-exportación entre
   mitades y el mismo `guard` en `LateICloudMirrorNoticeView` → ticket propio si se confirma.
5. Ficheros: `WelcomePrivateICloudGateLogic.swift`, `WelcomePrivateICloudGateView.swift`,
   `WelcomePrivateICloudGateTests.swift`, `qa/coverage-index.json`, ticket + `docs/TICKETS.md`.
