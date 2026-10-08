---
id: apple-id-close-loss-notice-uitest-fails-on-2-1
status: backlog
priority: low
area: "testing, sesiones, grupos"
created: 2026-09-29
updated: 2026-10-08
source: "gate de sheet-size-follows-the-device-not-the-window, 2026-09-29"
---

# El XCUITest del aviso de pérdida al cambiar de Apple ID falla en `2.1`

## Qué pasa

`AppleIDCloseNoticeUITests.test_blockedClose_offersTheLoss_notNowKeepsEverything_andLeavesTheCoordinatorFree` cae en su
línea 117: «El aviso no cuenta los cambios que se perderían» (`staticTexts` con `label CONTAINS "sin subir: 1"`).

**La app está bien, el test no.** Reproducido a mano con los mismos argumentos (`-uitest-seed minimal
-uitest-apple-id-changed -uitest-groups-outbox-pending`) y «Cerrar sesión y quitarlos»: la etapa
`apple_id_close_losing_group_changes` enseña «No pudimos cerrar tu sesión» y «Cambios de grupos sin subir: 1. Solo se
suben con la cuenta que los apuntó…», con «Ahora no» y «Cerrar sesión y perderlos».

## Lo medido (2026-09-29)

- `YalaLane-Adapt-iPhone-ProMax`, iOS 27.0, por UDID y en cola, centinela limpio.
- **`2.1` en `435bd8eb`, sin cambios: 2 de 2 en rojo.** El árbol de `sheet-size-follows-the-device-not-the-window`: 3 de
  3 en rojo, mismo mensaje. No depende de ese cambio.
- `AppleIDCloseNoticeView.swift` y `SignOutBlockedCopy.swift` cambiaron por última vez en `159191c4` (#296, 28-sep).

## Hipótesis (inferida, sin medir)

El test comprueba `cifra.exists` justo después de `blocked.waitForExistence`, sin esperar. Si la etapa se monta antes
de que llegue la cifra, o el texto se pinta primero con la copia «sin cifra», `exists` da falso. Lo primero es mirar el
árbol en el instante de la aserción; si es eso, `waitForExistence` en `cifra`.

## Relacionados

- [[queued-offer-after-dismiss-flakes-on-a-cold-simulator]] — otro caso del mismo fichero, distinto modo de fallo.

## Medido en 2.1 (triage 2026-10-08)

- La aserción sin espera sigue igual, ahora en `YalaUITests/Flows/AppleIDCloseNoticeUITests.swift:172-173` (era `:117`).
- En la nocturna de `2.1` del 2026-10-08 (run `37802106095`, iOS 26.5) el caso pasa a la primera. El rojo del ticket se midió en iOS 27.0 (ProMax), y no se ha vuelto a medir ahí.

Triage 2026-10-08: abierto · medium → low · pasa en el CI de 2.1 (iOS 26.5, run 37802106095) pero la aserción sigue sin esperar (:172-173) y el rojo de iOS 27.0 no se ha re-medido.
