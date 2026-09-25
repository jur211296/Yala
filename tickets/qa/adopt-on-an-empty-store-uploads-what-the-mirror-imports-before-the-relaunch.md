---
id: adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-25
source: "review adversarial de `adopt-uploads-a-foreign-corpus-without-a-lineage-check` (lente de bypass, H1), 2026-09-24"
---

# Un adopt sobre un store VACÍO no pide prueba de linaje, y lo que el espejo importa antes de relanzar se sube después

## El problema, en lenguaje de usuario

Instalo Yala en un iPhone cuyo iCloud tiene unas finanzas que nunca pasaron a la nube. En la bienvenida entro en una
cuenta en la nube que es de otra cosa (por ejemplo, una que nació en la nube en otro teléfono). En ese momento la app
aún no ha bajado nada de iCloud, así que no hay nada que comprobar y entra. Mientras me pide reabrir, iCloud baja mis
finanzas; al reabrir, se suben a esa cuenta y se mezclan.

## Lo medido (2026-09-24, leído en el código, sin ejecutar)

- La guarda de linaje del adopt solo corre con algo que subir en ese instante (`MigrationWorkExecutor.runAdoptOrphanReconcile`,
  `if pendingUploads > 0`). Es a propósito: el 2.º dispositivo de una cuenta nacida en la nube no puede tener marcador
  (Paso 0 · D2 del ticket padre).
- La quiescencia del adopt (`isImportQuiescent`) da `true` ANTES del primer import: con `lastImportDate == nil` y sin sync,
  `SubcategoryDedupGate.decide` devuelve `.run`; lo advierte `iCloudSyncService.swift` (~623).
- `CloudSyncEngine.fastForwardHistoryBaseline` sale SIN anclar si no hay ninguna transacción personal (el `guard let lastTx`),
  y el token queda ausente.
- Tras relanzar, un token ausente da `.fullRescanBootstrap` (`HistoryTokenFallbackLogic`), y el drain traduce toda
  transacción personal que no sea del motor, imports de CloudKit incluidos.

Lo que NO está medido: que en un iPhone real el Welcome llegue al adopt antes del primer import (el flujo «Restaurar
desde iCloud» y `ICloudRestoreInProgressLogic` pueden adelantarse), y que el espejo siga importando hasta el
relanzamiento asistido. Con el mismo iCloud que la cuenta, el mismo mecanismo re-emite el corpus: ruido, no mezcla.

## Relación

- Misma familia que `reverse-cancel-pushes-what-the-mirror-imported-during-the-wait`: lo que el espejo importa durante
  una espera acaba subiendo sin que nadie lo haya comprobado.
- Padre: `adopt-uploads-a-foreign-corpus-without-a-lineage-check`.

## Opciones, sin decidir

- Exigir el primer import terminado (`hasCompletedFirstImport` / la ventana de `ICloudRestoreInProgressLogic`) en la señal
  de quiescencia del adopt, para que la guarda vea lo que el espejo iba a traer.
- Anclar el baseline aunque no haya transacción personal, para que el primer drain no re-emita lo importado después.

## Criterios de aceptación

- [x] Un adopt con el store vacío no sube después, por el drain, un corpus que no desciende de la cuenta.
- [x] El 2.º dispositivo de una cuenta nacida en la nube sigue entrando, y el del mismo iCloud también.

## Resolución (2026-09-25)

**Medido antes de tocar nada.** El adopt corre con el espejo adjunto en Ajustes («Activar la nube en este dispositivo»), en
el resume del arranque y en el «Ya tengo una cuenta» de un Welcome que se mató a mitad: ahí el fichero del store ya existe y
el arranque no monta neutro. El Welcome de una instalación limpia monta neutro y no tenía agujero. Nada fuerza el
relanzamiento tras el adopt y el espejo sigue importando.

**La premisa del ticket, corregida.** Anclar la línea base sin transacción personal no cerraba nada: un teléfono real siempre
tiene una (los tipos de cambio que siembra el arranque), y lo que se importa después del paso 3 queda por encima de
cualquier ancla. Exigir `hasCompletedFirstImport` dejaría fuera al 2.º teléfono de una cuenta nacida en la nube (un iCloud
sin nada que importar no lo enciende), y la gracia de `BootSaveGateLogic` falla abierta con un import lento.

