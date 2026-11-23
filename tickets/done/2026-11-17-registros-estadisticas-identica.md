---
id: 2026-11-17-registros-estadisticas-identica
status: done
priority: medium
area: "estadisticas, registros"
created: 2026-11-17
updated: 2026-11-17
source: "decisión de Jürgen del 17-nov (17:35 Lima), encargo registros-estadisticas-identica"
---

# Estadísticas › Registros, idéntica a la pestaña Registros

## En lenguaje de usuario

En Estadísticas, el chip Registros enseña ahora exactamente lo mismo que la pestaña Registros: los chips Cuenta ·
Categoría · Más filtros con Lista/Calendario en su fila, «Buscar en Registros» al tirar de la lista hacia abajo, las
mismas filas agrupadas por mes, el mismo calendario, la misma selección y el mismo menú «···». El período de partida es
el de Estadísticas (el período es uno solo para toda la app). En el iPad, con la vista calendario, la página va a una
columna con el calendario a ancho legible, como en Registros.

## Qué se hizo

- `Views/Records/Compartida/RecordsSharedList.swift`: la única entrada a la lista (`RecordsTabView`), sin llaves por
  pantalla. Ofrece el buscador y pinta con el tinte de Registros. Ahí viven también la barra Seleccionar/«···», la del
  modo selección y la lógica de lo abierto cuando la página se estrecha (`RecordsOpenRecordOnNarrowing`).
- `RecordsTabView`: sin `showsQuickFilters` (siempre con chips); lo escrito en el buscador avisa por su propio cierre.
- `RecordsStandaloneView` y `DetailContainerView` montan la pieza compartida. En Estadísticas, buscar solo recalcula la
  lista (no Tendencias ni el Resumen) y la página del chip sigue la regla del calendario de Registros (decisión 66).
- Regla durable en `.claude/rules/swiftui-ds.md` (sustituye a las decisiones 14 y 15 de 2.3 para Estadísticas).

## Probado

- Unit: `YalaTests/RegistrosEstadisticasIguales/RegistrosEstadisticasIgualesTests` (11 casos) y el ajustado de
  `BugsUILote1RecordsSearchSlotWiringTests`.
- XCUITest: `YalaUITests/RegistrosEstadisticasIguales/RegistrosEstadisticasIgualesUITests` (chips y buscador por importe
  en Estadísticas › Registros; cae con el código de antes, donde no estaban).
- Capturas de antes y después en el simulador (iPhone 17 Pro claro, oscuro y girado; iPad Pro 13).

## Guion para el iPhone 14 (falta: Device MCP estaba ocupado por otra app)

1. Abre Yala Dev con datos. Ve a Estadísticas y toca el chip Registros (el último).
   Debe salir, bajo «+ Nuevo registro», la fila Cuenta · Categoría · (Más filtros) y a su derecha Lista/Calendario,
   igual que en la pestaña Registros.
2. Tira de la lista hacia abajo estando arriba del todo. Debe asomar «Buscar en Registros». Escribe un importe que
   tengas (p. ej. «12»): la lista se reduce a esos registros y el resto de Estadísticas no se queda trabado.
3. Toca la X del buscador: la lista vuelve entera.
4. Toca Calendario y luego Lista: se ve igual que en la pestaña Registros.
5. Toca «Seleccionar» (arriba): marca dos registros; abajo sale la barra con Eliminar y Editar. Toca «Cancelar».
6. Gira el teléfono con Estadísticas › Registros a la vista: la cabecera va en banda, como en Registros.
7. Cambia a tema oscuro (Ajustes › Apariencia) y repite el paso 1.

Resultado esperado: en cada paso, lo mismo que la pestaña Registros con el mismo período.

Cerrado en el barrido de QA 2026-11-23 (antes de la build 7): caso 4 de la tabla del barrido; XCUITest con capturas Evidencia: `RegistrosEstadisticasIgualesUITests`, `RegistrosEstadisticasCapturasUITests`
