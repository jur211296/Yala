---
id: sign-out-in-place-leaves-a-screen-with-nothing-to-tap
status: qa
priority: high
area: cloud-sync, sign-out, welcome
created: 2026-10-28
updated: 2026-11-06
source: card 7e60 del tablero (Jürgen, 2.º iPhone, 2026-10-28 ~06:14)
---

# Cerrar sesión aceptando perder los cambios: la app «se cierra»; y tras «Tu cuenta está lista», el elector del Welcome

## Qué pasaba

1. En la nube, con la sesión caducada, Jürgen cerró sesión y eligió perder los cambios sin subir. La app «crasheó y se
   cerró».
2. Al reabrir: «Ya tengo una cuenta» › Google › «Conectando cuenta» › «¡Tu cuenta está lista!» › al avanzar, volvió al
   elector «¡Hola! ¿Qué quieres hacer en Yala?» en vez de entrar a la app.

## Lo medido

- Sentry no tiene ningún evento de ese día (ni crash ni error) y el iPhone no estaba conectado: no hay informe del cierre.
- El camino de «perderlos» no tiene `fatalError`, `try!` ni unwraps forzados (leído entero).
- **El cierre en la nube cambia el almacén en caliente y vuelve a reposo sin pedir reabrir** (card ypit). El
  `ContentView` nuevo se monta durante el re-bootstrap, con la fase todavía en `.awaitingRelaunch`, y su arranque
  (`checkInitialSyncState`, sin ningún `await` antes de decidir) llama a `presentNextOnboardingScreen`, cuyo `guard` se
  calla en esa fase. Cuando la fase vuelve a `.idle`, nadie lo retoma: ni Welcome, ni app, ni la pantalla de reabrir. Una
  pantalla sin nada que tocar, que se vive como «se cerró», y sin informe en Sentry.
- No se puede ejercitar en el simulador: allí el almacén monta con espejo y el cambio en caliente se salta (lo midió el
  XCUITest de la celda solo-grupos: acaba en la pantalla de reabrir, que es lo previsto en ese caso).

## Hecho (2026-10-28)

(a) El arranque apunta que se calló esperando el relanzamiento y, cuando la fase vuelve a reposo, presenta el Welcome si
el onboarding no está hecho (`SignOutDeferredRoutingLogic`, `ContentView.resumeOnboardingRoutingDeferredForRelaunch`).
Si el cambio aborta, la fase no vuelve a reposo y manda la pantalla de reabrir, como antes. Tests:
`SignOutDeferredRoutingTests`.

(b) **Sin arreglar: no se encontró el camino.** Leído el flujo entero, tras «¡Tu cuenta está lista!» el botón solo cierra
la entrada a la cuenta, y el respaldo que reabre el elector exige el onboarding sin hacer, que la entrada marca como
hecho al empezar a conectar. Los demás escritores del elector (volver atrás, los borrados) no son alcanzables desde esa
pantalla. Hace falta una medida en el iPhone (abajo).

## Device-QA (iPhone de QA)

(a) Cierre en la nube aceptando perder cambios:
1. En un iPhone con Yala en la nube y cambios sin subir (por ejemplo, en modo avión apunta un gasto), ve a Ajustes ›
   Cerrar sesión › confirma.
2. Si sale el aviso de cambios sin subir, elige perderlos.
3. Esperado: sin cerrar la app, aparece el Welcome. Antes: pantalla vacía o la app parecía cerrarse.

(b) Si vuelve a salir el elector tras «¡Tu cuenta está lista!»:
1. No toques nada en el elector. Cierra Yala del todo (desliza hacia arriba en el selector de apps) y ábrela.
2. Si entra en la app con tu cuenta: el elector lo puso algo que no toca la marca del onboarding. Si vuelve al Welcome:
   algo borró esa marca. Cuéntame cuál de las dos.

## Falla en dispositivo (2026-11-05)

