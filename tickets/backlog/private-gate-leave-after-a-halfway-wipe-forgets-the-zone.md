---
id: private-gate-leave-after-a-halfway-wipe-forgets-the-zone
status: backlog
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

- [ ] Tras salir de un borrado a medias en la puerta, algo recuerda que iCloud quedó vacío y lo del teléfono no.
- [ ] Ningún remedio ofrece a quien activa Yala completo un borrado que purgue sus grupos.
- [ ] Si la puerta vuelve a medir y no queda nada a medias, la marca se va.

## Relacionados

- [[private-gate-wipe-failure-copy-claims-icloud-is-intact]] — el copy del mismo estado.
- [[late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed]] — el desarme del aviso tardío.
- [[discard-gate-proceed-leaves-the-imported-rows-behind]] — la salida `.proceed` de la puerta de la activación.
