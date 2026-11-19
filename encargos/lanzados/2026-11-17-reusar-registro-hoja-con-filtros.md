Yala
# Pagos planificados: botón «Reusar» y hoja de registros con los filtros y el buscador de Registros
---
toca: Yala/App/Views/Planning/PagosRecurrentes/RecurringFromRecordSheet.swift,Yala/App/Views/Planning/ScheduledPaymentsListView.swift,Yala/App/Views/Planning/ScheduledPaymentsView.swift,Yala/Resources/de.lproj/ReusarRegistro.strings,Yala/Resources/en-GB.lproj/ReusarRegistro.strings,Yala/Resources/en.lproj/ReusarRegistro.strings,Yala/Resources/es-419.lproj/ReusarRegistro.strings,Yala/Resources/es-AR.lproj/ReusarRegistro.strings,Yala/Resources/es-ES.lproj/ReusarRegistro.strings,Yala/Resources/es.lproj/ReusarRegistro.strings,Yala/Resources/fr.lproj/ReusarRegistro.strings,Yala/Resources/it.lproj/ReusarRegistro.strings,Yala/Resources/ja.lproj/ReusarRegistro.strings,Yala/Resources/nl.lproj/ReusarRegistro.strings,Yala/Resources/pl.lproj/ReusarRegistro.strings,Yala/Resources/pt-BR.lproj/ReusarRegistro.strings,Yala/Resources/pt-PT.lproj/ReusarRegistro.strings,Yala/Resources/pt.lproj/ReusarRegistro.strings,Yala/Resources/zh-Hans.lproj/ReusarRegistro.strings,YalaTests/ReusarRegistro/,tickets/done/2026-11-17-reusar-registro-hoja-con-filtros.md
depende: Yala/pagos-que-se-repiten-banner-y-hoja
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3, con «Pagos que se repiten: banner en Planificación…» ya mergeado (toca los mismos archivos de Planificación). La vista de Registros de Estadísticas va en otra sesión aparte («Registros de Estadísticas idéntica a Registros»): no la toques. Los componentes de `Yala/App/Views/Records/Components/` se reutilizan sin modificarlos; si hiciera falta un cambio ahí, mínimo y anotado.

## Qué pidió Jürgen (17-nov, 17:35 Lima, con capturas de TestFlight)
**A · Botón «Desde un registro» en Pagos planificados** (junto a «+ Nuevo pago planificado»):
1. Nombre corto para que el botón no crezca: recomendado **«Reusar»** con su ícono. Regla dura: **nunca un botón debajo del otro**, tampoco en el iPhone más chico (SE) ni con texto grande; si «Reusar» no cabe en una línea junto al otro en algún tamaño, ese botón pasa a **solo ícono** (con etiqueta de accesibilidad). Nada de «Buscar» (confunde).
2. La hoja que abre («Elige un registro», hoy una lista simple con buscador) pasa a **detent large** y se parece a **Registros**: arriba los **mismos filtros rápidos** de Registros (Cuenta, Categoría, el de más filtros) y un **buscador**, y las **mismas filas** de Registros (ícono de color de subcategoría, cuenta, monto, prioridad), agrupadas por día. Flexible para encontrar rápido el registro a reusar. Tocar uno sigue el flujo de hoy (crea el pago planificado desde ese registro). Reutiliza los componentes de `Yala/App/Views/Records/Components/` (RecordsQuickFilterBar, RecordsListSearchField, RecordRowView, RecordDateSectionView), sin duplicarlos.


## Cómo entregar
- Textos nuevos en es-419 neutro y en los 16 idiomas en una **tabla propia** `ReusarRegistro.strings` (`String(localized:table:)`), no en Localizable.strings. Carpetas sincronizadas: no hace falta tocar el pbxproj.
- Probar en claro, oscuro, con el iPhone girado, en iPhone SE (simulador) y en el iPhone 14 por DeviceMCP. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Tests en `YalaTests/ReusarRegistro/`.
- Entregable visual: artifact de Claude con antes y después (botones en SE y 14, y la hoja). Nunca Markdown ni PDF.

## Reglas
- Sin esquema de datos nuevo. Commits y PR sin firma de IA, PR contra 2.3. Toca solo lo declarado; si hace falta otro archivo, mínimo y anotado en «Decidido sin consultar».
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión», sin mergear ni desplegar lo incompleto).
- Cierre: si está completo, CI verde y el modo lo permite, `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

1. **Base: `2.3`, no la rama del banner.** El encargo declara `depende:` del PR de «Pagos que se repiten: banner…», pero ese PR sigue abierto y con conflictos contra 2.3. Lo único que comparte con este encargo en `ScheduledPaymentsView.swift` son dos comentarios junto al banner; mi cambio en ese fichero está en otro tramo (la hoja). Basarme en su rama arrastraría su conflicto a mi PR.
2. **Los filtros de la hoja son propios, no los de la sesión.** La barra rápida de Registros escribe en `SessionState.shared`, que comparten el Panel, Estadísticas y Registros: filtrar por una cuenta para encontrar el registro a reusar dejaría la app filtrada al cerrar. La hoja usa un modelo propio (`ReusarRegistroFilters`) que nace vacío y muere con ella.
3. **Se reusan los componentes, con un cambio mínimo en dos (anotado):** `RecordsQuickFilterBar` pasa a aceptar cualquier modelo con los tres conjuntos y `showFiltersSheet` (protocolo `RecordsQuickFilterModel`; `RecordsViewModel` lo cumple sin cambios), y `RecordsListSearchField` deja de ser `private`. `RecordRowView` y `RecordDateSectionView`, sin tocar.
4. **«Más filtros» abre la misma hoja de Registros (`RecordsFiltersView`) con el modelo propio.** Esa hoja escribe el monto directo en la sesión; al cerrarla, el monto pasa al modelo de la hoja y la sesión vuelve al que tenía.
5. **El buscador va siempre a la vista** (en Registros asoma al tirar) y busca con la regla de Registros: descripción, categoría, cuenta, etiqueta o importe.
6. **Sin período ni Lista/Calendario en la hoja:** sigue la ventana de los últimos 6 meses de siempre, con su pie. Cuando hay algún filtro, «Limpiar filtros» va en la línea de los chips.
7. **Botón: «Reusar» con el icono `doc.on.doc`.** `ViewThatFits` con dos formas, las dos en una fila: píldora con nombre, o solo el icono (redondo, 44 pt, nombre y pista para VoiceOver). Nunca uno debajo del otro. El identificador `scheduled_payments_create_from_record_button` se conserva.
8. **Las filas son las de Registros**, así que su identificador pasa a `record_row`: se actualiza el XCUITest que lo buscaba (`YalaUITests/Flows/RecurrenteDesdeRegistroUITests.swift`, fuera de `toca:`, cambio mínimo).
9. **Textos nuevos en `ReusarRegistro.strings`** (16 idiomas): botón, pista, «Limpiar filtros» (el mismo texto que `filters.clearFilters`) y el vacío con filtros. Los textos que ya existían del selector (título, vacío, sin resultados, pie) se reusan.
