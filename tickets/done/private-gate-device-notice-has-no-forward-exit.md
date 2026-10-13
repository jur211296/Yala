---
id: private-gate-device-notice-has-no-forward-exit
status: done
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-13
updated: 2026-10-12
source: "review adversarial de `groups-only-private-restart-skips-the-wipe-alert`, lentes de camino (F5) y de datos (A6)"
---

# Con datos en el teléfono y sin iCloud, la puerta privada solo ofrece borrar o volver

## El síntoma

Mi teléfono tiene datos de antes y no tengo iCloud activo (o no hay red). Elijo «Es mi primera vez →
privado» y la única forma de seguir adelante es borrar. Si no quiero borrar, solo puedo volver atrás.

## Lo medido (2026-09-13)

Desde el arreglo de `groups-only-private-restart-skips-the-wipe-alert`, `WelcomePrivateICloudGateLogic
.decide` da `.foundDeviceData` cuando hay corpus local, **también** en las dos celdas que antes eran
`.noICloud` y `.unreachable`. Con eso desaparecen sus dos CTA:

- **«Seguir así»** (`continueWithoutValidating`), que es el único gesto que escribe el testigo del espejo
  tardío. El ADR dice que no poder preguntar **jamás bloquea**.
- **«Reintentar»** del error de red.

`foundDeviceContent` tiene dos salidas: borrar, o volver al chooser. **No es un camino muerto** —desde el
chooser se puede elegir la nube o restaurar— pero sí es una pantalla que solo avanza destruyendo.

Y hay un agravante: `ContentView.checkHasExistingData()` **falla CERRADO** (un fetch que lanza devuelve
`true`), así que un error de lectura convierte «Es mi primera vez» en «borra todo o vete» sin que haya un
solo dato detrás.

## La decisión que hace falta

Una tercera salida en el aviso del teléfono no es obvia: «seguir sin borrar» significa montar el
onboarding de cero **encima** de los datos que hay, que es justo el bug que el aviso vino a impedir. Las
dos opciones sobre la mesa:

- **(a)** Ofrecer «Activar Yala completo» desde aquí. Es lo que el caso mayoritario quiere de verdad —un
  solo-grupos que ahora quiere vida personal— y esa pantalla **conserva** los grupos. Hoy no hay forma de
  llegar ahí desde la puerta.
- **(b)** Dejarlo como está y mejorar el copy del «volver», para que se lea como «esto no es lo que
  buscas» en vez de como un cancelar.

## Cómo se prueba

- Unit: la tabla de `decide` ya cubre las celdas; lo que cambie serán las salidas de la vista.
- Device-QA: en un teléfono sin cuenta de iCloud.

## Medido en 2.1 (triage 2026-10-08)

- Sigue. `WelcomePrivateICloudGateLogic.decide` (`:97-105`) da `.foundDeviceData` también sin cuenta y con fallo.
- `foundDeviceContent` (`WelcomePrivateICloudGateView.swift:456`) tiene dos salidas, «Dejarlo como está» (`leaveGate()`) y borrar. Su docblock dice «No hay tercera».
- `ContentView.checkHasExistingData()` (`:1442-1464`) sigue fallando cerrado: el `catch` devuelve `true`.

## Pregunta para Jürgen (triage 2026-10-08)

- **A** (recomendada): la (a) del ticket. Ofrecer «Activar Yala completo» desde el aviso del teléfono, que conserva los grupos. Además, que un error de lectura no cuente como «hay datos».
- **B**: la (b). Dejar las dos salidas y que el copy de «Dejarlo como está» se lea como «esto no es lo que buscas».
- **C**: solo arreglar el fallo cerrado de `checkHasExistingData`.

Con A, la prioridad es `medium`.

Triage 2026-10-08: abierto · medium → medium · `foundDeviceContent` sigue con dos salidas (dejarlo o borrar) y `checkHasExistingData` sigue fallando cerrado (`ContentView.swift:1463`).

## Resuelto (2026-10-12) — decisión de Jürgen: «solo lo alcanzable»

Medido antes de construir: una sesión solo-grupos completada no vuelve al Welcome, así que «Activar Yala completo» desde
este aviso no tendría quien lo use (el único camino, inferido, es un alta de grupos a medias: ticket
`groups-entry-left-half-done-reaches-the-private-gate-with-group-rows`). Se hizo la otra mitad de A:

- Un error al leer los datos del teléfono ya no cuenta como «hay datos». La puerta enseña «No pudimos revisar este
  teléfono» con «Reintentar» (vuelve a medir) y «Volver», sin ningún borrado. El resto de consumidores del detector sigue
  fallando cerrado a propósito.
- Probado: `PrivateGateDeviceUnreadableTests` (tres suites), mutante de fallo cerrado verificado, y el XCUITest
  `PrivateGateDeviceUnreadableUITests` (pantalla nueva + control con datos legibles), con el seam
  `-uitest-private-gate-device-reading`. Capturas: `capturas/antes.png` y `capturas/despues.png` del PR.

## QA

Ya cubierto por XCUITest. En device no se puede provocar el error de lectura sin un build de desarrollo; si se quiere
ver: build `Yala Dev`, lanzar con `-uitest -uitest-reset -uitest-private-gate-device-reading unreadable`, «Empezar» →
«Es mi primera vez». Esperado: la pantalla nueva; «Reintentar» la repite; «Volver» vuelve a la elección.

## Cierre

Cerrado en el barrido de QA 2026-10-12: el XCUITest PrivateGateDeviceUnreadableUITests recorre la pantalla nueva y su control con datos legibles, y PrivateGateDeviceUnreadableTests fija la lógica con un mutante de fallo cerrado (PR #470). En un iPhone el error de lectura no se provoca sin un build de desarrollo, y el cambio no ofrece borrar nada.
