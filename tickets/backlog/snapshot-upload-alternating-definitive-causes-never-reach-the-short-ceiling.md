---
id: snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling
status: backlog
priority: high
area: "modo-nube, migración"
created: 2026-09-23
updated: 2026-09-23
source: "medición de `alternating-definitive-causes-never-reach-the-short-ceiling` (2026-09-23): el mismo agujero, en la ida"
---

# Al subir a la nube, con dos motivos definitivos turnándose, la subida espera tres días en vez de quince minutos

## El problema, en lenguaje de usuario

La subida del snapshot («Migrar a la nube», la barra que avanza con las páginas) promete rendirse a los **15
minutos** cuando el motivo es de los que no se arreglan esperando. Si se dan dos de esos motivos a la vez y se
turnan —una cuenta congelada o suspendida **y** un teléfono cuyo store falla a ratos—, ese plazo no vence nunca y la
salida llega a las **72 horas**. Mientras tanto la persona ve la barra quieta. Es el agujero que
`alternating-definitive-causes-never-reach-the-short-ceiling` cerró en la vuelta a iCloud.

## Por qué pasa (leído en el código el 2026-09-23, árbol `6d225f6f`)

- El techo corto de `uploadingSnapshot` se mide con `CauseStallClock` por causa (`MigrationRunner.observeSnapshotStall`),
  y la regla «causa distinta ⇒ lo acumulado se tira» lo reinicia en cada cambio de motivo. Su docblock lo admite
  (`MigrationPolicy.snapshotProgressBudgetSeconds`: «con dos causas definitivas alternándose el reloj corto se
  reinicia en cada cambio, y lo único que garantiza que la espera termine es éste»).
- **Es alcanzable**: hay una observación por pasada (`driveUpload` devuelve `false` tras observar), y los
  productores de `localFailure` de `MigrationSnapshotUploader` (`nextPage`, `enqueueSnapshotRows`, `drainOnce`, el
  `fetch` del outbox) saltan ANTES del push, mientras que `accountUnavailable` (403 o el 409 `yala_account_reverting`)
  sale DEL push. Una pasada falla al leer, la siguiente lee bien y el push da 403: el motivo cambia en cada pasada.
  Con la sesión borrada, `sessionExpired` + `localFailure` hace lo mismo.
- **Lo que es inferencia**: la frecuencia real de «un store que falla a ratos». Nadie la ha medido; el canario
  `cloudSnapshotUploadWaiting` publica `<tramo avance>|<tramo causa>|<causa>` y la alternancia se vería como avance
  creciendo con la causa siempre en el tramo bajo.

## En la ida sin cifra (22 %, 35 %, 80 %) se midió y NO es alcanzable de forma sostenida

El claim tiene dos productores, pero el 403 no se emite hoy y exige sesión viva, lo contrario de `sessionExpired`;
`assigningIdentity` tiene uno solo; `cutover(.pending)` puede cambiar de motivo una vez (`otherDevice` → `refused`),
lo que retrasa la salida unos 15 min, no 72 h. Por eso este ticket es solo de la subida.

## Qué haría falta

Lo mismo que en la vuelta: un tercer reloj de «cualquier motivo definitivo» (`CauseStallClock` con una sola clave,
dos campos aditivos en `MigrationState` y subida de schema), con la máquina decidiendo el corto contra él y el reloj
por causa eligiendo el copy (`snapshotExitReasonRaw`). La regla de área, punto (1) de las fases previas al montaje,
tiene el razonamiento entero.

## Criterios de aceptación

- [ ] Dos motivos definitivos turnándose en la subida salen a los 15 min acumulados, no a las 72 h.
- [ ] Un `localFailure` aislado tras horas sin red sigue sin cobrar esas horas.
- [ ] El copy de la salida no afirma un motivo que no llegó solo al plazo.

## Relacionado

- `alternating-definitive-causes-never-reach-the-short-ceiling` — el mismo arreglo, en la vuelta.
- `snapshot-upload-has-no-ceiling-and-no-way-out` — el que puso los dos relojes de la subida.
