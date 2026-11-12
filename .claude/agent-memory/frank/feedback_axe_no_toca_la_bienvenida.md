---
name: axe-no-toca-la-bienvenida
description: En el iPhone 17 Pro (iOS 27.2) los toques de axe no avanzan la bienvenida ni el alta; los de XcodeBuildMCP sí
metadata:
  type: feedback
---

El 12-nov, `axe tap` (por id y por coordenadas) no hacía nada en «Empezar» de la bienvenida ni en «Siguiente» del
alta; `tap` de XcodeBuildMCP (snapshot_ui + elementRef) sí avanzó. Device MCP estaba ocupado por otra sesión (la
versión gratis solo admite un espejo).

**Why:** costó varios intentos antes de cambiar de herramienta.
**How to apply:** para el «antes» de una pantalla tras el alta, fuerza el estado por plist (`hasCompletedOnboarding`,
`setup.isNewInstall`, ver [[forzar-preferencias-en-el-simulador]]) y lanza sin `-uitest`; si hay que tocar, XcodeBuildMCP.
`type_text` deja el teclado físico: `simctl erase` antes de XCUITest.
