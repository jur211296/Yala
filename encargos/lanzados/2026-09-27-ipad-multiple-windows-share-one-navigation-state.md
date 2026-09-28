# Fase 0 del carril adaptativo: cerrar el ticket ipad-multiple-windows-share-one-navigation-state

## Contexto
Yala es una app universal SwiftUI. El PR #285 (mergeado a 2.1) dejó el plan vigente del carril adaptativo iPad / iPhone Duo / mejoras de iPhone en `docs/exploracion/adaptativo-ipad-duo.md`, con 13 fases en serie. Esta es la fase 0 y va primera por fecha: desde el 23-oct-2026 el iPhone Duo hereda la multiventana del iPad (tech talk de Apple citado en el ticket), y hoy dos ventanas de Yala comparten un solo estado de navegación (`SessionState.shared`, un solo `AppRouter`). Lee el ticket `tickets/backlog/ipad-multiple-windows-share-one-navigation-state.md` y el plan antes de empezar.

Este carril corre EN PARALELO a Cola A: hay otra sesión de Claude viva en otro worktree (`Yala--late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`) usando sus propios simuladores. No la toques ni toques sus ficheros.

Decisiones ya tomadas por Jürgen / plan, no se reabren:
- Enfoque Apple-nativo (§5.1 aprobado).
- iPhone en horizontal: SÍ, opción A, pero tras la fase 1. No entra en esta fase.
- Xcode 27.1 beta (simulador Duo) queda aparcado a Jürgen por espacio en disco (ticket `xcode-27-1-with-the-iphone-duo-simulator`). No bloquea esta fase; no lo instales. Gate y release siguen en Xcode 27.0.

## Que se pide
Lo que dice el ticket: comprobar en simulador lo que se pueda del fallo de navegación compartida y, salvo que la evidencia diga claramente que no hay fallo, apagar la multiventana con `INFOPLIST_KEY_UIApplicationSupportsMultipleScenes = NO` en los build settings del target `Yala` (Debug y Release). Verificar con `plutil` que el `Info.plist` compilado pasa de `true` a `false`. Si puedes manejar el simulador, intentar abrir una segunda ventana en `YalaLane-Adapt-iPad-Pro-13` y confirmar que ya no aparece; si no, el ticket va a `qa` con el guion de iPad real para Jürgen. Deja claro en el ticket y en el plan que se vuelve a encender en `ipad-real-multiwindow-with-per-scene-state`.

## Que NO hay que tocar
- Ningún cambio de UI ni de layout: eso es de la fase 1 en adelante.
- Nada de Cola A ni de ficheros de sync/nube.
- No instalar Xcode 27.1 ni tocar el Xcode activo.
- `marketing/` no se toca.

## Reglas del carril adaptativo (obligatorias)
Simulador (Jürgen, 27-sep): usa solo simuladores dedicados con prefijo `YalaLane-Adapt-` (créalos con `xcrun simctl create` si no existen: al menos `YalaLane-Adapt-iPad-Pro-13` y un iPhone del carril), SIEMPRE por UDID (`-destination id=<UDID>`), nunca por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar cualquier otro simulador. DerivedData propia del worktree (`-derivedDataPath` dentro del worktree).

## Como se sabe que esta bien
- `Info.plist` compilado para `YalaLane-Adapt-iPad-Pro-13` con `UIApplicationSupportsMultipleScenes = false`.
- XCUITest de navegación en verde en el iPad y el iPhone del carril, por UDID. Gate verde (UI tests del CI son advisory; contrasta con la base si fallan por el patrón flaky conocido).
- Ticket movido (done si verificado en simulador; `qa` con guion si falta iPad real) y `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Es de noche (21:00–6:00 Lima): no uses AskUserQuestion; elige la opción recomendada y, si algo es demasiado importante para asumirlo, abre ticket propio y aparca. Sin «¿Sigo?» ni gate por número de ficheros. Haz gate, commit, PR contra 2.1, merge, actualiza `tickets/` y `docs/TICKETS.md`, y termina con `/cerrar-total`. Bugs o decisiones nuevas de camino van a ticket propio antes de cerrar. No sync al Kanban del panel.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR o dejaste artifact listo; (3) terminaste el ticket y vas a /cerrar-total, con un resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por un test rojo que vas a reclasificar, un build que vas a reintentar ni ruido de CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** El target `Yala` tiene **cuatro** configuraciones (`Debug`, `Release`,
`Debug-Dev`, `Release-Dev`), no dos. El build «antes» en `YalaLane-Adapt-iPad-Pro-13` da
`UIApplicationSupportsMultipleScenes => true`. Sigue habiendo un solo `WindowGroup`, ni `@SceneStorage` ni
`openWindow` en `Yala/`, y `SessionState.shared` / `AppRouter.shared` son singletons de proceso.

**D1 · ¿En qué configuraciones va `INFOPLIST_KEY_UIApplicationSupportsMultipleScenes = NO`?** → En las cuatro del
target `Yala`. Por qué: `Yala Dev` compila con `Debug-Dev`/`Release-Dev`; dejarlas fuera deja la multiventana
rota en las builds Dev que se prueban. Alternativa descartada: solo `Debug`/`Release`, como dice el ticket
(premisa medida y corregida).

**D1-bis · La receta del ticket no hace nada (medido).** `INFOPLIST_KEY_UIApplicationSupportsMultipleScenes = NO`
en las cuatro configuraciones compiló y el plist siguió en `true`: el `CoreBuildSystem.xcspec` de Xcode 27.0 solo
define `INFOPLIST_KEY_UIApplicationSceneManifest_Generation`, que siempre escribe un manifiesto multiventana. →
`INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO` en las cuatro y el manifiesto explícito
(`UIApplicationSupportsMultipleScenes = false`, `UISceneConfigurations` vacío, la misma forma que generaba Xcode) en
`Yala/Resources/Info.plist`, que es el `INFOPLIST_FILE` de las cuatro. Por qué: es la única vía que cambia el plist
compilado. Alternativa descartada: dejar `_Generation = YES` y superponer la clave en el fichero, con dos fuentes
declarando el mismo manifiesto.

**D2 · ¿Cómo se comprueba el fallo sin Simulator.app?** → Una sonda temporal (DEBUG, tras un argumento de
lanzamiento) que pide una segunda escena con `requestSceneSessionActivation` y cuenta `connectedScenes`, antes y
después del cambio. No se commitea. Por qué: es lo único que mide en simulador si el sistema abre la segunda
ventana, sin interfaz gráfica. Alternativa descartada: dar la evidencia de código por suficiente sin medir.

**D3 · ¿Criterio para apagar?** → Se apaga salvo que la sonda diga que el sistema no abre una segunda ventana ni
con el ajuste en `YES`. La navegación compartida es estructural (singletons), no depende de la sonda.

**D4 · ¿`done` o `qa`?** → Si la sonda mide «antes: 2 escenas / después: 1 y error», el ticket va a `done`: el
criterio del ticket es que la segunda ventana no aparezca, y eso queda medido. El guion de iPad real se deja en
el ticket como comprobación opcional de Jürgen, no como bloqueo.

**D5 · ¿Qué XCUITest de navegación?** → Los del área de navegación del `qa/coverage-index.json`, en el iPad y el
`YalaLane-Adapt-iPhone-ProMax` por UDID. Si fallan, se contrastan con `2.1` antes de culparme.

**D6 · ¿ADR?** → No. Es un apagado temporal con ticket de vuelta (`ipad-real-multiwindow-with-per-scene-state`);
se anota en el plan y en el ticket, no es una decisión que dure.
