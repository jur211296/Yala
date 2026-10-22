---
id: fresh-start-after-adopt-exit-with-group-changes-ends-in-device-wipe-failed
status: done
area: "welcome, borrado, grupos"
priority: high
created: 2026-10-15
updated: 2026-10-15
closed: 2026-10-15
source: "Barrido de QA 2.1 (Frank, 2026-10-15), visto en el simulador"
---

# Tras salir de la nube, «Borrar todo y continuar» con cambios de grupos acaba en «No pudimos borrar todo»

## Qué pasa

Es el caso de la card `tablero-decidir-tras-cancelar-la-entrada-con-la-069g` (ticket
`fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes`, decisión A de Jürgen del 2026-10-06).
Lo esperado tras «Borrar todo y continuar» es la puerta privada con el motivo y la cifra de los cambios de grupos, y la
oferta de perderlos. En el simulador sale en su lugar la puerta con **«No pudimos borrar todo · No pudimos terminar.
Puede que parte de tus datos ya no esté y el resto siga aquí…»** (`welcome_private_icloud_wipe_failed_device`), con
«Volver a intentarlo» y «Dejarlo por ahora».

La primera mitad del arreglo sí funciona: ya no sale «inténtalo en un rato», se llega a la puerta privada.

## Cómo se reproduce (medido el 2026-10-15)

Yala Dev en el simulador (iPhone 17 Pro, iOS 27.0), árbol `8cd693cb6`:

1. Lanzar con `-uitest -uitest-reset -uitest-seed minimal -uitest-welcome-after-adopt-exit -uitest-groups-outbox-pending`.
2. «Es mi primera vez en Yala» → sale «Detectamos datos previos en tu dispositivo. ¿Borrar todo…?».
3. «Borrar todo y continuar» → **«No pudimos borrar todo»**. Dos veces seguidas, igual.

**Control:** el mismo lanzamiento sin `-uitest-groups-outbox-pending` llega al onboarding («Tu nombre»). El fallo lo
provoca el cambio de grupos pendiente.

Capturas: `~/Claude/worktrees/_capturas/2026-10-15-barrido-qa-2-1/c5-1-borrar-todo-y-continuar.png` y
`c5-2-con-grupos-pendientes-falla-el-borrado.png`.

## Lo que se sabe del código (sin medir dentro)

- La pantalla es `WelcomePrivateICloudGateView.deviceWipeFailed`. Llega ahí cuando `deviceCorpus.wipe()` devuelve un
  motivo que no es `CloudSessionSignOut.freshStartGroupsPendingFailure`, o cuando lo es pero
  `CloudSessionSignOut.shared.freshStartGroupsBlock` es `nil` (`groupsPendingPhase`, :844-848).
- El borrado (`ContentView`, ~:2490-2550) devuelve `"deviceWipeFailed"` desde el `catch` genérico. Solo el
  `catch is DataWipeService.GroupsDomainWipeError` lleva a la oferta de perderlos. El texto del aviso dice que parte de los
  datos puede ya no estar, así que puede que el borrado personal sí corriera antes de lanzar.
- El desenlace no deja rastro en el log de la app: ningún `print` en ese `catch`, solo el canario
  `freshStartWipeFailed · deviceCorpusWipe`.
- **Sin descartar que sea del montaje:** el seam deja la fila del outbox en el store `YalaSyncMeta-UITest`. Lo primero es
  saber qué lanza y desde qué paso; si es el seam, el arreglo es el seam y esta card se cierra.

## Hecho cuando

Con cambios de grupos que no pueden subir, «Borrar todo y continuar» tras salir de la nube enseña la oferta de perderlos
con su cifra (o se demuestra que el fallo es solo del seam y se arregla el seam), con un XCUITest de este camino.

## Causa (medida el 2026-10-15 con una sonda en el simulador)

**Era del montaje de test, no del producto.** La puerta devolvía `importNotQuiescent` antes de llegar a la subida de
grupos: `performDeviceCorpusWipe` espera al import de iCloud si `ICloudPersonalCorpusProbe.mirrorWillSync()` dice que el
store espeja, y bajo `-uitest` lo decía siempre. El store `YalaModel-UITest` monta con `cloudKitDatabase: .none`, pero sale
de `personalConfiguration` antes de capturar la decisión del mount, así que `personalStoreMountedDecision` se queda en
`.iCloudMirror`. Sin cuenta de iCloud, `waitForImportQuiescence` devuelve `false` al instante. Es la regla «El testigo del
mount MIENTE en los hosts de test» de `swiftdata-cloudkit.md`.

El control «sin cambios de grupos» no descartaba nada: sin ellos el alert borra en el sitio y nunca pasa por la puerta.

## Arreglo

`AppBootstrapper.applyUITestHooksEarly` pone `ICloudPersonalCorpusProbe.mirrorWillSync = { false }`, la verdad del host de
test. XCUITest `WelcomeFreshStartAlertUITests#testAfterAnAdoptExit_withGroupChanges_offersTheLossWithItsCount_andLosingThemReachesOnboarding`
recorre oferta con cifra (1) → «¿Perder estos cambios?» → onboarding; con el seam quitado cae con «No pudimos borrar todo».

En producción el Welcome normal monta `.neutralNoMirror` y no espera nada. La población real que sí podría caer en la misma
espera (espejo adjunto con iCloud Drive apagado) va aparte: `welcome-wipes-on-a-mirrored-store-never-start-with-drive-off`.

Capturas: `~/Claude/worktrees/_capturas/2026-10-15-borrar-todo-cambios-grupos/`.
