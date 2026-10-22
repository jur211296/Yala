---
id: ipad-large-and-extra-large-widgets
status: done
priority: low
area: "widgets, ipad"
created: 2026-09-26
updated: 2026-10-02
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.5 y §8, fase 5), 2026-09-26"
---

# iPad · fase 5: widgets grandes y uno extragrande

**Paso 13 de 13 del carril adaptativo. Tamaño S–M. Independiente de las demás fases.**

## Lo medido hoy

Solo tres widgets admiten `.systemLarge`: los dos donuts (`CategoriesPieWidget`, `SubcategoriesPieWidget`)
y Flujo de caja. **Ninguno** admite `.systemExtraLarge`, que es solo de iPad.

## Qué cambia para el usuario

- `.systemLarge` para Presupuestos, Últimos registros y Pagos planificados.
- Un `.systemExtraLarge` «Resumen del mes»: saldo, gasto por categoría y presupuestos en una pieza.

Ojo: un campo nuevo en el DTO del App Group apaga los widgets si no se añade a las dos copias (app y
widgets).

## Hecho cuando

- Capturas de cada widget nuevo en la galería y en la pantalla de inicio de `YalaLane-Adapt-iPad-Pro-13` y
  `YalaLane-Adapt-iPad-mini`, en claro y oscuro.
- Los widgets que ya existían, en `YalaLane-Adapt-iPhone-ProMax`: iguales que antes (el DTO no los apagó).
- Test de que el DTO del App Group decodifica igual en las dos copias. Gate verde.
- Widgets del Duo: no investigados; si hace falta, ticket aparte.

## Relacionados

- [[ipad-native-app]]. [[after-session-redesign-review-widgets-siri-applepay-and-web-copy]] — revisar
  los widgets en Cola B deja el DTO preparado.

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

## Cierre (2026-10-02)

- **Grande** en Presupuestos (6 filas), Últimos registros (7) y Pagos planificados (7). El mediano sigue con 3.
- **Extragrande** nuevo, «Resumen del mes» (`MonthSummaryWidget`): balance y gasto del mes, donut con top 5 + «Otros», y los 4 presupuestos más apretados. Toque por columna: categorías → Estadísticas, presupuestos → Presupuestos; el resto → Panel.
- **DTO sin tocar**: todo sale de campos que ya viajaban. `WidgetDTOParityTests` fija que las dos copias decodifican igual (scan estructural + round-trip con el escritor real), con dos mutantes en el lector verificados en rojo.
- Capturas: `qa/evidencia-ipad-widgets-20261002/` (README con lo que hay y lo que no).
- Duo: no investigado, fuera de alcance.
