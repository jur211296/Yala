---
id: finish-halfway-wipe-early-failure-shows-no-feedback
status: backlog
priority: low
area: "modo-nube"
created: 2026-09-26
source: "review adversarial de `late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed` (2026-09-26)"
---

# Si «Terminar de borrar» falla pronto, la pantalla vuelve igual y no dice que lo intentó

## El problema, en lenguaje de usuario

En «El borrado quedó a medias», la persona pulsa «Terminar de borrar», confirma, ve el progreso y vuelve a la misma
pantalla sin ningún mensaje. Pasa cuando el reintento falla antes de llegar a iCloud (sin red, o con iCloud todavía
importando). Parece que el botón no hizo nada.

## Lo medido (2026-09-26, leyendo código)

`classifyLateWipeFailure` devuelve `.leftHalfway` también sin `zoneDone` si el borrado ya estaba a medias, y es lo
correcto para el estado: iCloud sigue vacío. Lo que falta es feedback del intento. Es el mismo molde que «Volver a
intentarlo» en `.failed`, que tampoco distingue un segundo fallo del primero.

## Por dónde va

Una línea de estado bajo el cuerpo («No pudimos terminar. Revisa tu conexión.») cuando la fase se re-entra desde
`.wiping`. Decisión de copy.
