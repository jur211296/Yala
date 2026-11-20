---
name: reproducir-el-cierre-privado-en-el-simulador
description: Cómo hacer que el simulador (sin iCloud) enseñe la cifra «Cambios por subir» del cierre privado y contar qué escribió la app, con sqlite sobre el historial
metadata:
  type: reference
---

El simulador no tiene iCloud, así que el cierre privado nunca ve un export y su contador da «no se puede contar» (sin cifra).
Para ver la cifra que ve un iPhone que ya usó iCloud (19-nov, card del «893»):

- **Ancla a mano**: con la app cerrada, `xcrun simctl spawn <udid> defaults write com.jurgenschmidt.yala.dev
  cloudSync.confirmedExportStartedAt -float <epoch anterior al alta>`. Al cerrar sesión sale «Cambios por subir: N» y a
  los 45 s el aviso de pérdida.
- **Qué escribió la app**: el store vive en el App Group (`simctl get_app_container <udid> com.jurgenschmidt.yala.dev
  groups` → `Library/Application Support/YalaModel-Dev.store`). `ACHANGE` × `Z_PRIMARYKEY` da objetos por entidad y tipo
  (0 alta, 1 cambio, 2 borrado); `ACHANGE.ZCOLUMNS` dice qué columna, y la fila (`Z<ENTIDAD>.Z_PK = ZENTITYPK`) cuál.
- El alta en iCloud privado desde el Welcome con Device MCP: «Entrar con iCloud privado» → «Seguir así» → reabrir (simctl
  terminate + launch) → chat (nombre, moneda, tipo) → «Entrar a Yala». `type_text` de Device MCP no dejó
  `HardwareKeyboardLastSeen` en el simulador (medido ese día), a diferencia de axe y XcodeBuildMCP.

Relacionado: [[el-ancla-que-no-existe]].
