---
id: storage-actions-release-the-working-flag-under-a-running-resume
status: backlog
priority: low
area: "modo-nube, migración, ajustes"
created: 2026-09-16
source: "segunda pasada de review de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), lente de copy — duda; anterior a ese ticket"
---

# «Volver a iCloud» confirmado durante un re-kick no hace nada y re-habilita los botones antes de tiempo

## El problema, en lenguaje de usuario

Abro «Volver a iCloud» y paso las dos confirmaciones. Si justo en ese rato la pantalla estaba retomando algo por su
cuenta, mi «sí» no hace nada visible y los botones vuelven a estar activos aunque la app siga trabajando.

## Por qué pasa

- El botón se deshabilita con `controller.isWorking` (`StorageSettingsView.swift:329`), pero las dos confirmaciones
  pueden estar abiertas cuando arranca el re-kick de 30 s o el de primer plano (`rekickIfParked` → `resume()`).
- `resume()` tiene `guard !isWorking`; `startReverse()` y `resetAfterRollback()` no
  (`CloudMigrationController.swift`, `func startReverse`, `func resetAfterRollback`). Ponen `isWorking = true` encima
  del `resume()` en vuelo, el runner descarta sus `submit` por `runGuarded`, y su `defer` baja `isWorking` mientras el
  `resume()` sigue corriendo.
- Resultado: el toque no empieza nada y, salvo que haya una salida de la espera a medias (entonces sale el aviso
  `storage.errors.reversePendingExit`), no se dice nada. Con `isWorking` en `false` antes de tiempo, los botones se
  re-habilitan y el siguiente tick puede re-kickear sobre el `resume()` vivo, que el runner vuelve a descartar.

El journal está a salvo: la exclusión real la da `MigrationRunner.runGuarded`. Lo que miente es la pantalla.

## Criterios de aceptación

- [ ] Una acción de la persona que llega con trabajo en vuelo espera a que suelte (molde de
      `cancelReverseUpload`) o lo dice, en vez de perderse.
- [ ] Ninguna acción baja `isWorking` mientras otra lo tiene tomado.

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` (su `cancelReverseUpload` ya espera a que suelte).
