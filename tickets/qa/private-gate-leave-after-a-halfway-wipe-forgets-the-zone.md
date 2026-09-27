---
id: private-gate-leave-after-a-halfway-wipe-forgets-the-zone
status: qa
updated: 2026-09-27
priority: medium
area: "onboarding, modo-nube"
created: 2026-09-27
source: "encargo de `private-gate-wipe-failure-copy-claims-icloud-is-intact` (2026-09-27), punto 4; aparcado por alcance. Inferido por lectura, NO reproducido"
---

# Salir de la puerta tras un borrado a medias olvida que iCloud ya está vacío

## El síntoma, en lenguaje de usuario

Confirmo que quiero borrar mis datos de iCloud. Se borra iCloud, pero falla a mitad de lo del teléfono. La pantalla ya
me lo dice bien (desde `private-gate-wipe-failure-copy-claims-icloud-is-intact`). Toco «Dejarlo por ahora». A partir
de ahí la app no recuerda que iCloud quedó vacío con lo del teléfono dentro, y nada me lo vuelve a preguntar.

## Lo medido (2026-09-27, leyendo código)

- `WelcomePrivateICloudGateView.leaveGate()` retira el arm con `clearICloudCorpusWipeArm()` desde `.wipeFailed`, con la
  zona ida o sin tocar. Esa función borra también `icloudCorpusWipeZoneDone`.
- El aviso tardío, en el mismo estado, usa `disarmFailedICloudCorpusWipe()`: con la zona ida escribe «a medias»
  (`leaveICloudCorpusWipeHalfway`) y el arranque pregunta con «El borrado quedó a medias».

## Por qué no se copió ese desarme en la puerta

El remedio de «a medias» es el aviso tardío, y su «Terminar de borrar» corre `performICloudCorpusWipe(.handover)`: purga
el dominio de Grupos y las preferencias. Los tres montajes de la puerta no piden lo mismo:

| Montaje | Borrado de la puerta | ¿Vale `.handover` para terminarlo? |
|---|---|---|
| Welcome, «Es mi primera vez → privado» | `.handover` | Sí, es el mismo borrado |
| Activación, puerta privada | `.zoneOnly` | No borra filas; no llega a «a medias» |
| Activación, «Restaurar → Empezar desde cero» | zona + filas importadas | **No**: purgaría los grupos de quien activa para conservarlos |

Y en el Welcome la puerta ya re-detecta parte del estado: si la persona vuelve a elegir privado, la puerta mide y
encuentra las filas del teléfono (`foundDeviceData`). Lo que se pierde es el resto de salidas (nube, restaurar). Cada
una necesita decidir qué hace con la marca, y `measure()` en `.proceed` tendría que retirarla solo donde mide el
teléfono (el Welcome) y no donde `deviceCorpus` es `nil`.

## Qué hay que decidir

1. ¿La puerta del Welcome escribe «a medias» al salir de `.wipeFailed(zoneGone: true)`? Si sí, quién la retira en cada
   salida del chooser.
2. ¿Qué hace la puerta de la activación con ese estado? Opción: una marca propia con un remedio de su alcance, no el
   aviso tardío.

## Criterios de aceptación

- [x] Tras salir de un borrado a medias en la puerta, algo recuerda que iCloud quedó vacío y lo del teléfono no.
- [x] Ningún remedio ofrece a quien activa Yala completo un borrado que purgue sus grupos.
- [x] Si la puerta vuelve a medir y no queda nada a medias, la marca se va.

## Relacionados

- [[private-gate-wipe-failure-copy-claims-icloud-is-intact]] — el copy del mismo estado.
- [[late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed]] — el desarme del aviso tardío.
- [[discard-gate-proceed-leaves-the-imported-rows-behind]] — la salida `.proceed` de la puerta de la activación.

## Resuelto (2026-09-27)

**Qué cambia para quien usa la app.** Si el borrado de iCloud falla después de vaciar iCloud y la persona sale:

