# Tras salir de un adopt, «Cancelar» y el «OK» del aviso de borrar todo vuelven a la bienvenida, no dentro de la app

## Contexto
Ticket `tickets/backlog/fresh-start-alert-cancel-after-an-adopt-exit-lands-in-the-app.md` en `origin/2.1` (léelo entero primero). Tarjeta del tablero fspw (`tablero-tras-salir-de-un-adopt-cancelar-del-avis-fspw`). Sale del PR #372 (`fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes`), que introdujo el testigo `freshStartAlertPresentedOverWelcome` solo para el botón destructivo con cambios de grupos pendientes y pidió no tocar las demás salidas.

En lenguaje de usuario: alguien empieza a entrar con su cuenta de la nube desde la bienvenida, el adopt falla o lo cancela y vuelve a la bienvenida. Elige «Soy nuevo → privacidad total», sale «¿Borrar todo y continuar?» porque el teléfono tiene datos, y toca «Cancelar». Espera volver a donde estaba y en cambio aterriza dentro de la app, sobre los datos que iba a borrar. Lo mismo con el «OK» del aviso de que el borrado falló. Lo medido en el ticket: esas dos salidas reabren el Welcome solo `if !hasCompletedOnboarding`, y tras un adopt ese flag queda en `true` (`onAdoptStarted`, kill-safety) sin que ninguna salida lo devuelva.

Decisión tomada de noche (regla día/noche, reversible, la recomendada por el propio ticket): **lo correcto es la bienvenida**. Tras un adopt cancelado o fallido, «Cancelar» y el «OK» del aviso de fallo vuelven a la elección privado/nube (`.chooser`), no a la app. Que un kill a mitad del adopt deje a la persona en la app es otro caso y no se toca aquí.

Jürgen prefiere siempre lo más robusto y la mejor práctica, aunque tome más tiempo.

## Qué se pide
- Las dos salidas («Cancelar» del «¿Borrar todo y continuar?» y «OK» del aviso de fallo del borrado) usan el mismo testigo `freshStartAlertPresentedOverWelcome` que ya usa el botón destructivo: si el alert se presentó sobre el Welcome, reabren el Welcome en `.chooser`. Sin cambio para quien no completó el onboarding.
- Revisa que no quede otra salida de ese alert con la guarda vieja; si hay, misma regla y dilo en el cierre.
- Tests que fijen el destino de cada salida (con y sin adopt previo, con y sin onboarding completo) y mutantes que lo prueben.
- Si se puede montar el estado en el simulador (seed de UITest del adopt en la bienvenida), capturas de antes y después en `capturas/` del worktree (`antes.png`, `despues.png`) con las rutas en el resumen de cierre. Si no se puede, dilo en el cierre en vez de inventarlas.
- Ticket a `qa` con guion corto de device-QA, `docs/TICKETS.md` y `qa/coverage-index.json` al día. Tarjeta fspw al estado que toque, firmando como frank.
- Cierra con PR a `2.1` en auto-merge y luego `/cerrar-total` autónomo, sin esperar a Jürgen.

## Qué NO hay que tocar
- El comportamiento del botón destructivo ya arreglado en #372.
- El kill-safety del adopt (`onAdoptStarted` y el flag `hasCompletedOnboarding`): no se revierte el flag, solo se decide el destino con el testigo.
- Producción y staging (nada de DDL ni credenciales). marketing/ y Web/.

## Pipeline serial en la Mini (obligatorio)
1. Limpiar sims muertos, basura previa, DerivedData de sesiones ya cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen. Sin preguntar.
2. Build con `xcodebuild -jobs 2` sin simulador encendido.
3. Encender UN solo simulador.
4. Tests.
5. Apagar y borrar los datos de ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests. La Mini anda justa de disco (~32 GB libres).

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. Justo antes del gate, mira si el PR #382 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## DerivedData y cachés
Al lanzar y al cerrar, borra sola el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No preguntes. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

## Cierre limpio
Al `/cerrar-total`: apaga el simulador que usaste, borra sus datos, quita el worktree y su DerivedData si ya no hace falta, y no dejes devices apagados ni worktrees huérfanos. Si creaste algún secreto en el Llavero, dilo en el cierre.

## Cómo se sabe que está bien
- Con un adopt cancelado y datos locales, «Soy nuevo → privacidad total → Cancelar» vuelve a la elección privado/nube, y el «OK» del aviso de fallo también.
- Quien no completó el onboarding, igual que hoy.
- Build verde, unit y UI de las áreas tocadas verdes, mutantes muertos.
- PR a 2.1 en auto-merge, capturas antes/después (o motivo de su ausencia), Mini limpia.

## Paso 0

Decisiones resueltas antes de tocar código (sesión autónoma, 2026-10-07; nada de esto es de Jürgen):

1. **Destino** — lo fija el encargo: tras un adopt cancelado o fallido, «Cancelar» y el «OK» del aviso de fallo
   reabren el Welcome en `.chooser`. Sin onboarding completo, igual que hoy.
2. **Una sola pregunta, un solo predicado.** «¿Había un Welcome debajo que reabrir?» ya la contesta
   `FreshStartAlertRoutingLogic.pendingGroupsRoute` para el botón destructivo. Las dos salidas nuevas preguntan lo
   mismo, así que la condición (`!hasCompletedOnboarding || presentedOverWelcome`) pasa a un predicado con nombre que
   usan las tres. El destructivo no cambia de comportamiento: sus cuatro celdas siguen fijadas por sus tests.
3. **El testigo vale para el «OK».** Medido: `showFreshStartWipeFailedAlert = true` solo lo escriben
   `performFreshStartWipe` (su `catch`) y `refuseWhileGroupsArePending`, los dos detrás del botón destructivo de
   este mismo alert. No hay otro disparador que lo encienda con un testigo viejo.
4. **Otras salidas con la guarda vieja: ninguna en este alert.** El `if !hasCompletedOnboarding` de
   `ContentView` (onDismiss del cover del adopt) es otro cover y otra situación — cuando UIKit lo tumba sin
   terminal — y queda fuera; va al cierre como hallazgo.
5. **El estado se monta con un seam de ENTRADA** (`-uitest-welcome-after-adopt-exit`): onboarding dado por visto
   (efímero, el mismo `applyOnboardingAlreadySeen`) y el Welcome reabierto en `.chooser` con el trío de `onBack`.
   En el simulador no hay SIWA, así que el adopt real no se puede conducir. Finge la entrada, no la decisión: el
   alert, sus botones y el testigo son los de producción.
6. **Pruebas**: lógica pura (4 celdas del predicado), source-scan del cableado de las dos salidas y del seam,
   XCUITest «Cancelar tras adopt → Chooser» (rojo sin el arreglo), mutantes sobre el predicado y sobre cada salida.
   El «OK» del aviso de fallo en XCUI se intenta con `-uitest-fail-wipe`; si no monta, queda en source-scan + device-QA.
