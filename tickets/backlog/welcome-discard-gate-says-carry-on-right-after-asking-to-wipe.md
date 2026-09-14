---
id: welcome-discard-gate-says-carry-on-right-after-asking-to-wipe
status: backlog
priority: low
area: "onboarding, modo-nube, copy"
created: 2026-09-14
source: "review adversarial del PR de `activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable` (3 lentes, 2026-09-14); NO reproducido en device"
---

# En el Welcome, «Empezar desde cero» sin iCloud responde «Puedes seguir»

## El síntoma, en lenguaje de usuario

Abro Yala por primera vez, elijo «Ya tengo cuenta → iCloud», y en Restaurar toco **«Empezar desde cero»**.
La app va a comprobar mi iCloud y no puede. Me dice: «Este teléfono no tiene iCloud activo… **Puedes
seguir**: por ahora tus datos se quedan aquí». Acabo de pedir que se borren.

## Lo medido (2026-09-14)

- `ContentView.swift` enruta el `onStartFresh` de `WelcomeRestoreView` a
  `returnToWelcomeChooser(dismissing: $showWelcomeRestore, step: .privateICloudGate)`, y
  `WelcomeFlowContainer` monta ese step con `unverifiedExit: .proceedWatchingTheMirror`.
- O sea: el mismo gesto que en la activación ya vuelve atrás sin prometer nada, en el Welcome sigue
  respondiendo con el copy de «no has pedido nada, puedes continuar».

## Por qué esto es COPY y no el mismo bug de datos

Medido, y es lo que lo deja en `low`:

- En el Welcome la puerta **sí** recibe `deviceCorpus` (`deviceCorpusGate`), así que con datos locales la
  decisión no es `.unreachable` sino `.foundDeviceData(iCloudUnverified: true)` — que **sí borra** el
  teléfono, con doble confirmación. `.unreachable` y `.noICloud` solo se alcanzan cuando **no hay nada
  local que borrar**.
- Y el testigo del espejo tardío que esa salida escribe es **correcto ahí**: en el Welcome «empiezo de
  cero» es la frontera de otro usuario en este dispositivo, así que el `.handover` de su aviso es el
  scope que toca — al revés que en la activación, donde purgaría los grupos de quien está activando.

Lo que queda mal es lo que la pantalla DICE: «Puedes seguir: por ahora tus datos se quedan aquí» y
«Inténtalo otra vez antes de seguir» se escribieron para quien acaba de elegir «privado», no para quien
acaba de pedir un borrado.

## Qué hay que decidir

¿El copy de esas dos fases distingue «vengo de elegir privado» de «vengo de pedir un borrado», o se acepta
que en el Welcome la frase valga para los dos? El material ya existe: las tres claves
`welcome.privateICloud.discardUnverified*` que el ticket padre estrenó.

## Criterios de aceptación

- [ ] Tras confirmar «Empezar desde cero» en el Welcome y no poder preguntarle a iCloud, la pantalla no
      dice «Puedes seguir» ni «antes de seguir».
- [ ] La salida **sigue** adelante y sigue escribiendo el testigo del espejo tardío: en el Welcome no hay
      app detrás a la que volver, y el ADR dice que no poder preguntar JAMÁS bloquea.

## Relacionados

- [[activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable]] — el ticket padre, que
  arregló la mitad de la activación y estrenó el copy.
