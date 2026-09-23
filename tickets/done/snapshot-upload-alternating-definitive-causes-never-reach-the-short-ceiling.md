---
id: snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling
status: done
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

- [x] Dos motivos definitivos turnándose en la subida salen a los 15 min acumulados, no a las 72 h.
- [x] Un `localFailure` aislado tras horas sin red sigue sin cobrar esas horas.
- [x] El copy de la salida no afirma un motivo que no llegó solo al plazo.

## Relacionado

- `alternating-definitive-causes-never-reach-the-short-ceiling` — el mismo arreglo, en la vuelta.
- `snapshot-upload-has-no-ceiling-and-no-way-out` — el que puso los dos relojes de la subida.

## Resolución (2026-09-23)

**Qué cambia para la persona.** Si al activar la nube el teléfono falla a ratos al leer su base de datos y además la
cuenta está congelada (otro dispositivo la está devolviendo a iCloud) o la sesión se borró, la subida se rinde a los
15 minutos acumulados, no a los tres días. Sale con un texto propio —«la subida de tus datos se atascó por algo que
esperar no iba a arreglar»—, porque ninguno de los dos motivos llegó solo al plazo. Con un solo motivo sostenido todo queda igual: a los 15 minutos, con su texto. Y un fallo
local aislado tras horas sin red sigue sin cobrarse esas horas.

**Cómo.** El molde exacto de la vuelta (`alternating-definitive-causes-never-reach-the-short-ceiling`): un tercer reloj
en el journal, el de «cualquier motivo definitivo» (`snapshotStallDefinitiveAt` + `snapshotStallDefinitiveAccruedSeconds`,
schema **13**). Suma entre motivos distintos, se PAUSA con una observación sin motivo y se reinicia con una página
confirmada o con el cambio de fase (los borra `clearSnapshotStallCeiling()`, como a los otros cuatro). La máquina decide
el corto contra él: el evento `snapshotUploadStalled` trae `definitiveStalledSeconds`. El reloj por causa se queda solo
para el copy (`snapshotExitReason`).

**El texto, decidido por Jürgen a mitad de sesión.** El primer diseño sacaba los motivos mezclados con `stalled`, «el
genérico». Dos lentes de la review cazaron que no lo es: su texto dice «la subida de tus datos **lleva días** sin
avanzar» en los 16 locales, y esta salida llega a los 15 min (en la vuelta el genérico no afirma plazo, y por eso el molde
no lo traía). Jürgen eligió un motivo propio: `SnapshotExitReason.mixedCauses`, con `storage.failed.snapshotMixedCauses`
en los 16 locales, sin motivo ni plazo y sin el correo de soporte. `stalled` queda para las 72 h, donde «días» es
verdad, y el canario `cloudSnapshotUploadAborted` no mezcla los dos casos.

**Una sola implementación.** El reloj de lo definitivo vive en `CauseStallClock.observeAnyDefinitive` y lo llaman la
vuelta y la subida: la regla de área dice «no lo copies a una tercera etapa: llámalo». La función de la vuelta pasó a
delegar en él sin cambiar su comportamiento.

**Consecuencias decididas (las mismas de la vuelta), fijadas con test:** un hueco SIN observaciones entre dos motivos
distintos cuenta; y una fila v12 parada a mitad de la subida sale como mucho un plazo corto después, con el texto
específico, que entonces es verdad.

**El canario de espera** `cloudSnapshotUploadWaiting` no cambia: su segundo segmento sigue siendo el tramo de causa, el que deja
ver la alternancia en la flota.

**Sin device-QA:** el escenario no se monta a voluntad en un iPhone y el cambio es lógica del runner y la máquina,
cubierta por tests contra el store. Va a `done`.

**Tests:** `snapshotDefinitiveClock_alternatingCauses_leaveAtTheShortCeiling` (fallo local y 409 turnándose cada 30 s:
899 s holdea, 900 s sale con `mixedCauses` aunque la última pasada traiga el 409),
`snapshotDefinitiveClock_networkHoursBetweenTwoCauses_areNotCharged` (10 min de 409, 3 h de red, y sale 5 min después),
`snapshotDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts`, `snapshotDefinitiveClock_aRowFromBeforeV13_leavesOneShortCeilingLater`
y el round-trip de los seis `snapshotStall*` en el journal (no existía para la familia). Adaptado
`snapshotCeiling_aDifferentCause_startsItsOwnClock`: antes esperaba a 1 710 s y salía con «la sesión caducó»; ahora sale
a los 900 s de la suma con `mixedCauses`. El texto nuevo, en `SnapshotUploadCeilingLogicTests`.

**Verificación:** 15 mutantes, todos muertos (11 del reloj y la máquina, 4 del motivo y su texto). Review de tres
lentes (semántica del reloj, consumidores, tests): la semántica y los consumidores salen limpios, la refactorización de
la vuelta es equivalente; cazaron el «lleva días» (arreglado con el motivo nuevo), una aserción redundante y un test
de fila vieja que no probaba el «no en el acto» al pie de la letra (arreglados).

**Encontrado por el camino:** el runner puede pasar el reloj equivocado al canario de espera y al rastro sin que ningún
test lo vea, aquí y en la vuelta → `stall-canaries-have-no-test-for-which-clock-they-publish` (low). Y el encabezado
del índice de `docs/TICKETS.md` decía 516 con 529 filas; corregido a 530.
