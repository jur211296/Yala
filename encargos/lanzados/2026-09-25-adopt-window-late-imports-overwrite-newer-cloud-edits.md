# Tras un adopt, lo que el espejo importa tarde no puede pisar ediciones más nuevas de la nube

## Contexto
Cola A autónoma Yala (riesgo real: overwrite silencioso). Acaba de mergear a 2.1 el PR #253 (`cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`). Ticket: `tickets/backlog/adopt-window-late-imports-overwrite-newer-cloud-edits.md` (medium, modo-nube/migración).

Hora Lima ~23:27 → **nocturno**: elige lo robusto sin AskUserQuestion; si la decisión es demasiado grave para asumirla, aparca el ticket y no inventes.

MODO AUTÓNOMO (norma Jürgen 2026-09-22, override explícito): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan **queda suspendida**. Implementa de punta a punta hasta gate/PR/merge/`/cerrar-total` sin pedir continuar. Solo AskUserQuestion de producto/acceso real entre 06:00–21:00 Lima; de noche no aplica.

## Que se pide
Cierra el ticket: tras un adopt, los inserts del espejo que llegan *después* del `fastForwardHistoryBaseline` no deben re-emitirse con HLC fresco de forma que, por LWW, pisen ediciones más nuevas ya en la nube.

Decisión robusta (elige tú, sin preguntar): preferir no traducir en el primer drain tras adopt los inserts del espejo cuya identidad ya conoce el backend (el pull traerá su versión), frente a acuñar el HLC viejo. Documenta la elección en el PR.

Criterios del ticket + tests que fijen el no-overwrite. Al cerrar: board al día (`tickets/` + `docs/TICKETS.md`), residuales con ticket propio si salen, `/cerrar-total`.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- El hermano `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check` salvo residual medido inevitable
- `adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate` (aparte; no lo mezcles)
- Refactors amplios fuera del adopt/drain/HLC path

## Como se sabe que esta bien
- Un caso de adopt con import tarde del espejo ya no sube filas conocidas por el backend con HLC fresco que puedan ganar a ediciones cloud más nuevas
- Tests (unit/integration del motor) cubren el no-overwrite
- PR mergeado a `2.1`, ticket en done/qa según corresponda, `/cerrar-total` limpio con índice `docs/TICKETS.md` al día

## Paso 0

Sesión nocturna en MODO AUTÓNOMO: decisiones auto-contestadas, sin `AskUserQuestion`.

- **D1 · qué hacer con esas filas.** No traducirlas; el pull trae la versión del backend. Acuñarles «el HLC que tenían» no
  es posible: ese HLC no viaja por CloudKit.
- **D2 · alcance.** Altas, cambios y borrados que el espejo trae de filas que el backend conoce. Un cambio o un borrado con
  HLC fresco pisa igual que un alta.
- **D3 · de dónde sale «conoce».** La enumeración del reconcile del adopt (vivas y borradas), guardada junto al registro del
  adopt, que ya sobrevive al relanzamiento y ya se retira tras el primer drain completo.
- **D4 · autor.** Altas sin mirar la firma del espejo (ningún camino local crea una fila con una identidad del backend en la
  ventana); cambios y borrados solo con ella.
- **D5 · lista ilegible.** Todo como antes, con rastro: la regla del registro.
- **Ficheros (nota, no pregunta).** `CloudSyncEngine`, `MigrationWorkExecutor`, `RelayIdentityLedger`, `MetricsService`, dos
  suites de test, la regla `swiftdata-cloudkit.md`, el ticket, un ticket residual, `docs/TICKETS.md` y `qa/coverage-index.json`.
- **Ticket a `qa`, no a `done`:** el caso real necesita dos iPhone y CloudKit.
