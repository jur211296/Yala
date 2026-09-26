---
id: ipad-native-app
status: backlog
priority: medium
area: platform
created: 2026-09-09
updated: 2026-09-26
source: idea Jürgen 2026-09-09
---

# App nativa para iPad

## La idea

Una versión de Yala pensada para iPad, no la de iPhone estirada: aprovechar el ancho para ver el
detalle y el contexto a la vez.

## Por qué importa

Las finanzas se revisan sentado. El iPad es donde el usuario compara meses, cuadra cuentas y mira
informes largos — todo lo que en el teléfono obliga a ir y volver entre pantallas.

## Estado

Idea capturada, **sin spec**. Nota de camino, medida el 2026-09-09: la app **ya tiene rastro de
iPad** —el helper de Design System `DS.Adaptive.sheetDetents(_:)`
(`Yala/App/Theme/DesignTokens.swift:436`) existe para adaptar sheets a iPad/Mac, y hay ramas `isWide`
en las vistas de Estadísticas—, así que el punto de partida no es cero. Al hacer spec, medir qué
parte está ya adaptada antes de estimar.

## Exploración (2026-09-26)

Hecha: `docs/exploracion/ipad-nativo.md`, con 45 capturas del simulador (iPad mini e iPad Pro 13", en
vertical y horizontal). Decisión de partida, de Jürgen: **misma app universal, no una app aparte**.
Este ticket pasa a ser el **paraguas** de las fases:

| Fase | Ticket | Prioridad |
|---|---|---|
| 0 · riesgo vivo | [[ipad-multiple-windows-share-one-navigation-state]] | high |
| Cola B | [[floating-buttons-cover-row-amounts-on-ipad-landscape]], [[cola-b-redesigns-must-hold-up-at-ipad-width]] | medium |
| 1 · barra lateral y lista-detalle | [[ipad-sidebar-and-list-detail-for-records-and-planning]] | medium |
| 2 · Grupos, Ajustes, Yala IA al lado | [[ipad-list-detail-for-groups-and-settings-and-chat-inspector]] | low |
| 3 · teclado, puntero, menús | [[ipad-keyboard-shortcuts-pointer-context-menus-and-drop]] | low |
| 4 · varias ventanas | [[ipad-real-multiwindow-with-per-scene-state]] | low |
| 5 · widgets grandes | [[ipad-large-and-extra-large-widgets]] | low |

Se cierra cuando se cierre la fase 1; las demás son mejoras independientes.

## Relacionados

- [[iphone-duo-native-app]] y [[apple-watch]] — la misma tanda de plataformas del 2026-09-09.
- [[yala-android]] — la otra plataforma pendiente.
