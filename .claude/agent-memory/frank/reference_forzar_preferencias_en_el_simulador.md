---
name: forzar-preferencias-en-el-simulador
description: Receta medida para escribir UserDefaults de Yala en el simulador sin -uitest (estados de días: Nº de registros, fechas, pasos) — cfprefsd y la trampa de plutil con claves con puntos
metadata:
  type: reference
---

Para auditar lo que se oculta bajo `-uitest` (tips, «Primeros pasos», banners) hay que conducir la app SIN `-uitest`
y forzar los estados escribiendo sus preferencias. Medido el 2026-10-14 (lote 5 de la auditoría UX 2.2):

1. `xcrun simctl terminate` de la app.
2. Matar el `cfprefsd` del runtime: `pgrep -f "simruntime/Contents/Resources/RuntimeRoot/usr/sbin/cfprefsd"` + `kill`.
   Sin esto, al relanzar la app recibe el valor viejo de su caché y lo reescribe encima.
3. Escribir el plist del contenedor (`simctl get_app_container … data` + `Library/Preferences/<bundle>.plist`) con
   **`plistlib` de Python**. `plutil -replace setup.step.1.completed` interpreta los puntos como keypath y crea
   diccionarios anidados: la app no ve nada y no da error.
4. `xcrun simctl spawn … defaults write <dominio>` no sirve: escribe fuera del contenedor.

Teclear: `axe type` deja de entrar en los campos de importe a ratos; `type_text` de XcodeBuildMCP sí entra, pero deja
el simulador en modo teclado físico (`erase` antes de XCUITest, `.claude/rules/testing.md`).

Relacionado: [[maqueta-de-variantes-por-xcuitest]], [[capturas-sobreviven-en-worktrees-capturas]].
