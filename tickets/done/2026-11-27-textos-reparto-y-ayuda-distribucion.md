---
id: 2026-11-27-textos-reparto-y-ayuda-distribucion
status: done
priority: medium
area: "groups-expense-form, l10n"
created: 2026-11-27
updated: 2026-11-27
card: tablero-textos-de-reparto-y-ayuda-de-distrib
source: "hallazgos de los cierres del 26-nov (Grupos: pulido de división) y pendientes de 2.3; lote aprobado por Jürgen el 27-nov"
---

# Textos: «Partes iguales» en el éxito de un gasto de grupo, VoiceOver de «y dividido…» y la ayuda «Toca una burbuja»

El arreglo del 26-nov (`GroupSplitLabelLogic`) dejó bien la etiqueta del reparto en el detalle de un gasto de grupo, pero
dos sitios seguían leyendo el tipo guardado: la pantalla de éxito al guardar y lo que VoiceOver lee en «y dividido…» del
formulario. Un gasto «es todo de Ana» se guarda con el tipo `equal` y los dos decían «Partes iguales». Además, la ayuda
«?» de las tres tortas (categorías, subcategorías, etiquetas) decía «Toca una burbuja para filtrar el resto del Panel»,
y en Distribución tocar una categoría abre su detalle.

## Hecho cuando

- El éxito dice «Todo de Ana» / «Todo tuyo» cuando una sola persona carga con el gasto; los repartos de verdad siguen
  diciendo su tipo.
- VoiceOver lee «Dividido: Todo de Ana» en la pieza del formulario; sin monto, el tipo guardado como antes.
- Las seis claves de ayuda dicen lo que hace cada toque hoy, en el Panel y en Distribución, en los 16 idiomas.

## Resolución (2026-11-27)

- `RepartoRealEnExitoYFormulario.swift` (`Yala/App/Logic/GruposPulidoDivisionDetalle/`): `splitKind`, `splitLabel` y
  `splitIconName` de `GroupExpenseSuccessData`, y `GruposPulidoDivisionDetalleText.splitLabel(splitType:shares:…)`, los
  dos sobre `GroupSplitLabelLogic`. El icono de persona solo para «todo de»; el resto conserva el de su tipo.
- `GroupExpenseSuccessView`: la fila «División» pinta y lee la etiqueta real. `GroupExpenseFormView`: la lectura de
  VoiceOver de la pieza «dividido» usa las partes calculadas (`spokenSplitLabel`). El texto visible no cambia.
- `Localizable.strings` ×16: `panel.widgetInfo.{categoriesPie,subcategoriesPie,tagsPie}.{small,large}HowA`. Categorías
  explica las dos pantallas («En el Panel… ver solo esa categoría; en Distribución, abre el detalle»); subcategorías y
  etiquetas, «ver solo… tócala otra vez para volver a verlo todo». es-AR con voseo, pt-PT con «tu».
- Pruebas: `YalaTests/TextosRepartoYAyuda/` (éxito, VoiceOver, cableado de las dos vistas, ayuda en los 16 idiomas).
- Medido en el simulador antes y después (Viaje a Cusco, «Souvenirs» todo para Ana): éxito «Partes iguales» → «Todo de
  Ana»; VoiceOver «Dividido: Partes iguales» → «Dividido: Todo de Ana».

## Fuera

- El texto VISIBLE de la pastilla «y dividido [en partes iguales]» y la frase del grupo de 2 siguen con el tipo guardado.
- En Distribución, el «?» de la torta no responde al toque ni aparece para VoiceOver (queda dentro del botón de la
  tarjeta): hallazgo del cierre, sin tocar.
