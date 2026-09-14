---
id: private-icloud-gate-back-lands-on-the-wrong-branch
status: backlog
priority: medium
area: "onboarding, modo-nube"
created: 2026-09-14
source: "review adversarial de `restore-start-fresh-keeps-the-imported-corpus` (2026-09-14) · VISTO en simulador"
---

# Cancelar en la puerta de iCloud te deja en «Es mi primera vez», aunque hayas entrado por «Ya tengo una cuenta»

## El síntoma, en lenguaje de usuario

Welcome → «Ya tengo una cuenta» → «Restaurar desde iCloud» → «Empezar desde cero» → la app revisa mi
iCloud y me pregunta qué hacer → toco el chevron de volver. **Y acabo en «Es mi primera vez en Yala:
elige dónde guardar tus datos»**, que es la rama contraria y una pantalla que no había visto. Para
volver a Restaurar tengo que subir otro nivel y repetir la búsqueda entera.

## Lo medido (2026-09-14, árbol del PR de `restore-start-fresh-keeps-the-imported-corpus`)

- **Visto en simulador**, no deducido: iPhone 17 Pro, iOS 26.5, instalación fresca. Tras el chevron sale
  el sub-chooser de «Es mi primera vez».
- El `onBack` de la puerta es `goTo(newBranchOriginStep)` (`WelcomeFlowContainer.swift`), y
  `newBranchOriginStep` da `.newChooser` cuando el sub-chooser de «Soy nuevo» es visible — que en
  producción lo es desde que la elección nube está al 100 %.
- El nombre lo dice: ese helper contesta «de dónde vino quien está en la puerta» **asumiendo que entró
  por `handleNewOption(.privateAccount)`**. El PR del 2026-09-14 le añadió un segundo productor, y viene
  de la otra rama.
- **No hay bucle ni camino muerto**, y ningún dato se pierde: la puerta vuelve a preguntar siempre, así
  que elegir «privado» desde ahí es inofensivo, y el «Volver» de ese chooser lleva al de nivel 1.
- **Y el daño que sí tenía ya está cerrado en ese PR**: con `hasShownWelcomeChooser` en `true`, matar la
  app en ese punto abría el onboarding privado DIRECTO —sin chooser y sin validar iCloud—, que es el bug
  que aquel ticket cerraba, por detrás. El callback baja el flag, así que ese kill vuelve al Hero.

## Qué se espera

Que el chevron devuelva a la pantalla de la que se vino: la de Restaurar.

## Por qué no se hizo en el mismo PR

El destino del «volver» lo calcula el container y **la puerta no sabe de dónde la abrieron**. Dárselo
pide meterle un payload al `case privateICloudGate` de `WelcomeFlowStep`, y ese literal está pinneado
por source-scan (`WelcomePrivateICloudGateTests.privateCard_goesThroughTheGate` exige
`goTo(.privateICloudGate)` tal cual). Es un objeto propio: la forma del step, no el botón que este PR
arregla.

Dos caminos, y el primero es el que parece bueno:

1. **`case privateICloudGate(returningTo: WelcomeFlowStep)`**, con el molde de `groupsGate(purpose:)`, que
   ya lleva payload. Hay que actualizar el pin y los dos productores.
2. Que la puerta reciba su `onBack` como parámetro, igual que recibe `onRestore`. Menos cambio en el
   enum, pero mueve la decisión a los call-sites — que es justo lo que `newBranchOriginStep` centralizó.

**Ojo con la salida fácil:** un `@State` o una preferencia al lado del step que diga «vengo de Restaurar»
es el estado paralelo que la puerta de Grupos ya pagó una vez; el dato viaja DENTRO del case.

## Criterios de aceptación

- [ ] Restaurar → «Empezar desde cero» → puerta → chevron → **vuelve a Restaurar**.
- [ ] «Es mi primera vez → privado» → puerta → chevron → sigue volviendo al sub-chooser de «Soy nuevo»
      (o al chooser de nivel 1 donde no haya sub-chooser). Sin cambios.
- [ ] La tercera salida de la puerta («Traer mis datos») sigue llevando a Restaurar, y sigue retirando el
      arm del borrado.

## Relacionados

- [[restore-start-fresh-keeps-the-imported-corpus]] — el PR que añadió el segundo productor.
- [[welcome-copy-acusa-al-dueno-de-traer-datos-ajenos]] — otra salida del mismo Welcome.
