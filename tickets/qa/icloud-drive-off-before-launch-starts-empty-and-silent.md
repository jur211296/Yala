---
id: icloud-drive-off-before-launch-starts-empty-and-silent
status: qa
priority: high
area: "sync, icloud"
created: 2026-10-19
source: "QA guiado del 2026-10-19 (prueba A · i1o5) · card tablero-con-icloud-drive-apagado-antes-de-abrir-n5zw"
updated: 2026-10-19
qa-status: needs-testing
qa-notes: pide iPhone real con iCloud Drive; el simulador no tiene iCloud
---

# Con iCloud Drive apagado antes de abrir Yala, la app arranca vacía y no avisa de nada

## El síntoma, en lenguaje de usuario

Tengo mis movimientos en Yala con iCloud. Cierro Yala, apago iCloud Drive en Ajustes y vuelvo a abrirla: la app
está vacía y no me dice por qué. Ni «iCloud no está disponible» ni nada. Sigue así cada vez que la abro, hasta que
enciendo iCloud otra vez.

## Lo medido

- **iPhone de QA, 19-oct** (Yala Dev desde 3e59c0689): store con 37 movimientos y 4 cuentas; Jürgen cierra Yala y
  apaga iCloud Drive. Al abrir: `iCloudSync` da `noAccount`, setup OK, `UserSegmentService` «pre-import tx=0», store
  con 0 movimientos y 1 cuenta. Ningún aviso, tampoco al relanzar. Guards del aviso en `UserDefaults`:
  `hasPrivateSession=true`, `storageMode=icloud`, `hasCompletedOnboarding=true` (pasan).
- **Código**: el único productor del aviso era la gracia de 5 s de `ContentView`, que arranca en la caída
  `hasPersonalData` true→false (`RemoteWipeGraceLogic.personalDataChanged`). `@State hasPersonalData` nace en
  `false` y la primera medida (`checkInitialSyncState`) también da `false` ⇒ no hay caída, no hay gracia, no hay aviso.
- **Inferido**: la «1 cuenta» del store vacío es la cuenta de sistema de Grupos (`GroupBridgeSystemEntities`, la única
  cuenta que se crea fuera del formulario); `checkHasPersonalData` la excluye, así que el store cuenta como vacío. Y el
  15-oct el aviso salió porque el vaciado ocurrió con el proceso vivo.

## Qué cambia

El arranque en frío pide el aviso «iCloud no está disponible en este dispositivo» (con «Entendido») cuando el store
personal está vacío, el onboarding está hecho, la sesión es privada con iCloud (el mismo eje que la gracia) y la cuenta
de iCloud no está disponible (sin token de iCloud Drive, o CloudKit dijo `notAuthenticated`). No depende de la caída.

- Decide DESPUÉS del bootstrap (`requestColdStartICloudNoticeAfterBootstrap`, al final de la tarea del arranque):
  el eje de sesión lo escribe el backfill del bootstrap, que corre en paralelo al splash, y decidido en el splash el
  aviso no salía (medido en el XCUITest con `-uitest-reset`; en un teléfono real pasa en el primer arranque tras
  actualizar). Re-mide el store antes de decidir.
- **Una vez por proceso, y cede a la gracia** (review adversarial del 19-oct, dos hallazgos reales): la marca y el
  «ya se miró» viven en `ColdStartICloudNotice` (del proceso), porque con varias ventanas el `ContentView` que asciende
  volvía a pedir el aviso y drenaba la petición en cola como si fuera de la gracia (con iCloud de vuelta, podía acabar
  en «Tus datos fueron eliminados»). Y si había filas antes de re-medir, la caída es de la gracia: pedir los dos sacaba
  el aviso dos veces (`coldStartDefersToTheGrace`).
- Va por la cola del router (`.presentRemoteWipeNotice`), como la gracia, y el drenaje re-mide todo.
- **Una petición del arranque solo enseña «iCloud no está disponible»**: si al drenar iCloud ya volvió, se retira sin
  aviso. Nunca sale «Tus datos fueron eliminados» ni «Empezar de cero» por este camino: los datos vuelven solos con la
  importación.
- Decisión pura: `RemoteWipeGraceLogic.coldStartRequestsICloudNotice` y `coldStartDrainPresents`, con el predicado de
  «iCloud no disponible» compartido con `noticeDecision`.
- Bajo `-uitest` el chequeo está apagado salvo con `-uitest-cold-start-icloud-check`: el simulador nunca tiene token de
  iCloud y sin eso saldría en todo XCUITest que arranca sin seed.

**Residual aceptado:** quien tenga el onboarding hecho, sesión privada, iCloud apagado y haya borrado a mano todas sus
cuentas y categorías verá el aviso en cada arranque. Es cierto (iCloud no está) y solo tiene «Entendido».

## Tests

- `YalaTests/RemoteWipeGraceLogicTests`: la decisión en frío con sus cuatro controles (con datos, sin onboarding,
  sesión que no obedece —también la de la nube, con el predicado real—, iCloud disponible), el drenaje que solo
  presenta el aviso de iCloud, y la paridad del predicado con la gracia. Más el cableado (source-scan) del productor,
  del arranque y del drenaje.
- `YalaUITests/Flows/ColdStartICloudUnavailableUITests`: el caso de la card y cuatro controles con el seam puesto
  (iCloud disponible, store con datos, sin onboarding, sesión solo-grupos).

## Device-QA para Jürgen (repetir A · i1o5, con Yala CERRADA al apagar Drive)

1. En el iPhone de QA, instala la build con este cambio (Yala Dev) y comprueba que tienes movimientos.
2. Cierra Yala del todo (desliza hacia arriba en el selector de apps).
3. Ajustes › tu nombre › iCloud › iCloud Drive → apágalo.
4. Abre Yala. **Esperado:** sale «iCloud no está disponible en este dispositivo» con un solo botón, «Entendido». No
   sale «Empezar de cero» ni «Tus datos fueron eliminados».
5. Toca «Entendido». **Esperado:** te quedas en el Panel (vacío), no te manda al Welcome.
6. Ajustes › iCloud › iCloud Drive → enciéndelo. Vuelve a Yala y espera un minuto. **Esperado:** tus movimientos
   vuelven solos y no sale ningún aviso de borrado.
