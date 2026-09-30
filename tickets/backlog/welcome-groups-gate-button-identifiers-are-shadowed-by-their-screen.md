---
id: welcome-groups-gate-button-identifiers-are-shadowed-by-their-screen
status: backlog
priority: low
area: "testing, groups"
created: 2026-09-30
source: "XCUITest de `sign-out-wipe-abort-loops-the-groups-gate` (medido en el árbol de la corrida)"
---

# Los botones de las pantallas de la puerta de Grupos no tienen su identificador en runtime

## Lo medido (2026-09-30)

`WelcomeGroupsGateView.noticeShell` pone el `accessibilityIdentifier` de la pantalla en su `VStack`, y SwiftUI se lo
aplica a cada hijo pisando el suyo. En el árbol de la corrida, el botón «Volver» de `welcome_groups_gate_wipe_failed`
sale como `welcome_groups_gate_wipe_failed`, no como `welcome_groups_gate_wipe_failed_back`. Todos los `_back`,
`_retry`, `_confirm`, `_continue` y `_wait` de esa vista están muertos igual (inferido: mismo contenedor).

Un test escrito leyendo la vista da un rojo mudo. El XCUITest nuevo busca el botón por el id de la pantalla y lo
dice en un comentario.

## Por dónde va

`.accessibilityElement(children: .contain)` en el contenedor de `noticeShell`, medido con el árbol antes y después (la
regla de `testing.md` sobre identifiers en contenedores). Cambio de accesibilidad: comprobar VoiceOver.

## Criterios de aceptación

- [ ] Los botones de las pantallas de la puerta salen con su propio identificador en el árbol.
- [ ] Los XCUITest que buscan por el id de la pantalla siguen encontrándola.
