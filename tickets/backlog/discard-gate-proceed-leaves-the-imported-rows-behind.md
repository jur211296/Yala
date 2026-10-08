---
id: discard-gate-proceed-leaves-the-imported-rows-behind
status: backlog
priority: low
area: "onboarding, modo-nube"
created: 2026-09-14
source: "review adversarial del PR de `activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable` (3 lentes, 2026-09-14); NO reproducido en device"
updated: 2026-10-08
---

# Si la zona se vacía sola, «Empezar desde cero» sale sin llevarse las filas que ya bajaron

## El síntoma, en lenguaje de usuario

Estoy activando Yala completo. Traigo mis datos de iCloud, los veo, y decido «Empezar desde cero». La app
mira mi iCloud y lo encuentra **vacío** —porque otro teléfono mío acaba de vaciarlo, o la zona se borró
por su cuenta—. Como no hay nada que borrar allí, sigue al onboarding… y **los datos que ya bajaron siguen
en este teléfono**, y el espejo los vuelve a subir.

## Lo medido (2026-09-14)

- `WelcomePrivateICloudGateView.measure()`, rama `case .proceed`: `discardPendingWipe()` + `onProceed()`.
  No hay borrado de ningún tipo — es correcto para la puerta del chooser, donde no hay nada que borrar.
- En `.restoreDiscardGate` no lo es: a esa puerta se llega **después** del relanzamiento, con el store
  espejando y las filas importadas ya en el dispositivo.
- Y contradice la justificación escrita del `deviceCorpus: nil` de ese montaje
  (`FullModeActivationView.swift`): *«lo que hay en el teléfono vino de iCloud … se lo lleva este mismo
  borrado»*. En la rama `.proceed` no hay ningún borrado que se lo lleve.
- **Alcance real: estrecho.** Para llegar a `.restore` en la activación iCloud tuvo que contestar CON
  datos (el chooser de la activación solo tiene «privado» y «nube»; `.restore` sale de `onRestore`, que
  solo se ofrece en `.found`). Que la sonda encuentre la zona vacía después exige que otro dispositivo la
  haya vaciado en esa ventana, o un `.userDeletedZone`.

## Por qué NO se arregló con el ticket padre

El ticket padre lo cierra la decisión (a) de Jürgen —«devolver a Restaurar sin declarar ningún borrado»—
y esa decisión es sobre **no poder preguntar**. Aquí a iCloud sí se le preguntó y contestó, así que no hay
ningún borrado declarado que incumplir: el desenlace correcto no es volver atrás, es **borrar lo local**.
Es otra política y por eso es otro ticket.

## Qué hay que decidir

¿La rama `.proceed` de `.restoreDiscardGate` borra las filas locales antes de salir? Opciones: contar el
corpus local en esa rama (le devuelve a la puerta el `deviceCorpus` que hoy es `nil` a propósito), o
llamar a `performWipe` igualmente — que con la zona vacía solo borraría las filas.

## Criterios de aceptación

- [ ] Tras confirmar «Empezar desde cero» y medir el iCloud vacío, el onboarding de la activación no
      arranca encima de las filas que el espejo ya había importado.
- [ ] El dominio de Grupos y las preferencias de quien activa siguen intactos (el scope sigue siendo
      `.importedRows`, nunca `.handover`).

## Relacionados

- [[activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable]] — el ticket padre.
- [[activation-restore-start-fresh-keeps-the-imported-rows]] — el abuelo, que creó esta puerta.

## Añadido 2026-09-27 (`private-gate-leave-after-a-halfway-wipe-forgets-the-zone`)

El caso más probable de «zona vacía con las filas importadas dentro» era el borrado de esta misma puerta que falla (o
un corte) después de vaciar iCloud. Ese ya no sigue al onboarding: con la marca «a medias» o la de la zona puesta, la
rama `.proceed` termina el borrado `.importedRows` (`HalfwayWipe.finishOnReentry`). Queda abierto lo de este ticket:
iCloud vaciado desde otro dispositivo, sin ninguna marca en este.

## Medido en 2.1 (triage 2026-10-08)

- En `WelcomePrivateICloudGateView.measure()`, rama `.proceed`, `WelcomePrivateICloudGateLogic.afterEmptyMeasure` solo termina el borrado (`.finishHalfwayWipe`) con la marca «a medias» o la de la zona puestas; sin marcas sale por `.proceed(retiresHalfway: false)` → `discardPendingWipe()` + `onProceed()`, sin borrar las filas importadas.
- Es exactamente el resto que deja abierto el añadido del 2026-09-27: iCloud vaciado desde otro dispositivo, sin marcas en este.

Triage 2026-10-08: abierto · low → low · sin marcas, la rama `.proceed` de la puerta sigue saliendo sin borrar las filas importadas; exige que otro dispositivo vacíe iCloud en esa ventana y no pierde datos.