- **En «Es mi primera vez → privado»**, la app lo recuerda. Al abrirla ya dentro, pregunta «El borrado quedó a medias»:
  quedarse con lo que hay o terminar de borrar. Si en vez de eso elige «Restaurar», no se le pregunta: ya eligió quedarse
  con lo que hay.
- **En «Activar Yala completo → Restaurar → Empezar desde cero»**, al volver a tocar «Empezar desde cero» con iCloud
  vacío, la puerta termina de borrar lo que bajó de iCloud en vez de seguir al onboarding con esos datos dentro. Sus
  grupos y su nombre no se tocan.
- **En la puerta privada de la activación** no cambia nada: ese borrado es solo de iCloud y nunca queda a medias.

**Qué se tocó.**

- `WelcomePrivateICloudGateView`: parámetro `halfwayWipe` sin default y un solo `disarm()` para las salidas. `measure()`
  con iCloud vacío retira la marca donde midió el teléfono, o termina el borrado en «Empezar desde cero». Un borrado que
  termina bien retira la marca donde toca filas. El copy del fallo suma la marca previa.
- `WelcomePrivateICloudGateLogic`: `HalfwayWipe`, `afterEmptyMeasure`, `failureFoundZoneGone`, y `lateWipeLaunch` con
  `storageMode` (en `.cloud` retira la marca sin preguntar).
- Montajes (`WelcomeFlowContainer`, `FullModeActivationView`), `completeFullActivation` (retira la marca antes de declarar
  la sesión privada), `startFreshPrivateOnboarding` (la retira con el teléfono vacío) y el portal de «Restaurar» del Welcome.
- Regla nueva en `.claude/rules/swiftdata-cloudkit.md` y docblock de la marca al día.

**Decisiones asumidas** (encargo en modo autónomo): una sola marca para los dos montajes que la dejan; «Empezar desde
cero» termina sin tercera confirmación (la persona ya confirmó dos veces el mismo alcance y vuelve a pulsar el botón, que
pasa por su propio diálogo); terminar al volver cuenta también la marca de la zona sin «a medias» (kill justo tras la zona).

**Verificado.** `PrivateGateHalfwayWipeTests` (lógica, marcas y cableado de los tres montajes) y la tabla del arranque en
`LateICloudWipeLeftHalfwayLogicTests`. 18 mutantes, todos muertos. Review adversarial de tres lentes: dos hallazgos
medios aplicados (el kill tras la zona en «Empezar desde cero», «Restaurar» en el Welcome) y dos preexistentes a backlog.

**Fuera de alcance, en backlog.**

- `private-gate-back-from-found-keeps-a-resumed-arm`: volver desde «Encontramos datos» tras un corte deja el borrado
  armado, y en modo nube el arranque lo termina a ciegas.
- `activation-private-gate-leaves-a-late-notice-that-purges-groups`: activar sin poder mirar iCloud deja un aviso tardío
  cuyo borrado purga los grupos.
- El hermano `discard-gate-proceed-leaves-the-imported-rows-behind` sigue abierto para iCloud vaciado desde otro
  dispositivo; el caso del borrado a medias ya lo cubre este ticket.

## Guion de device-QA (opcional)

El fallo con iCloud ya vacío **no se puede provocar a mano** (exige que falle el borrado local a mitad). Lo que se puede
mirar es que el camino de siempre no cambió:

1. iPhone con datos de Yala en iCloud. Borra la app e instálala desde TestFlight.
2. Abre Yala → «Es mi primera vez» → «Privado». Sale «Encontramos datos tuyos en iCloud».
3. Toca «Empezar de cero», confirma, y **justo al confirmar activa el modo avión**.
4. Esperado: «No pudimos borrar todo» con «Tus datos siguen en iCloud, intactos». Toca «Dejarlo por ahora».
5. Quita el modo avión, elige otra vez «Privado»: vuelve a salir «Encontramos datos tuyos en iCloud». Nada se borró.
