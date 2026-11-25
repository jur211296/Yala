Yala
# Bugs de cuenta: dejar en verde las pruebas de sesión de la nube y espera del Panel
---
toca: YalaTests/CloudSync/CloudSessionRevisionWiringTests.swift,YalaTests/BarridoFinal23/PanelWaitsAfterEmpezarTests.swift,Yala/App/Views/Profile/ProfileView.swift,Yala/App/Views/Profile/YalaAccountView.swift,Yala/App/ViewModels/PanelViewModel.swift,Yala/App/ContentView.swift,Yala/App/Logic/AccountEntryLandingLogic.swift,Yala/App/Logic/SyncSignInBannerLogic.swift,Yala/Services/CloudSync/CloudSyncRuntime.swift,Yala/Services/CloudSync/CloudSyncEngine.swift,tickets/backlog/2026-11-25-bugs-cuenta-verde-pruebas-cableado.md,tickets/done/2026-11-25-bugs-cuenta-verde-pruebas-cableado.md
esfuerzo: high
cierre: cierra-sola
---

Card del tablero (2.3, prioridad alta): **tablero-bugs-de-cuenta-dejar-en-verde-las-prueba-het0**. Jürgen autorizó este arreglo el 25-nov a las 10:50 Lima.

## Contexto
El PR #1176 (https://github.com/jur211296/Yala/pull/1176), «Bugs de cuenta: Vaciar datos, Eliminar cuenta y primeros pasos en solo gastos», rama `encargo/2026-11-25-bugs-cuenta-nube-vaciar-datos-y-eliminar-cuenta` hacia `2.3`, está abierto, en auto-merge y BLOQUEADO. El check `tests` falla en la tanda 2 de unit en dos pruebas, que siguen en rojo al repetirlas. Run: https://github.com/jur211296/Yala/actions/runs/45633857419.

1. `YalaTests/CloudSync/CloudSessionRevisionWiringTests.swift` → `readerTracksTheSession`, caso `Yala/App/Views/Profile/ProfileView.swift`, ancla `private var deleteAccountRowHasSession: Bool {`. Espera que las 2 líneas siguientes sean `CloudSessionRevision.shared.track()` y `return UITestHooks.fakeBackendSession || CloudAuthService.shared.hasSession` (línea 92 de la prueba). El PR cambió ese getter: sigue llamando `track()`, pero ahora devuelve `AccountDeletionRowLogic.shouldShow(hasSession: …, storageIsCloud: CloudSyncFlags.storageMode == .cloud)` en varias líneas.
2. `YalaTests/BarridoFinal23/PanelWaitsAfterEmpezarTests.swift` → `wiring` (línea 122). Espera el texto literal `if justEntered, next.isWaiting || inputs.firstPullCompleted || inputs.attestVerdictIsTerminal { AccountEntryPanelWait.disarm() }`. El PR, en `Yala/App/ViewModels/PanelViewModel.swift`, agregó `|| waitsForSignIn` a esa condición.

Causa probable (no confirmada): las dos son pruebas de cableado que comparan el texto del código y quedaron viejas frente al cableado nuevo del PR. Igual hay que confirmar dos cosas. Primero, que `deleteAccountRowHasSession` siga reaccionando cuando la sesión entra con Ajustes abierto (card n533), que es lo que protege la prueba 1. Segundo, que desarmar la espera también con `waitsForSignIn` no haga que el Panel muestre S/ 0 con «Crear categorías» en vez del esqueleto justo después de «Empezar», que es lo que protege la prueba 2.

## Qué se pide
1. Trabaja **sobre la rama del PR 1176**, no en una rama nueva: haz checkout de `encargo/2026-11-25-bugs-cuenta-nube-vaciar-datos-y-eliminar-cuenta` y empuja ahí. Si tu worktree nace sobre otra rama, cámbiate a esa.
2. Reproduce las dos pruebas en local y lee las aserciones exactas que fallan.
3. Para cada una, decide:
   - **Si el código del PR rompió el comportamiento que la prueba protege**, arregla el código sin perder los arreglos del PR: Vaciar datos sin el banner «Inicia sesión para subir N cambios», «Eliminar mi cuenta» visible con los datos en la nube aunque se haya perdido la sesión, primeros pasos para cuentas nuevas «solo gastos» y «gastos e ingresos», y el esqueleto del Panel que no se queda pegado.
   - **Si la prueba quedó vieja frente al cableado nuevo**, actualízala para que siga protegiendo lo mismo. La 1 debe seguir exigiendo `track()` antes de leer la sesión. La 2 debe seguir exigiendo que la espera se desarme solo en los casos correctos. No la debilites ni la borres.
   Di en el cierre qué fue cada una.
4. Corre las dos pruebas arregladas y las de `YalaTests/BugsCuentaNube/`, solo para confirmar que siguen verdes. No edites estas últimas.
5. Ticket: crea `tickets/backlog/2026-11-25-bugs-cuenta-verde-pruebas-cableado.md` y, al cerrar, muévelo a `tickets/done/`.
6. Deja el PR #1176 en auto-merge y cierra sin esperar el CI.
7. El entregable es un artifact visual de Claude. Debe mostrar, por cada prueba, qué protegía, qué cambió en el PR, qué se decidió (código o prueba) y el antes y el después. Enlázalo en el cierre.

Pruebas en simulador o dispositivo:
  - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
  - Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
  - Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
  - Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva); nada de bucles de 10 min ni comandos que se pasen del límite y queden en segundo plano a ciegas.
  - Antes de compilar en iOS mira la carga: si otra sesión compila con xcodebuild en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.

Build iOS: pipeline serial (limpiar, compilar con `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, probar, apagarlo). Usa el iPhone 14 por DeviceMCP. Un segundo simulador, solo en la Max. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Solo lo de `toca:`: las dos pruebas, los archivos de la app que el PR tocó en la sesión de la nube y el Panel, y el ticket. Nunca `Yala/`, `YalaTests/` ni `tickets/` enteros, ni `Yala/Resources`.
- No reviertas los arreglos de Vaciar datos, Eliminar cuenta, primeros pasos ni del esqueleto.
- No toques el gateway ni despliegues nada.
- Sin firma de IA en commits ni en el PR.

## Cómo se sabe que está bien
- Las dos pruebas pasan en local y siguen protegiendo lo que protegían.
- Las pruebas de `YalaTests/BugsCuentaNube/` siguen verdes.
- El cierre dice, para cada prueba, si fue el código o la prueba, y por qué.
- El PR #1176 queda en auto-merge.
- Cierre con `/cerrar-total`, con las secciones «Saltado o asumido sin preguntar» y «Decidido sin consultar». Todo en español neutro latinoamericano.
