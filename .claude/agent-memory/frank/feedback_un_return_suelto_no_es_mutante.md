---
name: un-return-suelto-no-es-mutante
description: Mutar con `return` al principio de una función Void falla si la línea siguiente es un switch/if expresión — Swift lo toma como su argumento y lo ejecuta.
metadata:
  type: feedback
---

Un mutante «`return // MUTANTE`» encima de un `switch` NO desactiva nada: Swift 5.9+ lee `return` + `switch` de la línea
siguiente como `return switch …` y lo ejecuta. El test salió verde «con el bug dentro» y casi lo doy por no
discriminante (2026-11-06, lote UI 2.3, bienvenida de Grupos). Con `if UITestHooks.isActive { return }` cayó en rojo.

**Why:** costó dos reescrituras del XCUITest buscando por qué no discriminaba, cuando el que no mutaba era el mutante.

**How to apply:** muta con un `if cond { return }` o comentando el cuerpo, nunca con un `return` suelto delante de un
`switch`/`if`. Si un test sale verde con el mutante, revisa primero que el mutante compile a lo que crees.
