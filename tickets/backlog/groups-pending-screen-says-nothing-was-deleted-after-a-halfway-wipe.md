---
id: groups-pending-screen-says-nothing-was-deleted-after-a-halfway-wipe
status: backlog
priority: low
area: "groups, modo-nube"
created: 2026-09-26
source: "review adversarial de `late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed` (2026-09-26)"
---

# «Faltan cambios de grupos» dice «No borramos nada» cuando iCloud ya se había borrado

## El problema, en lenguaje de usuario

Un borrado del aviso de «Encontramos datos tuyos en iCloud» queda a medias: iCloud ya se borró y el teléfono no. La
persona pulsa «Terminar de borrar», pero antes hay cambios de grupos sin subir y la subida se para. Sale la pantalla de
«faltan cambios de grupos», cuyo texto (`groups.freshStartPending.lead`) dice que no se borró nada. No es verdad: lo de
iCloud ya no está.

## Lo medido (2026-09-26, leyendo código)

`WelcomePrivateICloudGateLogic.classifyLateWipeFailure` da prioridad a los grupos pendientes, porque su pantalla es la
que explica qué falta subir. El estado durable queda bien (`disarmFailedICloudCorpusWipe` conserva «a medias» y el
arranque vuelve a preguntar); lo que miente es el copy de esa fase en esta combinación. Alcanzable solo si entre el
fallo y «Terminar de borrar» se apuntó un cambio de grupo sin red. No se tocó porque el encargo prohibía cambiar
`.groupsPending`.

## Por dónde va

Un cuerpo alternativo para `.groupsPending` cuando `isICloudCorpusWipeLeftHalfway()`, o una línea más que diga que lo
de iCloud ya se borró. Decisión de copy.
