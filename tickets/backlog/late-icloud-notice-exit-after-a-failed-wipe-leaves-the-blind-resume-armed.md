---
id: late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed
status: backlog
priority: medium
area: "groups, modo-nube"
created: 2026-09-26
source: "review adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently` (2026-09-26)"
---

# Salir del aviso del espejo tardío tras un borrado fallido deja armada la reanudación a ciegas

## El problema

En `LateICloudMirrorNoticeView`, la fase `.failed` sale con «Dejarlo por ahora» (`dismiss()`) o con «Cerrar» en la
barra (`onKeep()` + `dismiss()`). Ninguna retira el arm (`StorageModePersistence.armICloudCorpusWipe`). En el arranque
siguiente, `ContentView.runLateICloudMirrorCheck` ve el arm y reanuda `performICloudCorpusWipe(.handover)` a ciegas,
sin pantalla. Borra la zona de iCloud, las filas personales y el dominio de Grupos, aunque la persona dijo «déjalo
así». El comentario de la fase promete lo contrario: «el aviso vuelve en el próximo arranque».

## Lo medido (2026-09-26)

Lo encontraron dos lentes de la review de `fresh-start-wipe-kills-unsent-group-writes-silently`, leyendo el código.
Ese ticket lo cerró para su fase nueva (`.groupsPending`), donde no se había borrado nada, así que desarmar era seguro.
En `.failed` NO lo es sin más: el fallo puede llegar después de borrar la zona, y el arm es lo que termina un borrado
a medias. Por eso no se tocó.

## Por dónde va

Distinguir el fallo antes de la zona del fallo después. Solo desarmar el primero, y en el segundo decirle a la
persona que el borrado quedó a medias en vez de reanudarlo en silencio.
