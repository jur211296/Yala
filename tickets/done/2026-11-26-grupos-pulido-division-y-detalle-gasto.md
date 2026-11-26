---
id: 2026-11-26-grupos-pulido-division-y-detalle-gasto
status: done
priority: medium
area: "groups-expense-form, groups-bridge-settings-optout"
created: 2026-11-26
updated: 2026-11-26
card: tablero-grupos-pulido-de-como-se-dividio-det
source: "pedido de Jürgen del 26-nov-2026 con 5 capturas"
---

# Grupos: «¿Cómo se dividió?» más amigable, detalle de gasto en tarjetas y la etiqueta «Partes iguales» equivocada

Jürgen (26-nov, 13:31): la hoja «¿Cómo se dividió?» de un grupo de dos abría en grande con media pantalla vacía; el
detalle de un gasto de grupo obligaba a subir la hoja para ver el reparto y, en grande, quedaba plano, sin tarjetas; y un
gasto «Pagaste · es todo de Pia» decía «Partes iguales» junto a «Reparto».

## Hecho cuando

- «¿Cómo se dividió?» abre a media altura, con las cuatro opciones claras de un vistazo y «Más opciones» como antes; con
  texto grande, en una columna y estirable a grande.
- El detalle de gasto de grupo enseña a media altura el importe, quién pagó y el reparto con lo de cada uno, sin subir.
- En grande, las mismas tarjetas, despegadas del fondo, en claro y oscuro.
- La etiqueta del reparto dice lo que dicen los montos («Todo tuyo», «Todo de Pia», «Partes iguales», «Monto exacto»,
  «Porcentaje», «Proporciones», «Personalizado»), con pruebas unitarias de todos los casos.

## Resolución (2026-11-26)

- `GroupSplitLabelLogic` (`Yala/App/Logic/GruposPulidoDivisionDetalle/`) decide el tipo por los montos reales: una sola
  persona con parte → «todo de»; varias con la misma parte (tolerancia de 1,5 céntimos) → «Partes iguales»; partes
  distintas → el tipo guardado, o «Personalizado» si el tipo es `equal`, vacío o desconocido. La barra de proporciones
  sigue el mismo criterio. 21 pruebas unitarias + paridad de las 5 claves en los 16 idiomas
  (`YalaTests/GruposPulidoDivisionDetalle/`).
- `GroupTwoPersonSplitView`: rejilla 2×2 de tarjetas (fila = quién pagó, columna = cómo se reparte), alturas
  `[.medium, .large]` con selección y fondo de cristal a media altura / del tema en grande. VoiceOver lee la frase de
  siempre («Pagó Caro · partes iguales. Le debes S/ 60.00 a Caro»).
- `GroupExpenseDetailSheet`: cabecera compacta como el registro personal, una tarjeta con «Tu parte» y el reparto, otra con
  los detalles; en grande, fondo del tema para que las tarjetas no queden planas (en el tema Oscuro la tarjeta y el fondo
  de la hoja eran del mismo color).
- XCUITest `GruposPulidoDivisionDetalleUITests` (5 casos, con las capturas del antes y el después).

## Fuera de alcance (anotado)

- La pantalla de éxito al guardar un gasto de grupo (`GroupExpenseSuccessView`, fila «Reparto») sigue diciendo «Partes
  iguales» para un «es todo de X»: lee `SplitType.displayName`. Mismo arreglo con `GroupSplitLabelLogic`.
- La etiqueta de accesibilidad de la fila «y dividido…» del formulario (`GroupExpenseFormView`) dice igual el tipo guardado.