**El arreglo: el adopt no da por contestada la pregunta del linaje mientras el corpus de iCloud no haya llegado.** Con el
espejo adjunto y ninguna fila local que la pida, el reconcile le pregunta a CloudKit, sin el espejo, si ese iCloud tiene
alguna (`ICloudPersonalCorpusProbe.adoptRelevantRecords`). Si la tiene, espera sin tocar nada a que el import la baje, y
entonces decide la guarda de siempre, con su salida de siempre. Si no la tiene, o no hay cuenta de iCloud, entra. Sin
respuesta, reintenta. Canario `cloudAdoptICloudCorpusChecked`. Regla en `swiftdata-cloudkit.md` («Y con el espejo
adjunto…»).

**Tests.** `MigrationWorkExecutorTests` (sección del store sin corpus): el corpus ajeno que llega tarde no sube y el flujo no
arma la nube mientras espera; el 2.º teléfono de una cuenta nacida en la nube entra (sin corpus o sin cuenta de iCloud); el
del mismo iCloud espera a su corpus y entra sin resubirlo; sin respuesta de CloudKit no entra; tras un `found`, la primera tanda no basta; sin sonda cableada no entra; sin espejo, o con
filas de linaje en local, no se pregunta; el canario sale una vez por desenlace. `AdoptICloudCorpusCheckWiringTests`: producción
inyecta los dos seams y los tipos de la sonda casan con la exención de la guarda.

**Review adversarial (tres lentes).** Ningún hallazgo alto. Cambió el arreglo en un punto: tras un `found`, la primera
tanda de filas ya no apaga la espera (esperaba a que llegara UNA fila y la guarda juzgaba un corpus a medias); ahora espera a
que el primer import del proceso termine y quede quieto. Además: la sonda tolera una zona borrada entre la lista y la
lectura, un test fija que el ejecutor sin sonda cableada no entra, y el test de las exenciones las ata entidad a entidad.
Aceptado a sabiendas y escrito en la regla: falla cerrado, así que una sonda que no contesta o un espejo que nunca baja lo
que la zona tiene dejan a esta población esperando hasta el techo de 72 h, donde antes entraba; y el 2.º teléfono de una
cuenta nacida en la nube cuyo iCloud tiene un corpus viejo de Yala sale por linaje, como ya salía cuando el import ganaba la
carrera. En `Yala Dev` con `.localNoMirror` la sonda puede mirar otro contenedor que el espejo (solo desarrollo).

**Lo que queda.** Lo que llega al espejo DESPUÉS de la respuesta de CloudKit —otro teléfono del mismo Apple ID que escribe
en un iCloud vacío, o una cuenta de iCloud que se inicia tras un `noAccount`— sube igual al relanzar:
`adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check` (medium). Y lo que un import tardío trae de filas que
el backend ya conoce sube con un reloj nuevo que puede pisar ediciones más nuevas:
`adopt-window-late-imports-overwrite-newer-cloud-edits` (medium). La sonda lee CloudKit, que no existe en el simulador:
device-QA abajo.

## Device-QA (iPhone real: CloudKit no existe en el simulador)

**Montaje.**
1. iPhone A con el build nuevo instalado, con un Apple ID cuyo iCloud tenga finanzas de Yala (unas cuantas transacciones)
   que NUNCA pasaron a la nube.
2. Una cuenta en la nube que no venga de ese iCloud: créala en otro teléfono (B) con «Soy nuevo → Tu cuenta en la nube» y
   apunta una transacción en B para reconocerla.
3. En A: borra Yala, reinstálala y ábrela. En la bienvenida **no elijas nada**: cierra la app desde el selector de apps y
   vuelve a abrirla enseguida. Así el segundo arranque monta el store con el espejo de iCloud y el store sigue vacío.

**Caso 1 · iCloud con finanzas de otra historia (el del ticket).**
1. En A: «Ya tengo una cuenta» → entra con la cuenta de B.
2. Esperado: la activación no termina mientras iCloud baja los datos (barra de progreso sin «cierra y vuelve a abrir»).
   Cuando han bajado, a los ~15 min sale el aviso de que los datos de este teléfono no coinciden con esa cuenta.
3. En B: tira hacia abajo en Movimientos. **No aparece ninguna transacción de A.**
4. En A: la app sigue en iCloud con sus finanzas.

**Caso 2 · iCloud sin finanzas de Yala (control).**
1. Repite el montaje con un Apple ID sin datos de Yala y entra con la cuenta de B.
2. Esperado: entra como siempre, sin esperas nuevas, y ve la transacción de B.

**Qué mirar en Analytics Engine.** Canario `cloudAdoptICloudCorpusChecked`: `found` en el caso 1, `none` en el 2. Un
`failed:…` en cualquiera de los dos es la sonda rota en producción: avisar.
