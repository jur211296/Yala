---
id: restore-gate-claims-a-wipe-this-device-did-not-do
status: backlog
priority: low
area: "onboarding, sesiones, copy"
created: 2026-09-14
updated: 2026-10-08
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lente de producto"
---

# El Welcome dice «Eliminaste tus datos en este dispositivo» a un teléfono que no eliminó nada

## Lo medido (2026-09-14)

`RestoreOfferGate.wasWiped` lee los dos timestamps del iCloud-KV del Apple ID **sin mirar la sesión**.
`WelcomeRestoreView.startSearch` lo usa para entrar en el estado `.wiped`, que enseña
`welcome.restore.wiped.body` = «Eliminaste tus datos en este dispositivo. Empieza de nuevo cuando
quieras.» y **suprime la oferta de restaurar**.

Antes del arreglo del receptor, esa frase era cierta: si el timestamp estaba puesto, el dispositivo se
había vaciado de verdad. Desde que una sesión en la nube o solo-grupos IGNORA la señal, hay dispositivos
con el timestamp puesto que no vaciaron nada — y se les dice que sí, y se les quita la puerta de
restaurar.

El propio fichero acota su papel («la señal solo decide si OFRECER, nunca dispara wipe»), así que no
destruye: lo que hace es afirmar algo falso y cerrar una salida.

## Criterios de aceptación

- [ ] El estado `.wiped` del Welcome solo se afirma en un dispositivo donde el vaciado ocurrió.
- [ ] Quien ignoró la señal conserva su oferta de restaurar.

## Medido en 2.1 (triage 2026-10-08)

- `RestoreOfferGate.wasWiped` (`RestoreOfferGate.swift:42`) solo compara los dos timestamps. `WelcomeRestoreView.startSearch`
  (`WelcomeRestoreView.swift:251-257`) entra en `.wiped` con él, y el copy sigue en `es.lproj/Localizable.strings:4101`.
- La premisa se cumple solo en parte. Quitar la oferta de restaurar es casi siempre correcto: el vaciado lo emitió otro
  dispositivo y ese borrado bajó por CloudKit, así que el iCloud del Apple ID está vacío. Lo falso es la frase «en este
  dispositivo». Además es falsa para cualquier dispositivo que no emitió la señal, y no solo para las sesiones que la ignoran.
- `low`: es copy. Arreglo probable: un texto que no diga dónde se borró.

Triage 2026-10-08: abierto · medium → low · RestoreOfferGate.wasWiped sigue leyendo solo los timestamps del Apple ID y el copy afirma «en este dispositivo»; ningún commit tocó el gate.
