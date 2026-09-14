---
id: activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable
status: backlog
priority: high
area: "onboarding, modo-nube"
created: 2026-09-14
source: "review adversarial del PR de `activation-restore-start-fresh-keeps-the-imported-rows` (dos lentes, 2026-09-14); NO reproducido en device"
---

# «Empezar desde cero» sin red sigue sin borrar, y encima queda apuntado para un borrado peor

## El síntoma, en lenguaje de usuario

Estoy activando Yala completo, he visto mis datos viejos y he tocado «Empezar desde cero». La app va a
comprobar qué hay en mi iCloud y **se cae la red**. Me dice «No pudimos revisar tu iCloud» y me ofrece
«Seguir así». Sigo… y mis datos viejos están todos ahí. Nadie borró nada, aunque yo lo confirmé.

## Lo medido (2026-09-14, en el PR que cierra `activation-restore-start-fresh-keeps-the-imported-rows`)

- Tres salidas de `WelcomePrivateICloudGateView` llaman a `onProceed()` **sin pasar por `performWipe`**:
  `continueWithoutValidating()` (`:479-483`, el botón de `.noICloud` y la acción secundaria de
  `.unreachable`), `case .proceed` (`:586-593`) y el atajo de `isUITesting` (`:553-556`).
- En la puerta del chooser (`.privateGate`) eso es un daño menor: se llega **antes** del relanzamiento y
  el corpus todavía no ha bajado al teléfono. En `.restoreDiscardGate` no: ahí **hubo relanzamiento**, el
  store espeja, y las filas importadas ya están en el dispositivo. Es el bug del ticket padre por otra
  rama, bajo un copy que promete lo contrario.
- **Y el daño encadenado es peor que el hueco.** `continueWithoutValidating` escribe
  `markPrivateChoseWithoutICloud()`. Cuando la activación termine y la sesión sea privada,
  `runLateICloudMirrorCheck` ofrecerá el aviso del espejo tardío, cuyo borrado es
  `performICloudCorpusWipe(.handover)` (`ContentView.swift:330`) — preferencias, purga del dominio de
  Grupos y `hasCompletedOnboarding = false`. O sea: el scope que el ticket padre argumenta que **no**
  puede aplicarse a quien acaba de activar conservando sus grupos.
- `.noICloud` es inalcanzable por este camino (para llegar hubo que encontrar corpus en iCloud). El caso
  real es `.unreachable`: la red se cae en la ventana entre el relanzamiento y la sonda.

## Qué hay que decidir

1. ¿Qué se le ofrece a quien confirmó «empezar de cero» y no se pudo preguntar a iCloud? Las tres
   opciones razonables: **(a)** devolver a Restaurar sin declarar nada (no se promete un borrado que no
   ocurrió); **(b)** borrar solo lo local, que sí está aquí, y dejar la zona para el aviso tardío;
   **(c)** dejarlo como está y avisar con copy honesto.
2. Si se elige (b) o (c): el aviso del espejo tardío tiene que dejar de usar `.handover` para quien salió
   por aquí, o se llevará los grupos.

## Criterios de aceptación

- [ ] Tras confirmar «Empezar desde cero» sin red, la app **no declara** un borrado que no ocurrió.
- [ ] El aviso del espejo tardío que llegue después **no purga el dominio de Grupos** de quien activó
      conservándolos.

## Relacionados

- [[activation-restore-start-fresh-keeps-the-imported-rows]] — el ticket padre, cerrado el 2026-09-14.
- [[private-gate-remote-wipe-can-strand-its-arm]] — la otra familia de residuales de esta puerta.
