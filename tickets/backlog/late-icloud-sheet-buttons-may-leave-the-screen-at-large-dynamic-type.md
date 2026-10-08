---
id: late-icloud-sheet-buttons-may-leave-the-screen-at-large-dynamic-type
status: backlog
priority: low
area: "modo-nube, a11y"
created: 2026-09-26
updated: 2026-10-08
source: "review adversarial de `late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed` (2026-09-26)"
---

# La hoja del aviso tardío de iCloud puede quedarse sin botones con el texto muy grande

## El problema, en lenguaje de usuario

Con el tamaño de texto de accesibilidad al máximo, y en idiomas largos (alemán), el cuerpo de las pantallas de
`LateICloudMirrorNoticeView` puede empujar los dos botones fuera de la pantalla. Solo quedaría «Cerrar», que es «luego»:
la pantalla de «El borrado quedó a medias» vuelve en cada arranque y la persona no podría decidir nunca.

## Lo medido (2026-09-26)

**No demostrado**: leído en código, no visto en el simulador. `noticeBody` pone el texto con
`fixedSize(horizontal: false, vertical: true)` dentro de un `VStack` sin `ScrollView`. El patrón ya existía en las
fases anteriores; la fase nueva lo agrava porque se presenta sola en el arranque.

## Por dónde va

Medirlo en el pase de estrés (iPhone más pequeño, Dynamic Type máximo, alemán). Si se confirma, envolver el contenido en
un `ScrollView` con los botones fuera.

## Medido en 2.1 (triage 2026-10-08)

- `noticeBody` sigue igual: título y cuerpo con `.fixedSize(horizontal: false, vertical: true)` y los botones en el mismo `VStack`; no hay ningún `ScrollView` en `LateICloudMirrorNoticeView.swift`. Sigue pendiente de verlo en el pase de estrés (iPhone pequeño, Dynamic Type máximo, alemán).

Triage 2026-10-08: abierto · low → low · `LateICloudMirrorNoticeView.noticeBody` sigue siendo un `VStack` con `fixedSize` y sin `ScrollView` en todo el fichero; sin medir en el pase de estrés.
