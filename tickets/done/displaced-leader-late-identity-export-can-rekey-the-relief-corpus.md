---
id: displaced-leader-late-identity-export-can-rekey-the-relief-corpus
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived` (2026-09-24), lente del duplicado"
---

# Las identidades que el líder desplazado exporta TARDE pueden pisar las del relevo y duplicar

## El problema, en lenguaje de usuario

El iPhone A empieza a activar la nube, prepara mis movimientos y se queda sin conexión antes de mandarlos a iCloud. El
iPhone B toma el relevo y termina. Días después A recupera la conexión y manda a iCloud lo que tenía preparado: B podría
acabar con los mismos movimientos dos veces.

## Lo medido y lo inferido (2026-09-24)

- **Inferido, sin medir**: los dos teléfonos hacen su backfill (`SyncIdentityService.backfillIdentities`, en
  `assignIdentity`) y acuñan identidades distintas para las mismas filas; el rebind no las une porque los testigos son
  locales. B pasa la comprobación del relevo cuando A no subió nada (`has_personal_writes=false` o backend sin filas vivas)
  o cuando todo lo que subió llegó a B, y sube con sus identidades. Si la exportación tardía de A gana el campo `syncID`
  en CloudKit, la fila local de B cambia de identidad y el siguiente push/pull la trata como otra: libro doble.
- Es la clase del residual (c) del adopt, escrito en el docblock de `MigrationWorkExecutor.runAdoptOrphanReconcile`
  (import-lag → identidad fresca → duplicado), pero en la ida y con el líder volviendo.
- **Sin medir**: cómo resuelve el espejo de CloudKit el conflicto del campo `syncID` entre los dos teléfonos.

## Criterios de aceptación

- [x] Medido si la exportación tardía del líder cambia la identidad de filas ya subidas por el relevo; si sí, que no
      duplique.

## Resolución (2026-09-24)

**La premisa se sostiene en el código; lo único sin medir es qué valor gana CloudKit.** Se diseñó para el peor caso.

- **Medido**: `syncID` va en el schema personal (los `.ckdb` lo llevan como `CD_syncID`), así que el espejo lo lleva de
  un teléfono a otro. Los testigos `SyncIdentity` viven en el store de metadatos (`cloudKitDatabase: .none`). El espejo
  del relevo sigue vivo desde `assignIdentity` hasta el remonte que sigue al cutover (`personalStoreDecision` solo monta
  `.cloudMirrorOff` con el par armado).
- **Medido, con tests que fallaban sin el arreglo**: si la identidad de una fila ya subida cambia por debajo, (1) el
  snapshot, que pagina por `afterSyncID`, la vuelve a subir con la identidad nueva (el backend guarda dos); (2) el pull de
  la verificación no encuentra fila con la identidad vieja y crea un born-remote (dos aquí); (3) una edición que traiga el
  import se traduce bajo la identidad nueva y sube como fila aparte.
- **Sin medir**: cómo resuelve CloudKit el conflicto del campo. Pide dos teléfonos y un corte de red. El canario nuevo
  `cloudRelayIdentityRestored` lo mide en la flota: distinto de cero es que CloudKit le dio la razón al líder.
- **Fuera de la ventana**: tras el remonte el relevo ya no espeja, así que la exportación del líder no le llega. Llegar
  antes de su `assignIdentity` es el caso de #241, que el backfill resuelve dando esa identidad.

**Arreglo** (`MigrationWorkExecutor.restoreRelayIdentities`): gana la identidad del relevo, la que el backend conoce. Una
fila se restaura solo si su identidad no tiene testigo aquí y su record de CloudKit casa con UN testigo huérfano con
coordenadas; lo ambiguo no se toca y una lectura que falla —también la de los metadatos de CloudKit— es avería local,
salvo en el reconcile de `done`, que ya corre sin espejo y deja rastro y sigue. Corre antes de cada página del snapshot,
antes del pre-check de la verificación de la ida, antes del drain de cada página del pull
(`pullAndApplyOnce(beforeDrain:)`), antes del árbol local del Merkle (`verifyIntegrity(beforeLocalTree:)`), antes del
drain del cutover y al empezar el reconcile de `done`. Regla: «Y lo que el líder desplazado exporta TARDE a iCloud no
le cambia la identidad al relevo» en `.claude/rules/swiftdata-cloudkit.md`.

**Pruebas**: 15 casos en `MigrationWorkExecutorTests` (los tres caminos del duplicado, el import durante la espera del pull
y del Merkle, el cutover, el reconcile, los seis tipos acuñados, el camino real de coordenadas con los metadatos del espejo
sembrados en el SQLite, seis formas de ambigüedad, el camino barato, las averías de lectura y el canario), y una tanda de
mutantes. Review adversarial con tres lentes: cazó que una lectura fallida de los metadatos se leía como «no hay nada»,
la ventana del Merkle, y que el seam escondía el camino de producción. Sin device-QA: el arreglo se prueba entero en unit, y lo que queda del dispositivo
(qué gana CloudKit) lo mide el canario.

**Residuales, con ticket**: una fila re-identificada y borrada antes de restaurarse
(`relay-row-rekeyed-then-deleted-tombstones-the-leader-identity`), la misma ventana en el adopt
(`adopt-window-late-leader-identity-export-can-duplicate-after-the-remount`) y la vuelta a iCloud que re-importa la
identidad del líder (`reverse-mount-can-reimport-a-late-leader-identity`). Los demás teléfonos del mismo iCloud que aún no
entraron se quedan con la identidad que gane CloudKit; al entrar los re-identifica el linaje de #242 (clave única) o
esperan con su aviso.
