---
id: ipad-keyboard-shortcuts-pointer-context-menus-and-drop
status: backlog
priority: low
area: "platform, ipad, accessibility, records"
created: 2026-09-26
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.3 y §8, fase 3), 2026-09-26"
---

# iPad · fase 3: atajos de teclado, puntero, menús contextuales y soltar recibos

**Tamaño M. Después de la fase 1.**

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

## Relacionados

- [[ipad-native-app]]. Depende de [[ipad-sidebar-and-list-detail-for-records-and-planning]] (los atajos
  de sección necesitan la barra lateral).
