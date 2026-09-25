---
id: lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived` (2026-09-24), lentes del dispositivo legítimo y del duplicado"
---

# Un movimiento borrado mientras el otro teléfono calla bloquea para siempre el relevo y el adopt

## El problema, en lenguaje de usuario

Empiezo a activar la nube en el iPhone A, sube parte de mis datos y se queda sin conexión. En el iPhone B, con el mismo
iCloud, borro un movimiento que A ya había subido y creo otro. Cuando B toma el relevo (o entra en la cuenta), Yala no sube
nada y me dice que espere a iCloud; pero por mucho que espere, nunca pasa.

## Lo medido y lo inferido (2026-09-24)

- **Medido en código**: la prueba de cobertura (`MigrationWorkExecutor.adoptSharedRowsProof`), que usan el adopt y desde
  este ticket el relevo (`checkForwardLineage`), exige que toda fila VIVA del backend esté en local en cada tabla con algo
  que subir. No distingue «su identidad no llegó» de «la fila se borró aquí»: B no puede saberlo, porque los testigos
  `SyncIdentity` son locales de cada teléfono (store de metadatos sin CloudKit) y un borrado que llega por CloudKit no deja
  rastro. El único que tombstonea esa fila en el backend es el motor del líder, que está callado.
- **Medido en código, sin montar**: los deduplicadores automáticos también borran copias que A pudo subir
  (`NotificationService` agrupa por `typeRaw`; `CategoryDeduplicationService` funde las categorías semilla, disparado
  desde `iCloudSyncService`). Ahí el bloqueo sí evita un duplicado real (la categoría fundida volvería doble), pero sigue
  sin salida si A no vuelve.
- **Antes del arreglo** el mismo caso no bloqueaba: subía, y el `verify` resucitaba la fila borrada (zombi) o duplicaba.
- **Menor, medido**: `verifyEnumerationComplete` solo recorre las tablas que trae el Merkle; una tabla ausente del Merkle y
  enumerada a medias pasaría la cobertura.

## Ideas (sin decidir)

- Casar por CONTENIDO las filas sin identidad de B con las del backend (el ancla de `SyncIdentityService`) en vez de exigir
  cobertura total: resolvería los dos lados, pero la enumeración hoy solo trae identidades.
- Una salida explícita tras el techo («subir igualmente, puede duplicar algo») es decisión de producto de Jürgen.

## Criterios de aceptación

- [x] Un borrado hecho en el otro teléfono durante la espera no deja el relevo ni el adopt sin salida, sin reabrir el
      duplicado de `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`.

## Resolución (2026-09-24)

**Qué cambia para quien usa la app.** Si borras un movimiento en el segundo teléfono mientras el primero está callado,
el relevo y la entrada en la cuenta ya no se quedan esperando para siempre: siguen en cuanto lo que este teléfono va a
subir lo creó él después. Y las filas del primer teléfono que están aquí sin su marca interna, cuando se pueden
reconocer sin ambigüedad (mismo instante de creación único, mismo comercio, misma semilla), toman su identidad en vez de
esperar a iCloud. Lo que sigue esperando, con el aviso de siempre a los 15 min, es el teléfono que conserva una fila del
primero sin su marca y sin forma segura de reconocerla: subirla la duplicaría.

**Cómo** (regla «Una fila que falta solo bloquea si aquí puede tener gemela» en `.claude/rules/swiftdata-cloudkit.md`):
`adoptSharedRowsProof` pregunta por las candidatas —filas sin identidad del backend— y falla cerrado. Casa por
`LineageTwinKey` solo con clave única (y nunca categorías del usuario por nombre); lo demás bloquea mientras quede una
candidata sospechosa, y no lo son la creada aquí después de la última escritura del backend (historial de SwiftData sin
el autor del espejo, +10 min) ni la semilla cuya clave de fusión es la de una fila que falta.

**Dos rondas de review.** La primera (tres lentes) tumbó «clave legible sin gemela ⇒ no bloquea», que fallaba abierto:
el `createdAt` que la migración ligera rellenó en cada teléfono, categorías editadas, colisiones del mismo milisegundo
que cruzaban identidades y la superviviente del deduplicador. La segunda cazó el renombrado para fundir categorías, la
semilla editada, la fila del backend sin clave y un deshacer a medias.

**Residuales con ticket**: `row-deleted-during-the-relief-wait-comes-back-after-the-relief` (la fila borrada vuelve tras
el relevo), `markerless-adopt-stays-blocked-while-another-device-writes-to-the-account`,
`lineage-enumeration-check-skips-tables-absent-from-the-merkle` (hallazgo menor de la ficha) y, al margen,
`notification-dedup-deletes-all-custom-reminders-but-one`. Sin ticket, escritos en la regla: desfase de relojes de más
de 10 min; que el espejo firme todas sus importaciones con su autor (premisa compartida con el cierre de la sesión
privada, pendiente de su device-QA); el deduplicador del arranque en la nube funde la semilla que suba duplicada
(inferido del código).
