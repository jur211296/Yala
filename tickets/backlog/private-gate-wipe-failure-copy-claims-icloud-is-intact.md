---
id: private-gate-wipe-failure-copy-claims-icloud-is-intact
status: backlog
priority: medium
area: "onboarding, modo-nube, l10n"
created: 2026-09-14
source: "review adversarial del PR de `activation-restore-start-fresh-keeps-the-imported-rows` (2026-09-14); NO reproducido en device"
---

# Si el borrado falla a mitad, la app dice que iCloud sigue intacto — y ya no lo está

## El síntoma, en lenguaje de usuario

Confirmo dos veces que quiero borrar mis datos de iCloud. Algo falla a medias y la app me dice: **«Tus
datos siguen en iCloud, intactos»**. No es verdad: la zona ya se borró y lo que queda en el teléfono está
a medio vaciar.

## Lo medido (2026-09-14)

- `performICloudCorpusWipe` (`ContentView.swift`) borra **primero** la zona de CloudKit
  (`ICloudPersonalCorpusProbe.wipe()`) y **después** las filas locales. `wipeAllUserData` guarda por
  lotes, así que un fallo a media lista devuelve `"localWipeFailed"` con la zona ya borrada.
- La fase `.wipeFailed` de `WelcomePrivateICloudGateView` (`:202-216`) enseña un copy único
  (`es-419.lproj/Localizable.strings:5711`) que afirma que iCloud sigue entero.
- **El copy correcto ya existe en el mismo fichero**: `wipeDeviceFailedBody` («puede que parte de tus
  datos ya no esté y el resto siga aquí»), que es exactamente el estado real.
- El motivo del fallo **ya viaja distinguido** (`"localWipeFailed"` frente a `"importNotQuiescent"` y los
  `CKError`), así que no hace falta ninguna señal nueva: solo llevarlo dentro de la fase.
- Aplica a los dos consumidores de la puerta. En el de la activación
  (`.restoreDiscardGate`, desde el 2026-09-14) la salida además empeora: «volver» lleva a la pantalla de
  Restaurar, que va a ofrecer restaurar de una cuenta que acaba de desaparecer.

## Criterios de aceptación

- [ ] Un fallo LOCAL tras haber borrado la zona enseña el copy que dice que parte de los datos ya no está.
- [ ] Un fallo de la ZONA (no se llegó a borrar nada) sigue diciendo que iCloud está intacto.
- [ ] Sin claves nuevas: se reusa `wipeDeviceFailedBody`, ya traducida en los 16 locales.

## Relacionados

- [[activation-restore-start-fresh-keeps-the-imported-rows]] · [[restore-start-fresh-keeps-the-imported-corpus]]
