---
id: invite-paste-under-join-button-on-iphone-18-pro
status: backlog
priority: low
area: groups
created: 2026-11-09
updated: 2026-11-09
source: "merge de 2.2 en 2.3 (2026-11-09): XCUITest corrido en un segundo simulador"
---
# En el iPhone 18 Pro, «Pegar» queda 2 pt bajo «Unirme al grupo»

`InviteRecoveryPasteVisibleUITests.test_longLinkWithKeyboard_joinButtonDoesNotCoverPaste` sale rojo en el simulador
**iPhone 18 Pro** (iOS 27.2): «Pegar» acaba en y≈509 y el botón empieza en y=507. En el iPhone 17 Pro, el simulador de
siempre, pasa.

Medido el 2026-11-09: rojo igual con `origin/2.3` compilado aparte (no lo trae el merge de 2.2) y con el merge.

Qué falta: ver si con ese alto el scroll no lleva «Pegar» del todo por encima del borde (`revealPaste` / `pasteAnchor`
en `InviteRecoveryView`) o si el test debe tolerar el redondeo. Dos puntos de solape apenas se ven; prioridad baja.
