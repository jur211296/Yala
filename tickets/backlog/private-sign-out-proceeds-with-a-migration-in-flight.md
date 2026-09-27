---
id: private-sign-out-proceeds-with-a-migration-in-flight
status: backlog
priority: medium
area: "sesiones, modo-nube"
created: 2026-09-27
updated: 2026-09-27
source: "review adversarial de `apple-id-change-boot-check-runs-before-the-migration-guard-can-see` (2026-09-26), lentes de fail-open y de cobertura; previo a ese diff"
---

# Cerrar la sesión privada no comprueba si hay un paso de datos a la nube en marcha

## El problema, en lenguaje de usuario

El aviso de «cambiaste de Apple ID» ya no sale a mitad de una migración a la nube. Pero si la persona cierra la sesión
privada por otro camino —la fila de Perfil, o el botón de un aviso que se ofreció antes de que la migración empezara—,
Yala cierra igual. Cerrar ahí puede borrar lo local mientras sube.

## Por qué pasa (medido el 2026-09-26 con grep; el escenario, inferido)

- Ni `CloudSessionSignOut.swift`, ni `CloudSignOutFlowLogic.swift`, ni `ProfileView.swift` leen `uiState`, `isWorking` ni la
  fase del journal para decidir el cierre privado. La única lectura de `uiState` en `ProfileView` decide si se ve la
  fila de Almacenamiento.
- `AppleIDCloseNoticeView.requestClose` elige la celda por `CloudSyncFlags.storageMode`, que sigue en `.icloud` hasta el
  cutover, y no mira la migración. El aviso puede esperar en la cola del router y contestarse más tarde.
- El guard del aviso automático (`AppleIDChangeCloseLogic.migrationAtRest`) solo protege la OFERTA.

## Criterios de aceptación

- [ ] El escritor del cierre privado (no cada pantalla) se para con la migración fuera de reposo, con el mismo predicado
  (`migrationAtRest`) y un motivo propio en el aviso.
- [ ] Test del escritor con la migración en vuelo + control positivo en reposo.
