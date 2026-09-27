---
id: local-wipes-other-than-sign-out-do-not-look-at-an-in-flight-migration
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-09-27
updated: 2026-09-27
source: "review adversarial de `private-sign-out-proceeds-with-a-migration-in-flight` (2026-09-27)"
---

# Vaciar datos, Empezar de cero y el vaciado remoto no miran si hay un paso de tus datos a la nube en marcha

## El problema, en lenguaje de usuario

Desde `private-sign-out-proceeds-with-a-migration-in-flight`, «Cerrar sesión» no borra nada a mitad de un paso de tus datos
entre iCloud y la nube. Los otros borrados que la persona pide a propósito no hacen esa comprobación. Si hay una subida en
marcha, la nube puede quedarse con lo que se quiso borrar, o el borrado cortar la subida. INFERIDO: no reproducido.

## Medido (2026-09-27, con grep; ninguno lee `uiState`, `isWorking` ni la fase)

- «Vaciar datos»: `UserDataResetView.swift:285`.
- «Empezar de cero»: `ContentView.swift:1961` y `:2079`.
- Obedecer la señal de vaciado remoto: `ShellDataAlertsModifier.swift:237`.
- `armICloudCorpusWipe`: `LateICloudMirrorNoticeView.swift:328`, `WelcomePrivateICloudGateView.swift:917`.

## Criterios de aceptación

- [ ] Decidido, por borrado, si se para con la migración fuera de reposo. Si se para, con la MISMA lectura
  (`MigrationRestReading.live` + `AppleIDChangeCloseLogic.migrationAtRest`), no con una copia.
