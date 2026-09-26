---
id: ipad-sidebar-and-list-detail-for-records-and-planning
status: backlog
priority: medium
area: "platform, ipad, navigation, records, planning"
created: 2026-09-26
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.1 y §8, fase 1), 2026-09-26"
---

# iPad · fase 1: barra lateral y lista-detalle en Registros y Planificación

**Tamaño L. Después de Cola B, tras la release 2.1.**

## Qué cambia para el usuario

En iPad, las secciones de la app pasan a una barra lateral (las de Más, siempre a la vista). En
Registros y Planificación, la lista y el detalle se ven a la vez: tocas un registro o un presupuesto y
se abre al lado, sin perder la lista. Todas las pantallas ganan un ancho legible. En iPhone no cambia
nada.

## Cómo (propuesta, pendiente de aprobar)

- `TabView` con `.tabViewStyle(.sidebarAdaptable)` y `TabSection` con las secciones de Más
  (`MoreView`). En iPad se ignora la configuración de pestañas del usuario y desaparecen Más y la
  pestaña temporal.
- En Registros y Planificación, `NavigationSplitView` de dos columnas solo en regular. El detalle de
  registro deja de ser hoja en iPad (cuidado: al cerrarse encadena el editor,
  `DetailContainerView.swift:768`).
- `AppTab` y los consumidores de `AppRouter` (`AppRouter.swift:23-28`) tienen que alcanzar los destinos
  que hoy solo se alcanzan desde Más.
- **Antes de empezar**: ADR con la estructura, una vez aprobada.

## Hecho cuando

- Capturas antes/después en iPad mini, iPad Pro 13" e iPhone (el iPhone igual que antes).
- XCUITest de navegación en un destino iPad.
- Rendimiento medido con Instruments en Registros con la semilla `pesado`.

## Relacionados

- [[ipad-native-app]] — paraguas. Depende de [[cola-b-redesigns-must-hold-up-at-ipad-width]].
- Siguientes: [[ipad-list-detail-for-groups-and-settings-and-chat-inspector]],
  [[ipad-keyboard-shortcuts-pointer-context-menus-and-drop]].
