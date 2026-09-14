---
id: remote-wipe-receiver-has-no-behaviour-test
status: backlog
priority: medium
area: "testing, modo-nube"
created: 2026-09-14
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lente de tests"
---

# El camino que borra por señal remota no tiene ningún test de comportamiento

## Lo medido (2026-09-14)

El eje de sesión del vaciado remoto está cubierto por: la matriz de 16 combinaciones del decisor puro
(comportamiento, fuerte) y `RemoteWipeSignalWiringTests` (source-scan del cableado). **Lo que no existe es
un test que ejercite el camino real**: «llega la señal a un dispositivo en sesión de la nube ⇒ el
`RouterEntryGate` no recibe `.remoteWipe`».

No se puede escribir hoy porque:

- `PreferenceSyncService.checkForRemoteWipeSignal` es `private`, en un singleton con `private init`, y su
  `iKV`/`local` son privados;
- `ContentView.handleRemoteWipeSignal` es `private` de una `View`;
- no hay seam de uitest que escriba `lastWipeTimestamp` en el iCloud-KV (`OwnerKeyValueStore` no contiene
  ni una referencia a `uitest`), y `AppBootstrapper` ni siquiera llama a `bootstrap()` bajo `-uitest`.

Un source-scan es una red contra la regresión del CABLEADO, nunca la del comportamiento. Esa distinción
ya está escrita en `.claude/rules/swiftdata-cloudkit.md` («un escáner prueba que el cambio se APLICÓ, no
lo que HACE»).

## Lo que ya existe para hacerlo

- `CloudSyncFlags.storageMode` tiene override en memoria + `_testResetStorageModeOverride()`.
- `PrivateSessionMark.set/clear/raw` aceptan un `UserDefaults` inyectado.
- Falta solo el punto de entrada: extraer el cuerpo de `checkForRemoteWipeSignal` a una función
  `internal` que reciba `(iKV, local)`, con el `private` actual delegando en ella.

Con eso, un caso real —sesión en la nube + timestamp remoto ⇒ cero intents encolados— mata de una vez los
tres agujeros que el source-scan solo puede cerrar por texto.

## Criterios de aceptación

- [ ] Existe un test que ejercita la detección con el eje apagado y afirma que no se encola el intent.
- [ ] Su control positivo (sesión privada ⇒ sí se encola) está en el mismo fichero.
- [ ] `RemoteWipeSignalWiringTests` dice cuáles de sus scans pasan a ser redundantes.
