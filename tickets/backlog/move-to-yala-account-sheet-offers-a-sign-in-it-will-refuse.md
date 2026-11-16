---
id: move-to-yala-account-sheet-offers-a-sign-in-it-will-refuse
status: backlog
area: cloud-sync
priority: low
created: 2026-11-16
updated: 2026-11-16
source: card 120i del tablero (detalles menores del barrido final de 2.3), punto 2
---

# «Pasar a tu cuenta de Yala» ofrece «Continuar con Google» y luego dice que no está disponible

## Qué pasa

Barrido final de 2.3 (iPhone 14, 15-nov). En modo iCloud, tras volver desde una cuenta de Yala, «Pasar a tu cuenta de
Yala» abre la hoja con «Continuar con Google». Solo al tocarlo dice «Pasar otra vez a ella todavía no está disponible»
(`storage.migrateBlock.returnedBody`). La hoja no debería ofrecer un camino que va a rechazar.

## Por qué no entró en el lote del 16-nov

El rechazo lo decide hoy el SERVIDOR al comprobar la cuenta (`StorageMigrationIdentityGateLogic.blockForClaimRefusal`,
`existing_stable` sobre una cuenta solo-grupos): el teléfono no sabe de antemano que esa cuenta volvió a iCloud. La
tarjeta ya recuerda el rechazo para la sesión viva (`cardRefusal`), pero no antes del primer intento. Arreglarlo pide una
marca local de «este teléfono volvió desde la cuenta X» o una comprobación antes de abrir la hoja: cambio de diseño en la
migración, no un arreglo de lote.

## Cómo se reproduce

1. Yala en una cuenta de Yala; Ajustes › Dónde viven tus datos › Volver a tu iCloud, hasta terminar.
2. En la misma pantalla, «Pasar a tu cuenta de Yala».
3. Sale la hoja con «Continuar con Google»; al tocarlo, «Pasar otra vez a ella todavía no está disponible».