iPhone 14 (iOS 27.2), Yala Dev sobre `origin/2.2` (#809), cuenta en la nube (Google).

1. **Sin red no se puede perder lo pendiente** (por diseño, `SignOutBlockedCopy`): con modo avión y un gasto sin subir,
   a los ~90 s «No pudimos cerrar tu sesión · Tus últimos cambios no llegaron a la nube…» + OK. Yala no se cierra. La
   opción «perder los cambios» del guion B3 solo existe en iCloud privado.
2. **Crash al cerrar sesión con red.** El cierre se completa y a los 10 s Yala se cierra: `EXC_BREAKPOINT` en
   SwiftData dentro de `ProfileViewModel.loadTransactions()` ← `loadData()` ← `setContext(_:)` ← `onAppear` de
   `ProfileView.listColumn`, disparado por `SheetBridge.didDismissViewController`. Al cerrarse la hoja de
   confirmación, Ajustes reaparece y hace `fetchCount` sobre el contexto del almacén que el cierre acaba de cambiar.
   `.ips`: `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/B3-crash-cerrar-sesion-Yala-2026-11-05-195252.ips`; vídeo `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/B3-iphone-cerrar-sesion-crash.mov`.
3. **«Ya tengo cuenta» deja en el Welcome.** Reabierta, Ya tengo cuenta › Google (misma cuenta) › «¡Tu cuenta está
   lista!» › Empezar → vuelve al chooser del Welcome. Vídeo `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/B3b-*`.

Siguiente: arreglar 2 (Ajustes no lee el contexto viejo al reaparecer durante o tras el cambio de almacén; revisar
los demás `setContext` que corren al cerrar la hoja) y 3. Review adversarial (cierre de sesión). Vuelve a QA con device.

## Arreglado (2026-11-05, noche, lote «Cerrar sesión con cambios»)

Medido en el iPhone 14 con Yala Dev de la rama:

- **Crash 1 (Ajustes reaparece con el almacén soltado).** La hoja de Ajustes deja de pintar su contenido en cuanto la
  generación del almacén cambia o el host se queda sin él (`.detachesFromSwappedStore()`, `SwappedStoreContentLogic`).
  Con el arreglo, el primer crash no salió.
- **Crash 2, el que el primero tapaba.** Con el primero fuera, el cierre en la nube seguía cerrando Yala a los ~8 s:
  `AppBootstrapper.rebootstrapAfterSwap` → `BackgroundTaskManager.registerTasks()` → `BGTaskScheduler` lanza
  `NSInternalInconsistencyException` por registrar dos veces el mismo identificador en el mismo proceso. `.ips` en
  `~/Claude/entregas/2026-11-05-lote-cerrar-sesion-crash-welcome/evidencia/Yala-2026-11-05-224058.ips`. Ahora
  `registerTasks()` corre una vez por proceso. **El cambio de almacén en caliente de la nube cerraba Yala siempre en un
  iPhone real desde la card ypit**: el simulador monta con espejo y nunca lo ejerció.
- **Bucle «Un último paso: reabre Yala» tras el cierre.** Un destino del Welcome de antes del cierre («Restaurar desde
  iCloud», que la prueba de la tarde dejó sin consumir) sobrevivía al borrado; el arranque abría Restaurar, Restaurar
  pedía reabrir y el neutro armado volvía a montar sin espejo, en cada apertura. Ahora cada arm del borrado escribe el
  destino del cierre o retira el viejo, y Restaurar que pide reabrir marca la elección. Medido: con el arreglo, una
  sola reapertura y conecta con iCloud.

Tests: `SwappedStoreContentTests`, `BackgroundTaskRegistrationOnceTests`, `SignOutWelcomeDestinationTests` (4
mutantes, cada uno en rojo).

## Mañana del 2026-11-06 (iPhone 14, con Jürgen para Google)

- **Crash 3, el que el segundo tapaba.** Con los dos primeros fuera, el cierre en la nube volvió a cerrar Yala a los
  ~3 s de pintar la bienvenida: `PanelViewModel.loadData()` ← `scheduleRecalculation` ← el `onDismiss` de la hoja de
  Ajustes del Panel viejo, que corre aunque el Panel ya no esté montado y recarga con el almacén soltado. `.ips` en
  `~/Claude/entregas/2026-11-05-lote-cerrar-sesion-crash-welcome/evidencia/Yala-2026-11-06-071322.ips`. Ahora el
  contexto de `PanelViewModel` y `DetailContainerViewModel` va atado a la generación del almacén (`BoundStoreContext`):
  con otro almacén montado se lee `nil`, y el Panel, Estadísticas y Registros no recargan ni recalculan. Son las únicas
  hojas de Ajustes que recargan algo al cerrarse (las otras ocho no tienen `onDismiss`). Medido: cerrar sesión con
  red, dos veces, sin `.ips` nuevo.
- **(b) resuelto en el aparato.** Desde un cierre limpio: «Ya tengo cuenta» › Google › «¡Tu cuenta está lista!» ›
  Empezar → entra en el Panel y se queda. Inferido, no medido: el elector salía por el estado roto que dejaban los
  crashes (neutro armado + destino viejo), que ya no se produce.
- **Reabrir a medias (decisión de Jürgen, 2026-11-06).** Quien elige entrar en una cuenta y ve Yala cerrarse antes de
  terminar, al reabrir vuelve a «¿Qué quieres hacer?», no al Paso 1 del alta privada (`WelcomeUnfinishedAccountEntry`).
  Medido: «Ya tengo cuenta › Google», cerrar en el aviso de Google y reabrir → el elector.

Tests nuevos: `BoundStoreContextWiringTests`, `WelcomeUnfinishedAccountEntryTests`.

## Device-QA pendiente (guion corto)

1. iPhone de pruebas con Yala Dev en la nube (Google). Ajustes › Tu cuenta de Yala › Cerrar sesión › confirma.
   Esperado: la bienvenida, y Yala sigue abierta 10 s después.
2. «Empezar» › «Ya tengo cuenta» › «Entrar con Google» › tu cuenta › «¡Tu cuenta está lista!» › Empezar. Esperado: el
   Panel.
3. Repite 2 pero cierra Yala del todo en el aviso de Google y ábrela. Esperado: «¿Qué quieres hacer?».
4. Sin probar aún: la sesión caducada con cambios sin subir (el caso original de la card). Si se puede provocar, cierra
   sesión ahí y comprueba lo mismo que en 1.
