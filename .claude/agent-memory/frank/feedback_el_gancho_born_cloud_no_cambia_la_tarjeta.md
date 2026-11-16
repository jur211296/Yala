---
name: el-gancho-born-cloud-no-cambia-la-tarjeta
description: -uitest-born-cloud-storage engaña al controlador, no a la tarjeta de estado; para capturar la nube de verdad, añade -cloudSync.storageMode cloud
metadata:
  type: feedback
---

Con `bornCloudStorage: true` (o `cloudProgress` de la vuelta), «Dónde viven tus datos» pinta los botones de la nube pero la
tarjeta de arriba sigue en «iCloud privado» y Grupos ofrece «Asociar»: la tarjeta lee `CloudSyncFlags.storageMode`, que el
gancho no toca. Medido el 9-nov-2026 en capturas de la zona 41. Lanzando además con
`extraArguments: ["-cloudSync.storageMode", "cloud"]` (dominio de argumentos: no persiste) y `cloudSession: true`, sale
«Tu cuenta en la nube» y «Tus grupos usan esta misma cuenta».

**Why:** una captura con la tarjeta contradiciendo al resto parece un bug de la app y lleva a afirmarlo en una revisión.
**How to apply:** antes de citar algo raro de una captura hecha con un gancho, mira qué lee la vista y qué finge el gancho;
si no casan, fija también la preferencia por argumento. Relacionado: [[forzar-una-preferencia-en-un-lanzamiento]].
