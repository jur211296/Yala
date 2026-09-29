---
id: ipad-list-detail-for-groups-and-settings-and-chat-inspector
status: backlog
priority: low
area: "platform, ipad, groups, settings, chat"
created: 2026-09-26
updated: 2026-09-27
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.1, §5.2 y §8, fase 2), 2026-09-26"
---

# iPad · fase 2: Grupos y Ajustes en dos columnas, y Yala IA al lado de los datos

**Paso 7 de 13 del carril adaptativo. Tamaño M. Después de la fase 1.**

## Qué cambia para el usuario

- **Grupos**: la lista de grupos a la izquierda y el grupo abierto a la derecha, sin que desaparezca la
  navegación (hoy abrir un grupo oculta la barra de pestañas).
- **Ajustes**: dejan de vivir en una hoja pequeña con pilas dentro; en iPad son una pantalla de dos
  columnas, como la app Ajustes del sistema.
- **Yala IA**: se abre como columna lateral (`.inspector`) y convive con el Panel, Registros o
  Estadísticas. Preguntas mirando los números. En iPhone sigue siendo la hoja de hoy.
- *Panel y cabeceras* salieron el 27-sep a su propio ticket, [[ipad-and-duo-panel-and-statistics-use-the-width]].

Todo lo de arriba vale igual en el **iPhone Duo abierto** (ancho regular). Grupos y Ajustes con el mismo
`NavigationSplitView` único que se pliega en compact de la fase 1; el inspector de Yala IA, en compact, sigue siendo
la hoja de hoy (SwiftUI lo hace solo con `.inspector`). Apple: en el Duo, las barras de un inspector se quedan
horizontales.

## Hecho cuando

- Capturas antes/después en `YalaLane-Adapt-iPad-mini` y `YalaLane-Adapt-iPad-Pro-13`, vertical y horizontal: Grupos
  con lista y grupo a la vez; Ajustes en dos columnas; Yala IA en columna junto a Panel, Registros y Estadísticas.
- En `YalaLane-Adapt-iPhone-SE` y `-ProMax`: Grupos, Ajustes y Yala IA como hoy (la hoja del chat incluida), o con
  las diferencias que permite la regla del iPhone.
- Redimensionar el iPad con Device Hub con un grupo abierto y con el chat abierto: no se pierde ni el grupo ni la
  conversación.
- Duo abierto, si ya existe su simulador. XCUITest de Grupos y Ajustes en un iPad y un iPhone del carril, por UDID.
  Gate verde.

## Relacionados

- [[ipad-native-app]]. Depende de [[ipad-sidebar-and-list-detail-for-records-and-planning]].
- Se apoya en [[settings-redesign-as-grouped-lists-like-ios]] y [[ai-chat-reads-heavier-than-a-messaging-app]].

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
