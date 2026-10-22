---
id: welcome-destructive-buttons-are-plain-text-taps
status: backlog
priority: low
area: "ui, onboarding, a11y"
created: 2026-09-10
updated: 2026-10-08
source: "review adversarial del paso 4, lente de SwiftUI/DS"
---

# Los botones destructivos del Welcome son texto pelado: sin `role`, sin área táctil y con menos peso que el que no destruye

## Lo medido (2026-09-10)

`WelcomeRestoreView.startFresh` (el «empezar de cero» del restore) es un `Button` cuyo label es un `Text`
con `DS.Typography.label` y `foregroundStyle(.secondary)`: **sin `role: .destructive`**, sin
`contentShape`, y con el área táctil del propio texto — por debajo de los 44 pt que pide Apple. Abre un
borrado irreversible.

Y hay una asimetría dentro del mismo flujo: cuando ese mismo desenlace se ofrece en un `.alert`
(`ShellDataAlertsModifier`, `UserDataResetView`) sí lleva `role: .destructive`. Lo que cambia el
tratamiento es el contenedor, no la gravedad de lo que hace.

El paso 4 (`welcome-private-fresh-start-skips-icloud-check`) ya no repite el patrón: su
`destructiveButton` lleva `role`, `contentShape` y `minHeight: DS.Button.actionSize`. Lo que queda es el
molde original.

## Alcance

- `WelcomeRestoreView.startFresh`, y cualquier otro `Button` de las vistas de Welcome cuyo label sea un
  `Text` suelto y cuya acción destruya datos. Contarlos antes de tocar nada.
- **No** convertirlos en `YalaSecondaryButton`: ninguna vista de Onboarding lo usa, y cambiar el peso
  visual de un botón destructivo para que compita con el primario es un cambio de producto, no de a11y.

## Criterios de aceptación

- [ ] Todo botón destructivo del flujo Welcome tiene `role: .destructive` y ≥44 pt de área táctil.
- [ ] El peso visual sigue por debajo del primario (la salida que no destruye sigue siendo la evidente).

## Medido en 2.1 (triage 2026-10-08)

- `WelcomeRestoreView`: el botón «Empezar desde cero» bajo «Continuar» (~388) y el secundario de `emptyStateView` (~794) siguen siendo `Button` con un `Text` suelto, sin `role: .destructive` ni área de 44 pt.
- La confirmación que abren (`showStartFreshConfirm`, ~215) sí lleva `role: .destructive`: el borrado no ocurre con un solo toque.

Triage 2026-10-08: abierto · low → low · siguen siendo texto suelto, pero el borrado pasa por una confirmación destructiva.
