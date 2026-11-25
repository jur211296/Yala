---
id: 2026-11-25-bugs-cuenta-nube-vaciar-datos-y-eliminar-cuenta
status: done
priority: high
area: "cloud-sync, account-deletion, bienvenida-2-3"
created: 2026-11-25
updated: 2026-11-25
source: "Jürgen, QA de Yala Dev 2.3 (9), 25-nov 7:04-7:12"
---

# Bugs de cuenta: Vaciar datos, Eliminar cuenta y primeros pasos en solo gastos

## Qué reportó Jürgen

- **A.** Tras «Vaciar datos» en una cuenta de Yala: banner «Inicia sesión para subir 7,383 cambios», «Dónde viven tus
  datos» igual, y el esqueleto del Panel pegado muchísimo tiempo, también al reabrir.
- **B.** En Ajustes › Tu cuenta no aparecía «Eliminar mi cuenta» (solo «Tu IA» y «Cerrar sesión»).
- **C.** Cuenta nueva con «Solo gastos», y luego también con «Gastos e ingresos»: sin Primeros pasos. Y tras crear la cuenta,
  esqueleto largo al reabrir.

## Medido

- iPhone 14 (Yala Dev 2.3 (9), cuenta de staging): «Recargar datos de prueba» + «Vaciar datos» dejaron **7.166 cambios** en
  la cola personal (3.148 filas con alta y baja pendientes, 1.099 bajas de tipos de cambio). Al reabrir, esqueleto **62 s**
  (el techo de `PanelAccountDataWait`), con la sesión válida.
- El motor sube la cola entera antes de su primera bajada, en trozos de 50 con el token pedido UNA vez (~300 ms por
  cambio ⇒ media hora). El Panel espera esa primera bajada. Un JWT que vence a mitad devuelve 401 ⇒ `.sessionExpired` ⇒
  `stoppedUntilSignIn` ⇒ banner (inferido por código; el JWT de staging dura 1 h).
- iPhone 18 de Jürgen: `tabBarDefaults23.migrated` puesto y sin `onboarding23.freshInstall`. El mazo exige esa marca
  (`SetupChecklistManager.showsDeck`), que `TabBarDefaultsMigration.runIfNeeded` decide una sola vez por instalación.
- B: «Tu cuenta de Yala» (y dentro «Eliminar mi cuenta») colgaba de `CloudAuthService.hasSession`. La fila existía y no se
  perdió en ningún commit; en modo nube con la sesión borrada por el SDK desaparecía la sección entera.

## Arreglo

- `SyncPushClient.push`: token y attest por trozo. Sin token tras un trozo confirmado, entrega lo confirmado.
- `CloudSyncRuntime.performCycle`: retira las altas que una baja posterior deja sin efecto
  (`CloudSyncEngine.dropSupersededUpserts`, fila y espejo) y, antes de la primera bajada del proceso, sube dos trozos y baja
  (`SyncOutboxBacklogLogic`).
- `PanelAccountDataWait`: no espera con el motor parado hasta iniciar sesión.
- `AccountDeletionRowLogic.shouldShow(hasSession:storageIsCloud:)`: «Tu cuenta de Yala» y «Eliminar mi cuenta» con los
  datos en la nube aunque no haya sesión; al confirmar sin sesión, `signInToResumeSync` primero
  (`ProfileView.confirmAccountDeletion`). La puerta firma con el proveedor del faro si no hay uno guardado
  (`SyncSignInBannerLogic.provider`).
- `TabBarDefaultsMigration.markStartedWithWelcome23`: el alta nueva de 2.3 apunta la marca (no las re-entradas).
- «Vaciar datos» conserva cuenta y sesión: decisión «Sesiones — dos ejes» (2026-09-09, punto 6) y S27i (2026-10-29).

## Pruebas

- `YalaTests/BugsCuentaNube/` (lógica + cableado), dos casos nuevos en `SyncPushClientTests`.
- `YalaUITests/BugsCuentaNube/PrimerosPasosTrasElAltaUITests`: teléfono «de antes de 2.3», alta por la conversación, los
  dos modos. Mutantes: sin la marca caen los dos; con el token pedido una vez caen los dos casos nuevos de la subida.
- iPhone 14 con el arreglo: cola tras vaciar 602 (mismo escenario), Panel en ~17 s al reabrir, «Todo sincronizado»; en
  modo nube sin sesión sale «Tu cuenta de Yala», y «Eliminar mi cuenta» entra con Google, borra en staging y termina en
  el Welcome.

## Hecho cuando

Lo de arriba en `2.3`. Device-QA pendiente en el iPhone 18 de Jürgen (teléfono de antes de 2.3): cerrar sesión, crear
cuenta nueva con «Solo gastos» y con «Gastos e ingresos» y ver Primeros pasos.
