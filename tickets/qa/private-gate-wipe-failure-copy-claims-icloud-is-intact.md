---
id: private-gate-wipe-failure-copy-claims-icloud-is-intact
status: qa
updated: 2026-09-27
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

- [x] Un fallo LOCAL tras haber borrado la zona enseña el copy que dice que parte de los datos ya no está.
- [x] Un fallo de la ZONA (no se llegó a borrar nada) sigue diciendo que iCloud está intacto.
- [x] Sin claves nuevas: se reusa `wipeDeviceFailedBody`, ya traducida en los 16 locales.

## Relacionados

- [[activation-restore-start-fresh-keeps-the-imported-rows]] · [[restore-start-fresh-keeps-the-imported-corpus]]

## Añadido 2026-09-27 (review de `private-gate-remote-wipe-can-strand-its-arm`)

La misma mitad a medias tiene un segundo síntoma, fuera del copy: salir de `.wipeFailed` por `leaveGate` desarma
con `clearICloudCorpusWipeArm()`, que también borra `icloudCorpusWipeZoneDone`. El aviso tardío ya usa
`disarmFailedICloudCorpusWipe()`, que en ese caso deja «a medias» (`leaveICloudCorpusWipeHalfway`). En la puerta
nadie recuerda que iCloud quedó vacío con lo del teléfono dentro. Inferido por lectura, sin reproducir.

## Resuelto (2026-09-27)

**Qué cambia para el usuario.** Si el borrado de iCloud de la puerta privada falla con iCloud ya borrado, la pantalla
dice «No pudimos terminar. Puede que parte de tus datos ya no esté y el resto siga aquí» en vez de «Tus datos siguen en
iCloud, intactos». Si falla antes de tocar iCloud, sigue diciendo «intactos», que ahí es verdad. Vale para los tres
sitios que montan la puerta.

**Cómo.** La fase de fallo lleva dentro si la zona se había ido: `.wipeFailed(zoneGone:)`. El dato sale de la marca
durable `isICloudCorpusWipeZoneDone()`, leída una vez tras el borrado y compartida con `gateWipeSettles`. El texto lo
elige `WelcomePrivateICloudGateView.wipeFailedBody(zoneGone:)`.

**Premisa corregida.** El ticket proponía decidir por el motivo (`"localWipeFailed"`). Medido: un reintento desde el
estado a medias que falla EN la zona devuelve un error de CloudKit con la zona ya borrada por el intento anterior, y ese
motivo diría «intactos». La marca la escribe quien cruza la zona y no depende del motivo.

**Aparcado.** El «Añadido 2026-09-27» (salir sin olvidar la zona) va a
`private-gate-leave-after-a-halfway-wipe-forgets-the-zone`: el remedio del aviso tardío es `.handover` y en la puerta
de la activación purgaría los grupos de quien activa.

**Verificado.** `PrivateGateWipeFailureCopyTests` (texto por caso, marca que sobrevive al re-arme, cableado) y los
source-scans existentes actualizados.

## Guion de device-QA (opcional)

El fallo con la zona ya borrada **no se puede provocar a mano**: exige que falle el guardado local a mitad de lista. Lo
que sí se puede mirar es que el caso de siempre no cambió:

1. iPhone con una cuenta de iCloud que tenga datos de Yala. Borra la app e instálala desde TestFlight.
2. Abre Yala → «Es mi primera vez» → «Privado». Sale el aviso «Encontramos datos tuyos en iCloud».
3. Toca «Empezar de cero» y confirma en la segunda pantalla. **Justo al confirmar, activa el modo avión.**
4. Esperado: «No pudimos borrar todo» con «Tus datos siguen en iCloud, intactos. Revisa tu conexión…».
5. Quita el modo avión y toca «Volver a intentarlo»: el borrado termina y sigue al onboarding.
