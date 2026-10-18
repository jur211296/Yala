---
id: export-filters-reset-when-the-text-size-changes
status: backlog
priority: low
area: "export, accessibility"
created: 2026-10-18
updated: 2026-10-18
source: "visto al sacar las capturas de la entrega 4 de la tarjeta con varias divisas (`multi-currency-accounts-4-reports-and-export`)"
---

# Cambiar el tamaño del texto con el asistente de exportación abierto devuelve las cuentas a «todas»

## Qué pasa

Con el asistente de Exportar abierto y solo una cuenta marcada, cambiar el tamaño del texto del sistema (Ajustes ›
Pantalla, o el Centro de Control) devuelve el filtro de cuentas a «(Todas las cuentas)», con todas marcadas. Medido el
2026-10-18 en el simulador (iPhone 17 Pro, iOS 27.0) con `simctl ui content_size`: de `large` a `extra-large`, la
selección «(2 seleccionadas)» pasa a «(Todas las cuentas)». Ir a «Siguiente» y volver NO la pierde.

## Por qué, inferido y sin medir

`ExportFiltersStepView` guarda la selección en `@State` y la inicializa a «todas» en el `onAppear` si
`hasInitializedAccounts` es `false`. Que se reinicie apunta a que la vista se vuelve a crear con el cambio de entorno
(otra identidad aguas arriba), no a la lógica de la selección: es anterior a la entrega 4.

## Qué haría falta

Medir dónde cambia la identidad (quien presenta la hoja desde Perfil) y que la selección sobreviva a un cambio de
entorno. Quien exporta con una sola cuenta y cambia el texto a mitad acabaría exportando todo sin darse cuenta.
