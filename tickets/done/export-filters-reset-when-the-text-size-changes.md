---
id: export-filters-reset-when-the-text-size-changes
status: done
priority: low
area: "export, accessibility"
created: 2026-10-18
updated: 2026-11-05
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

## Resuelto (2026-11-05, lote P5 de la 2.3)

**Medido en el simulador (iPhone 17 Pro, iOS 27.2) antes de tocar nada**, sobre la pantalla única de Exportar: el
problema era más grande que las cuentas. Con dos cuentas marcadas («Exportar 2 registros»), `simctl ui content_size
extra-large` dejaba la hoja como recién abierta: «Exportar 5 registros» y «Más opciones» plegado. Instrumentado: la
vista de Exportar se desmontaba y se volvía a montar (`onDisappear`/`onAppear`, `@State` nuevo) sin que la hoja se
cerrara, sin que `activeSheet` cambiara y sin que la lista de Ajustes se remontara.

**Causa**: el `.sheet(item: $activeSheet)` colgaba del contenido RAÍZ de la `NavigationStack` de Ajustes
(`listColumn`). La hoja de Ajustes que presenta el Panel cuelga fuera de su pila y no lo sufre.

**Arreglo**: las hojas de Ajustes (datos personales, importar, exportar) cuelgan del contenedor de la pila
(`ProfileView.settingsSheets`, aplicado en `body`), como las alertas del cierre de sesión.

**Medido después**, con un conductor XCUITest que espera un fichero de señal mientras el host cambia el tamaño: con el
arreglo, «Exportar 2 registros» antes y después, «Más opciones» abierto; control con la `ProfileView` de antes: «2» →
«5», plegado (rojo). La red que queda en el repo es `ProfileSheetsAnchorWiringTests`: el XCUITest no puede cambiar el
tamaño del texto con la app abierta. Regla nueva en `swiftui-ds.md`. Las otras hojas colgadas de la raíz de una pila no
están auditadas.
