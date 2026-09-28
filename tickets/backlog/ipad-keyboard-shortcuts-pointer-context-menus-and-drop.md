---
id: ipad-keyboard-shortcuts-pointer-context-menus-and-drop
status: backlog
priority: low
area: "platform, ipad, accessibility, records"
created: 2026-09-26
updated: 2026-09-27
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.3 y §8, fase 3), 2026-09-26"
---

# iPad · fase 3: atajos de teclado, puntero, menús contextuales y soltar recibos

**Paso 9 de 13 del carril adaptativo. Tamaño M. Después de la fase 1.**

## Lo medido hoy

**0** `.keyboardShortcut`, **0** `.commands`, **0** `.hoverEffect`, **0** arrastrar y soltar, **3**
`.contextMenu` en toda la app (`BudgetsFavoritesSettingsView`, `GroupRecordsView`, `CashFlowDetailLineRow`).

## Qué cambia para el usuario

- **Atajos** en `.commands` (salen al mantener ⌘): ⌘N nuevo registro · ⌘⇧N gasto de grupo · ⌘F buscar ·
  ⌘K Yala IA · ⌘1…⌘6 secciones · ⌘, Ajustes · ⌘E editar el registro abierto · ⌫ borrar con confirmación
  · ↑↓ recorrer la lista.
- **Puntero**: resaltado al pasar sobre filas, tarjetas y chips.
- **Menús contextuales** en filas de registro (editar, duplicar, cambiar categoría, borrar),
  presupuesto, grupo y cuenta. Valen también con pulsación larga en iPhone.
- **Soltar** una imagen o un PDF de recibo sobre Yala abre Nuevo registro por imagen.
- Fuera, a propósito: soltar un registro sobre otra cuenta. Mover dinero con un gesto es demasiado
  fácil de hacer sin querer.

## iPhone y Duo

Los menús contextuales valen también con pulsación larga en cualquier iPhone y en el Duo, y en el Duo Apple los
aparta solo del pliegue. Los atajos y el puntero son de iPad con teclado; en iPhone no se ven.

## Hecho cuando

- En `YalaLane-Adapt-iPad-Pro-13`: cada atajo de la lista lanzado con el teclado del Mac (en el simulador llega como
  teclado físico) hace lo que dice; mantener ⌘ enseña la lista. Capturas.
- Menús contextuales en filas de registro, presupuesto, grupo y cuenta, en el iPad y en `YalaLane-Adapt-iPhone-ProMax`
  con pulsación larga. Capturas.
- Soltar una imagen de recibo sobre Yala en el iPad (arrastrándola desde el Mac al simulador) abre Nuevo registro por
  imagen.
- Resaltado del puntero: no se captura bien en simulador; se anota en el guion de `qa` para un iPad real.
- XCUITest de los atajos principales (⌘N, ⌘F) en el iPad, por UDID. Gate verde.

## Relacionados

- [[ipad-native-app]]. Depende de [[ipad-sidebar-and-list-detail-for-records-and-planning]] (los atajos
  de sección necesitan la barra lateral).

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
