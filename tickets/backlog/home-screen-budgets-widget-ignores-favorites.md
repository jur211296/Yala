---
id: home-screen-budgets-widget-ignores-favorites
status: backlog
priority: medium
area: "budgets, widgets"
created: 2026-10-17
updated: 2026-10-17
source: "implementación UX 2.2 · lote 9 (presupuestos)"
---

# El widget de Presupuestos de la pantalla de inicio no mira los favoritos

Medido al implementar L9-11/L9-12 (2026-10-17): las estrellas de Perfil › Presupuestos y el nuevo «Mostrar en el widget» solo deciden la tarjeta de Presupuestos del **Panel**. El widget de la pantalla de inicio (`YalaWidgets/Widgets/BudgetsWidget.swift`, `createEntry`) enseña en modo automático los N con más porcentaje gastado, o los que se eligen al configurar el widget; no lee `isFavorite`. La pantalla de favoritos dice «aparecen en el widget de Presupuestos (3 en mediano, 5 en grande)», que son los tamaños de la tarjeta del Panel, y quien lo lea pensando en la pantalla de inicio espera otra cosa.

Decisión para Jürgen: (A) dejarlo y que el texto diga «la tarjeta del Panel»; (B) que el modo automático del widget de inicio enseñe los favoritos primero; (C) otra.

## Hecho cuando

Lo que se marca con la estrella sale donde la pantalla dice que sale, en las dos superficies o con el texto corregido.
