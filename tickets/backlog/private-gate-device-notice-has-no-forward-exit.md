---
id: private-gate-device-notice-has-no-forward-exit
status: backlog
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-13
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
