---
id: panel-new-record-greyed-out-silently-after-a-fresh-onboarding
status: done
area: panel
priority: high
created: 2026-10-27
updated: 2026-10-27
source: card omw5 del tablero (Jürgen, 2026-10-27 ~18:58 Lima)
---

# Tras un onboarding de cero, «+ Nuevo registro» sale apagado y no se explica

## Qué pasaba

Jürgen vació su iCloud privado e hizo el onboarding de cero. En el Panel, «Nuevo registro», Voz y Foto (y Yala IA,
en la misma fila) salían atenuados. Tenía la cuenta General, y nada decía por qué no podía registrar.

## Causa

La fila se apaga con `canUseVoiceInput`: cuenta activa **y** subcategoría visible. El «Sí, cargar categorías» del
onboarding llamaba a `seedCategoriesIfNeeded`, que sale por su centinela `seedCategoriesExecuted` **antes de mirar
la base**. Con el centinela puesto de una vida anterior (o con categorías viejas en la base en ese instante, que el
espejo se lleva después), el alta terminaba con cuenta y sin ninguna categoría, y nada volvía a sembrar. El botón
«Crear categorías» del selector tenía el mismo agujero. Qué camino exacto siguió su iPhone es inferido: la semilla
no deja telemetría.

## Arreglo

- `seedDefaultCategoriesOnUserRequest`: cuando la persona PIDE las categorías (onboarding, selector, Panel) se
  siembran si no tiene ninguna categoría propia, aunque el centinela diga lo contrario.
- El Panel ya no se queda gris en silencio: con cuenta y sin subcategorías visibles enseña «Crear categorías» y
  «Cada registro va en una categoría, y aún no tienes ninguna.» (molde L3-10). Sin categorías propias las crea ahí
  mismo; con categorías pero ninguna visible, abre Ajustes › Categorías.

Tests: `YalaTests/PanelCreateCategoriesTests` (con control y mutante) y `YalaUITests/PanelCreateCategoriesUITests`
(seed `sin-categorias`).

## Fuera

La fila de Estadísticas y el botón flotante: `stats-row-and-fab-grey-out-silently-without-account-or-categories`.
