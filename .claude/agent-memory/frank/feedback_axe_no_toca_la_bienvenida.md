---
name: axe-no-toca-la-bienvenida
description: En el iPhone 17 Pro (iOS 27.2) los toques de axe no avanzan la bienvenida ni el alta; en la vitrina tampoco los de XcodeBuildMCP: veredicto por XCUITest
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

**20-nov, la vitrina del Welcome:** el toque por mitades (`onTapGesture` de la caja) no recibió NINGÚN toque de `axe tap`
ni del `tap` de XcodeBuildMCP (con sonda `NSLog`: cero llamadas), y sí los de XCUITest por coordenada
(`WelcomeCarruselToqueUITests`, verde 2/2). Los `Button` de dentro (pausa, barras) sí respondían a axe. Y
`snapshot_ui`/`axe describe-ui` devolvían un árbol viejo mientras la vitrina rotaba: el veredicto, por captura o XCUITest.
Un `print` no sirve de sonda ahí: va al stdout con búfer y no llega al log; `NSLog` sí.
**How to apply (vitrina):** para medir o grabar el toque, un XCUITest con `simctl io recordVideo` alrededor.
