# Tras una migración a la nube fallida y sin efectos pendientes, ofrecer cerrar la sesión privada (cambio de Apple ID y cierre manual)

## Contexto
Ticket `tickets/backlog/apple-id-change-check-stays-off-after-a-failed-migration.md` (origen #273). Léelo entero: explica el problema y dónde vive el predicado.

Hoy, si un paso de los datos a la nube terminó en fallo (`failedRollback` → `.failed(.migration)`) y la persona no volvió a Almacenamiento a pulsar «Reintentar», Yala no le ofrece cerrar la sesión privada aunque cambie de Apple ID, y tampoco le deja cerrarla a mano: el guard exige `.idle` (`AppleIDChangeCloseLogic.migrationAtRest`), y desde `private-sign-out-proceeds-with-a-migration-in-flight` el cierre manual usa el mismo predicado (`CloudSignOutFlowLogic.migrationBlockReason`). La persona queda atascada con una copia de otra cuenta en el teléfono.

**Decisión de Jürgen (2026-10-04): A.** Ofrecer cerrar la sesión privada tras una migración fallida, con el alcance que dice el ticket: solo cuando el fallo NO lleva efectos pendientes (nada de `.rollback` u otros efectos que un resume ejecutaría). No dejar al usuario atascado. Si hay efectos pendientes, sigue sin ofrecerse, como hoy.

Jürgen prefiere siempre lo más robusto y la mejor práctica, aunque tome más tiempo.

## Qué se pide
1. Antes de tocar código, verifica la premisa contra el código de hoy en `origin/2.1` (puede haber cambiado desde el 27-sep). Si la premisa ya no se sostiene, documéntalo en el ticket y cierra con eso.
2. Haz que `migrationAtRest` (o el predicado que corresponda) acepte el terminal de migración fallida sin efectos pendientes, de forma que se abran a la vez los dos lectores: el aviso del cambio de Apple ID al arrancar y el cierre manual de la sesión privada. Cambia el test `migracionFallida_tambienPara` de `PrivateSignOutMigrationGuardTests` según la decisión y añade la tabla de casos (fallido sin efectos → se ofrece; fallido con efectos pendientes → no; en curso → no; idle → sí).
3. Cierre de la sesión privada tras ese fallo: que deje el estado de migración coherente (que «Reintentar» o el fallo viejo no reaparezcan con datos de otra cuenta). Si encuentras un caso que la decisión A no cubre, no lo improvises: déjalo en «Qué quedó fuera» y en un ticket.
4. Tests unitarios de la lógica y, si hay seam razonable, un XCUITest del camino visible (migración fallida → cerrar sesión privada disponible). Mutantes sobre el predicado nuevo.
5. Ticket a `qa` (con guion de iPhone si el camino real no se puede montar en el simulador) y `docs/TICKETS.md` / `qa/coverage-index.json` al día como en las sesiones anteriores.
6. PR contra `2.1` con auto-merge, y `/cerrar-total` autónomo al terminar.

## Qué NO hay que tocar
- No cambies el comportamiento cuando hay efectos pendientes ni cuando la migración está en curso.
- Nada de copy nuevo salvo que sea imprescindible; si hace falta, en los 16 idiomas.
- No entres en `marketing/` ni en la web.
- No cambies el flujo de «Reintentar» más allá de lo necesario para la coherencia del punto 3.

## Pipeline y Mini (normas de flota)
- Pipeline Yala SERIAL en la Mini: (1) limpiar sims muertos y basura previa, (2) build con `xcodebuild -jobs 2` sin simulador encendido, (3) encender 1 solo simulador, (4) tests, (5) apagar y limpiar ese simulador. Prohibido solapar swift-frontend + SpringBoard + app + UITests.
- DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de otra sesión viva. No preguntes a Jürgen; si el borrado falla, dilo en el cierre.
- Gate después del CI del PR anterior: arrancas ya sobre `origin/2.1`. Justo antes del gate, mira si el PR #380 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
- Si el cambio se ve en pantalla, deja `antes.png` y `despues.png` en la carpeta de capturas y lista las rutas en el resumen. Si no hay cambio visible, no inventes capturas.
- Al cerrar: simuladores apagados y borrados, worktree retirado si ya no hace falta, Mini lo más limpia posible. Si creaste cualquier secreto en el Llavero, dilo en el resumen.

## Cómo se sabe que está bien
- Con una migración fallida sin efectos pendientes, el cambio de Apple ID ofrece cerrar la sesión privada y el cierre manual funciona; con efectos pendientes o migración en curso, sigue bloqueado.
- Tests unitarios y de UI verdes, mutantes muertos, PR abierto contra `2.1` en auto-merge, ticket en `qa`, `/cerrar-total` hecho.

## Paso 0

Medido en `origin/2.1` (78c7fa34b) antes de tocar nada.

**La premisa se sostiene.** `AppleIDChangeCloseLogic.migrationAtRest` sigue exigiendo que la derivación dé `.idle`, y
`failedRollback` deriva `.failed(.migration)`. Los dos lectores del ticket lo comparten: el guard del arranque
(`AppBootstrapper.migrationAtRestForAppleIDChange`) y el cierre manual (`CloudSignOutFlowLogic.migrationBlockReason`).

**Decisiones (autocontestadas, MODO AUTÓNOMO):**

1. **Predicado nuevo, no `migrationAtRest` ensanchado.** `migrationAtRest` tiene un TERCER lector que ni el ticket ni el
   encargo nombran: el borrado pendiente del iCloud privado al arrancar (`ContentView`, `WelcomePrivateICloudGateLogic`).
   Ensancharlo haría que, tras un fallo, ese borrado se reanudara solo y que caducara la renuncia de «Activar la nube sin
   borrar», con «Reintentar» todavía a la vista. Eso es borrar datos fuera del alcance de la decisión A. Así que:
   `migrationAllowsPrivateSessionClose = migrationAtRest || failedWithNothingPending`, y lo leen SOLO los dos lectores del
   cierre. El tercero sigue con `migrationAtRest` estricto, como hoy.
2. **«Sin efectos pendientes» = `pendingEffectsData` vacío en el journal.** Al entrar en `failedRollback` el runner vacía
   `reverseOriginPendingEffectsData` en el mismo save, así que esa es la única cola que un resume ejecutaría. La lectura
   sale del MISMO fetch que la fase (`MigrationPhaseStore`), para que fase y pendientes no puedan venir de dos instantes.
   Journal ilegible ⇒ cuenta como «con pendientes».
3. **Términos del fallo asentado:** el controller no trabaja; su estado es `nil` o `.failed(.migration)` (un `.idle`
   desfasado con el journal en fallo NO concede); la derivación del journal da `.failed(.migration)` (deja fuera
   `.failed(.reverse)` y el relanzamiento pendiente); sin pendientes; modo persistido `.icloud` (el teléfono «como
   empezó»; la máquina ya lo garantiza, y el término lo fija fail-closed).
4. **Coherencia tras cerrar (punto 3): ya está por construcción.** El cierre privado arma el borrado del arranque, que
   borra el ARCHIVO sync-meta donde vive el journal (`SwiftDataConfiguration.performSignOutWipeIfArmed`): ni «Reintentar»
   ni el fallo viejo pueden volver. Si el borrado del archivo falla, el arm se retira y nada se borró: el fallo sigue
   siendo de quien lo tenía. No hace falta tocar «Reintentar».
5. **Sin copy nuevo.** Con efectos pendientes el bloqueo y su texto (`.migrationInFlight`) son los de hoy.
6. **XCUITest:** seam `-uitest-migration-failed` que finge la ENTRADA (la fila del journal en `failedRollback`, sin
   pendientes) en los dos fetch de producción, molde de `-uitest-migration-journal-unreadable`. El test comprueba antes
   que Almacenamiento pinta el fallo (control de que el seam montó algo) y después que «Cerrar sesión» ya no se para por
   la migración: llega hasta `signOut()`, donde lo frena `-uitest-sign-out-keeps-session` antes del arm.
