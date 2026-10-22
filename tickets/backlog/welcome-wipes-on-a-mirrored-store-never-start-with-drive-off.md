---
id: welcome-wipes-on-a-mirrored-store-never-start-with-drive-off
status: backlog
priority: low
area: "welcome, borrado, icloud"
created: 2026-10-15
updated: 2026-10-15
source: "Frank, al arreglar `fresh-start-after-adopt-exit-with-group-changes-ends-in-device-wipe-failed` (2026-10-15). Inferido leyendo el código, sin medir en device."
---

# Con iCloud Drive apagado y el espejo adjunto, los borrados del Welcome no empiezan nunca

## Qué se sabe

Los tres borrados del Welcome esperan al import de iCloud antes de guardar cuando el store espeja
(`ICloudPersonalCorpusProbe.mirrorWillSync()`): `performDeviceCorpusWipe`, `performICloudCorpusWipe` y la subida de
grupos previa (`drainGroupsBeforeFreshStart`, en `ContentView`). La espera es
`iCloudSyncService.waitForImportQuiescence`, cuya primera línea es `guard isAccountAvailable else { return false }`, e
`isAccountAvailable` es el token de iCloud **Drive** (`SwiftDataConfiguration.isICloudAvailable()`).

Con Drive apagado el mount es `.localNoMirror`, que adjunta el espejo (`attachesCloudKitMirror == true`). Ahí la espera
devuelve `false` al instante y el borrado sale con `importNotQuiescent`: la puerta enseña «No pudimos borrar todo · puede
que parte de tus datos ya no esté», sin haber borrado nada, en cada intento.

Es el gemelo, en sentido contrario, de `groups-sign-out-quiescence-gate-fails-open-with-drive-off`: allí la falta del
token abre la puerta; aquí la cierra para siempre.

## Lo que no se sabe (por qué es `low`)

- **Si la población existe.** En el Welcome normal el mount es `.neutralNoMirror` y no se espera nada. Hace falta un
  Welcome con el espejo adjunto (uno que se mató a mitad y relanzó con el fichero del store ya creado) **y** Drive
  apagado. Sin medir.
- Si con Drive apagado y CloudKit vivo el espejo importa de verdad (entonces esperar tiene sentido, pero con otro
  testigo de cuenta).

En el simulador se vio la misma salida por otra causa (el testigo del mount miente bajo `-uitest`), ya arreglada en el
seam: no prueba nada sobre producción.

## Criterios de aceptación

- [ ] Medido en device si un Welcome con `.localNoMirror` llega a estos borrados.
- [ ] Si llega: la espera usa un testigo de cuenta que no dependa de iCloud Drive, o el texto del fallo dice que no se
      borró nada.
