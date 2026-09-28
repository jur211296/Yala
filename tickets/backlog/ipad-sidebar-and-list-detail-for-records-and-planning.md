---
id: ipad-sidebar-and-list-detail-for-records-and-planning
status: backlog
priority: medium
area: "platform, ipad, navigation, records, planning"
updated: 2026-09-27
created: 2026-09-26
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.1 y §8, fase 1), 2026-09-26"
---

# iPad · fase 1: barra lateral y lista-detalle en Registros y Planificación

**Paso 5 de 13 del carril adaptativo. Tamaño L. Después de Cola B, tras la release 2.1.**

## Qué cambia para el usuario

En iPad, las secciones de la app pasan a una barra lateral (las de Más, siempre a la vista). En
Registros y Planificación, la lista y el detalle se ven a la vez: tocas un registro o un presupuesto y
se abre al lado, sin perder la lista. Todas las pantallas ganan un ancho legible. En iPhone la navegación
no cambia. Lo mismo vale para el iPhone Duo abierto, que tiene ancho regular.

## Cómo (§5.1 aprobada por Jürgen el 2026-09-27)

Aprobada con una condición: la versión que Apple recomienda, que se adapte sola a cualquier tamaño de iPad, de
ventana y al iPhone Duo abierto. Decisión: ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo».

- `TabView` con `.tabViewStyle(.sidebarAdaptable)` y `TabSection` con las secciones de Más
  (`MoreView`). En iPad se ignora la configuración de pestañas del usuario y desaparecen Más y la
  pestaña temporal.
- En Registros y Planificación, **un único** `NavigationSplitView` de dos columnas que en compact se pliega solo a
  pila (`preferredCompactColumn` para elegir qué se ve). **No** un `if` por size class con dos árboles: al
  redimensionar destruye lo abierto, y en el Duo se redimensiona con cada apertura (foro de Apple, «iOS 27 automatic
  resize»). El detalle de registro deja de ser hoja en ancho regular (cuidado: al cerrarse encadena el editor,
  `DetailContainerView.swift:768`).
- Lo abierto y lo seleccionado viven fuera del contenedor y sobreviven a un redimensionado.
- `AppTab` y los consumidores de `AppRouter` (`AppRouter.swift:23-28`) tienen que alcanzar los destinos
  que hoy solo se alcanzan desde Más.
- **Antes de empezar**: [[sheet-size-follows-the-device-not-the-window]] hecho. El ADR ya está escrito (27-sep).

## Hecho cuando

- Capturas antes/después en `YalaLane-Adapt-iPad-mini` y `YalaLane-Adapt-iPad-Pro-13`, vertical y horizontal:
  barra lateral con todas las secciones; Registros y Planificación con lista y detalle a la vez; ancho legible.
- En `YalaLane-Adapt-iPhone-SE` y `-ProMax`, a tamaño por defecto y a AX5: la navegación de siempre. Diferencias
  solo si las permite la regla del iPhone.
- **Redimensionar** el iPad con Device Hub de pantalla completa a ventana estrecha y vuelta, con un registro abierto:
  el registro sigue abierto (plegado a pila en estrecho, en su columna en ancho). Guion en el ticket si lo corre
  Jürgen.
- Duo abierto, si ya existe `YalaLane-Adapt-iPhone-Duo`: lista y detalle a la vez. Si no existe, lo cubre
  [[iphone-duo-native-app]].
- XCUITest de navegación en `YalaLane-Adapt-iPad-Pro-13` y en `YalaLane-Adapt-iPhone-ProMax`, por UDID.
- Rendimiento medido con Instruments en Registros con la semilla `pesado`.
- Gate verde.

## Relacionados

- [[ipad-native-app]] — paraguas. Depende de [[cola-b-redesigns-must-hold-up-at-ipad-width]].
- Siguientes: [[iphone-duo-native-app]], [[ipad-list-detail-for-groups-and-settings-and-chat-inspector]],
  [[ipad-and-duo-panel-and-statistics-use-the-width]], [[ipad-keyboard-shortcuts-pointer-context-menus-and-drop]].

## Reglas del carril adaptativo (obligatorias)

**Simulador** (Jürgen, 2026-09-27). Este carril usa simuladores dedicados creados con `xcrun simctl create` con
prefijo fijo `YalaLane-Adapt-` (p. ej. YalaLane-Adapt-iPhone-SE, YalaLane-Adapt-iPhone-ProMax,
YalaLane-Adapt-iPad-Pro-13, YalaLane-Adapt-iPad-mini) y los usa SIEMPRE por UDID (`-destination id=<UDID>`), nunca
por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar
simuladores sin ese prefijo (los usa la sesión de Cola A en paralelo). DerivedData propio del worktree
(`-derivedDataPath .ddp`). Receta para crearlos: `docs/exploracion/adaptativo-ipad-duo.md` §6.2.

**iPhone** (Jürgen, 2026-09-27). Se permiten mejoras de adaptación en iPhone si no rompen flujos ni ponen en riesgo
la release 2.1; cada una verificable en simulador con capturas antes/después en tamaños iPhone pequeño/grande y
Dynamic Type grande (`adaptativo-ipad-duo.md` §6.1).

**Layout** (ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo»). Se decide por size class y ancho del
contenedor, nunca por tipo de dispositivo ni orientación; un contenedor que se adapta, no un `if` por size class en
la raíz; APIs de iOS 27.1 solo tras `if #available`.
