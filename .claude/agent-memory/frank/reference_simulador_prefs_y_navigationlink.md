---
name: simulador-prefs-y-navigationlink
description: Dos trampas del simulador medidas el 2026-10-17 con iOS 27.0: cómo forzar una preferencia de la app, y que axe no abre un NavigationLink dentro de una hoja
metadata:
  type: reference
---

- **Forzar una preferencia de la app:** `simctl spawn <U> defaults write <bundle> …` escribe en el dominio global del
  simulador, no en el contenedor de la app, y la app no lo ve. Editar la plist del contenedor con la app parada
  tampoco basta: cfprefsd la tiene en caché y la pisa al guardar. Lo que funciona: `simctl shutdown`, editar
  `<data>/Library/Preferences/<bundle>.plist` con `plistlib` y `simctl boot`. Ver [[conducir-simulador-con-axe]].
- **`axe` no abrió un `NavigationLink` dentro de una hoja** (la fila «Moneda» de Nueva cuenta), ni por id, ni en
  físico, ni con touch. XCUITest sí lo abre. Para afirmar que esa navegación funciona, XCUITest.
- **El centro muerto de una fila con `Spacer` sin `contentShape`** (`swiftui-ds.md`) también cae en XCUITest, que
  toca en el centro. Antes de culpar a la herramienta, mira el label.
