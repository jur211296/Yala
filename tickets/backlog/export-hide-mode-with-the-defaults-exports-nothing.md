---
id: export-hide-mode-with-the-defaults-exports-nothing
status: backlog
priority: medium
area: "export"
created: 2026-10-28
updated: 2026-10-28
source: "medido en el simulador durante el lote panel-filtros-moneda (2026-10-28), al capturar el monto de Exportar"
---

# Exportar en «Ocultar» con lo que viene marcado no exporta nada

## Qué le pasa al usuario

En Ajustes › Exportar registros › Más opciones, elegir «Ocultar» sin tocar nada más deja «Ninguno con estos filtros» y
el botón apagado. Para exportar en ese modo hay que DESMARCAR todo lo que no se quiere ocultar: cuentas, etiquetas,
necesidades y monedas.

## Medido

- iPhone 17 Pro, iOS 27.0, seed `minimal`, 2026-10-28: «Ocultar» por defecto → «Ninguno con estos filtros». Captura:
  `/Users/jur/Claude/worktrees/_capturas/2026-10-28-panel-filtros-moneda/hallazgo-exportar-ocultar-por-defecto-ninguno.png`.
- El asistente arranca con todas las cuentas, etiquetas, necesidades y monedas marcadas (`ExportRecordsView`: estado
  inicial y el `onChange` de cuentas que marca todas sus monedas). Con un solo modo global (`isExcludeMode`), en
  «Ocultar» lo marcado se OCULTA (`TransactionsExportService.applyInMemoryFilters`, pasos 1, 4, 6b y 7): todo.
- Preexistente, no lo introdujo este lote. Registros › Filtros no lo tiene: allí cada lista arranca vacía.

## Qué hacer

Decidir el comportamiento al cambiar de modo (vaciar lo marcado al pasar a «Ocultar», o dos listas como Registros).
Es diseño del asistente: pide a Jürgen antes de tocarlo.
