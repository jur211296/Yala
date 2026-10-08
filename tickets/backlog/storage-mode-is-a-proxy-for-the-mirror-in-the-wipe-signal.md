---
id: storage-mode-is-a-proxy-for-the-mirror-in-the-wipe-signal
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-09-14
updated: 2026-10-08
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lente de caminos y alcance"
---

# En la ventana del cutover, una sesión privada deja de obedecer el vaciado remoto

## Lo medido (2026-09-14)

Las dos mitades de la señal de vaciado (`wipeSignalsAppleIDDevices` y `wipeSignalObeyedByThisSession`)
usan `storageMode` como PROXY de «¿el store de este teléfono espeja el iCloud del Apple ID?». El repo
tiene la señal DIRECTA —`SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror`,
expuesta como `CloudSessionSignOut.personalMountAttachesMirror`— y la vista del emisor ya la consume dos
líneas más arriba, para `wipeOperation`.

El proxy se rompe en las ventanas donde `.cloud` convive con el espejo VIVO, que el repo declara
legítimas (`StorageModePersistence.isCloudWithMirrorOn`: «legítimo y transitorio durante la ventana de
export del cutover y durante toda la reversa post-mount»):

- **Adopt / alta born-cloud**: `writeCloudArmed` escribe el par, pero **no remonta el store** — «hasta
  que el proceso muera el mirror sigue vivo», y la app solo pide «cierra y vuelve a abrir», que puede
  tardar horas.
- **Reversa E→C**: `.icloud` no vuelve hasta `persistICloudMode`, al final de una cadena journaleada con
  llamadas al servidor.

En toda esa ventana la sesión es privada, las filas SON las del Apple ID, y el dispositivo **deja de
obedecer** la señal. El espejo le baja los borrados igual, así que las filas desaparecen — pero sin
`performLocalWipeForRemoteSync`: sin `resetToDefaults()`, sin reseteo del tema, sin aterrizaje elegido.

Y por `remote-wipe-signal-is-burned-even-when-the-session-ignores-it`, esa señal no vuelve: la ventana no
produce un retraso, produce una pérdida.

## La salvedad por el otro lado

`attachesCloudKitMirror` **tampoco sirve como sustituto directo**: devuelve `false` para
`.neutralNoMirror`, el mount de toda instalación fresca, y `.claude/rules/swiftdata-cloudkit.md` ya
registra que usarlo como pre-filtro apagó una validación entera en el 100 % de su población. Y miente en
los hosts de test, así que cualquier gate que lo lea necesita seam.

## Y desde el 2026-09-14 la ventana también SILENCIA un aviso

`wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal` puso el mismo eje delante del aviso
«Tus datos fueron eliminados de iCloud». En la ventana del cutover la sesión ES privada y sus filas SÍ
son las del Apple ID, pero el eje da `false` ⇒ el aviso **se calla en la única celda donde era verdad**.
El daño es menor que el del borrado perdido —se pierde información, no datos— pero sale del mismo proxy
y se cierra con la misma decisión.

## Criterios de aceptación

- [ ] Decidido si el eje del vaciado remoto lee el mount, el modo, o los dos.
- [ ] Si lee el mount: declara su seam de test, con el default en la verdad del host (`false`).
- [ ] Una sesión privada en la ventana del cutover no pierde su señal de vaciado.

## Medido en 2.1 (triage 2026-10-08)

- `wipeSignalsAppleIDDevices` sigue en `DestructiveScopeLogic.swift:179-181`, con `confirmedPrivateSession && storageMode == .icloud`. `wipeSignalObeyedByThisSession` (`:228-230`) delega en él.
- `StorageModePersistence.isCloudWithMirrorOn` (`CloudSyncFlags.swift:138`) sigue declarando legítima la ventana con `.cloud` y el espejo vivo. `writeCloudArmed` se escribe en `BornCloudSignUpService.swift:377` y `MigrationWorkExecutor.swift:1405/2407`.
- Por qué low: el espejo baja los borrados igual, así que no hay datos en riesgo. Lo que se pierde es el reseteo de preferencias, el aterrizaje y el aviso, y solo dentro de una ventana transitoria del cutover. El gemelo que da lo perdido por definitivo es `remote-wipe-signal-is-burned-even-when-the-session-ignores-it`, que sigue abierto.

Triage 2026-10-08: abierto · medium → low · Los dos extremos de la señal siguen decidiendo con storageMode == .icloud y no con el montaje del espejo; ningún commit cambió el eje después de a64e02e76 y 21477f598 (2026-09-14), que el ticket ya describe
