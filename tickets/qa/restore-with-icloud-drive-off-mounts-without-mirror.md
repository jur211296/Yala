---
id: restore-with-icloud-drive-off-mounts-without-mirror
status: qa
priority: medium
area: "icloud, restaurar, arranque"
created: 2026-11-05
updated: 2026-11-05
source: "lote N4 (iCloud Drive y preferencias), medido leyendo el código al cerrar la card de las esperas del arranque"
---

# Restaurar no trae nada con iCloud Drive apagado

## Qué pasa, en lenguaje de usuario

Tengo la sesión de iCloud abierta pero iCloud Drive apagado. Reinstalo Yala y elijo «Restaurar desde iCloud»: la app me
dice que necesito iCloud, o me pide reabrir, aunque mis datos están en iCloud y CloudKit funciona.

## Lo medido (2026-11-05, rama 2.3)

- `WelcomeRestoreView.startSearch` decide «¿hay iCloud?» con `iCloudSyncService.isAccountAvailable`, que es el token de
  iCloud **Drive** (`SwiftDataConfiguration.isICloudAvailable()`). Con Drive apagado cae en `.iCloudDisabled`.
- Cambiar solo ese testigo a `hasICloudAccount` (token **o** CloudKit `.available`, el que ya usan las esperas del
  arranque desde el lote N4) **no basta**: la tabla de montaje (`personalStoreDecision`) también va por el token, así
  que con Drive apagado una instalación nueva monta el store neutro, sin espejo. Restaurar buscaría sin poder traer
  nada, o `WelcomeRestoreRelaunchLogic.needsRelaunchToSearch` pediría reabrir, el arranque volvería a montar sin espejo
  y la petición se repetiría: un bucle.
- El mount que sale con Drive apagado y la app ya en uso (`.localNoMirror`) sí adjunta el espejo (`.automatic`); el
  problema es el neutro de la instalación nueva y el relanzamiento del Welcome, que deciden por el token.

## Qué hay que decidir y hacer

Arreglarlo es tocar a la vez la tabla de montaje y Restaurar: que el portal de relanzamiento del Welcome y el montaje
pregunten por la cuenta de CloudKit cuando Restaurar la necesita. Va con el lote N3 (Restaurar y Almacenamiento), que
vive sobre esos ficheros. Device-QA en un iPhone con iCloud Drive apagado.

## Criterios de aceptación

- [ ] Con iCloud Drive apagado y la sesión abierta, «Restaurar» trae los datos sin pedir reabrir en bucle.
- [ ] Sin cuenta de iCloud, sigue diciendo «Activa iCloud».

## Hecho (2026-11-05, lote «Restaurar / reinstalar», sobre 2.3)

- **La pregunta «¿hay iCloud?» es la cuenta de CloudKit.** `WelcomeRestoreView.startSearch` decide con
  `WelcomeRestoreRelaunchLogic.accountCheck` (token de Drive, o CloudKit `.available`), y la salida del Welcome
  (`WelcomeFlowContainer.leaveWelcome`) con `iCloudSyncService.hasICloudAccount`. Si CloudKit aún no contestó en este
  proceso, Restaurar le pregunta UNA vez antes de decidir; sin respuesta, «Activa iCloud» como antes.
- **La tabla de montaje NO se tocó, y la premisa de arriba se midió**: tras el relanzamiento del Welcome el chooser
  queda marcado (`ContentView.onNeedsMirrorRelaunch`), los dos neutros caducan y con Drive apagado sale
  `.localNoMirror`, que adjunta el espejo con el contenedor nombrado (card n5zw). `needsRelaunchToSearch` es falso con
  ese mount: no hay bucle. Lo fija `RestoreICloudDriveOffTests.mountAfterRelaunch_driveOff_attachesTheMirror`.
- **Sin cuenta** sigue «Activa iCloud» (control `RestoreICloudDriveOffUITests.test_withoutAccount_stillAsksForICloud`).
- Tests: `YalaTests/RestoreICloudDriveOffTests` (lógica + cableado) y `YalaUITests/RestoreICloudDriveOffUITests`
  (seam nuevo `-uitest-fake-icloud-drive-off`). Mutante medido: devolviendo la puerta al token, el caso de Drive
  apagado cae con «Restaurar pidió activar iCloud».
- **Fuera de esto**: las esperas del arranque que siguen leyendo el token (`BootSaveGateLogic`, `MigrationGateLogic`)
  son del lote N4 (PR propio, abierto al cerrar este).

## Device-QA (iPhone de pruebas, Yala Dev)

1. Ajustes › tu nombre › iCloud: deja la sesión abierta y **apaga iCloud Drive**.
2. Borra Yala Dev e instálala de nuevo desde Xcode.
3. Abre Yala › «Empezar» › «Ya tengo una cuenta» › «Restaurar desde iCloud».
4. Esperado: Yala pide reabrir una vez; al volver, «Buscando…» y luego «Encontramos tus datos» con tus cifras.
   No debe salir «Activa iCloud para continuar» ni volver a pedir reabrir.
5. Control: cierra sesión de iCloud en el iPhone y repite 2-3. Esperado: «Activa iCloud para continuar».
