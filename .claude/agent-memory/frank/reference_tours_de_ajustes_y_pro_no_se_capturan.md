---
name: tours-de-ajustes-y-pro-no-se-capturan
description: Guías, tours y avisos que -uitest calla se capturan reales recorriendo la bienvenida en el simulador sin iCloud: iCloud privado → «Seguir así» → relanzar.
metadata:
  type: reference
---

Medido el 2026-11-20 (maquetas de Primeros pasos, simulador de la Max): `ProfileView` calla el tour de Ajustes y el
tour Pro con `guard !UITestHooks.isActive`, el Panel calla su guía, el empujón y Siri igual, y no hay atajo `-uitest-*`
que los muestre. Sin `-uitest`, Yala Dev abre la bienvenida.

**Corrección del mismo día (sesión «Solo gastos» + Panel progresivo):** la bienvenida real SÍ se recorre sin cuenta de
iCloud. «Entrar con iCloud privado» → «Este dispositivo no tiene iCloud activo» → «Seguir así» → «Un último paso:
reabre Yala» → `simctl terminate` + `launch` → chat (nombre, «Soles», modo) → «Entrar a Yala». Así salen todos los
intrusos reales (guía «Este es tu resumen», oferta Pro, tour «Tus cuentas · 1 de 3»). Para el «antes», `git archive`
de la base en una carpeta aparte y `simctl uninstall` + `install` entre pasadas (ver [[antes-del-iphone-con-git-archive]]).

**How to apply:** para capturar o verificar lo que un usuario nuevo ve de verdad, recorre la bienvenida así en vez de
recrear sobre capturas. Teclear el nombre con Device MCP deja el simulador en modo teclado físico: `simctl erase` antes
de volver a XCUITest. Y tras cerrar el presupuesto o el pago de Primeros pasos, su guía de Más sale a los 0,7 s: un toque
rápido la cierra y parece un toque muerto.
Relacionado: [[axe-primer-toque-y-mazo-en-un-paso]].
