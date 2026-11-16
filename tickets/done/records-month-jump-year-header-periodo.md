---
id: records-month-jump-year-header-periodo
status: done
priority: medium
area: "records, filters, l10n"
updated: 2026-11-12
created: 2026-11-12
source: "decisiones 17, 79, 73 y 74 de la discusión del artefacto 2.3 (docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md), card tablero-2-3-registros-saltar-de-mes-el-ano-en-la-ryqg"
---
# Registros: saltar de mes, el año en la cabecera y «Período»

**Qué pasaba.** En «Todo el tiempo», con dos años de registros, la cabecera de día decía «4 de julio» sin año (el mismo
día de dos años se leía igual) y no había forma de saltar a un mes: hasta un gasto de hace tres semanas eran nueve
deslizamientos. Convivían «periodo» y «Período»; «Nota contiene...» llevaba tres puntos, y el monto del filtro enseñaba
un «0.00» fijo aunque la persona usara otros decimales o la coma.

**Decidido (9-nov).** 17: T1 + T2 (separador de mes fijo y tocable, cabecera de día con año y total, año solo fuera del
año actual). 79: la cabecera fija lleva fondo. 73: una sola grafía, «Período». 74: puntos suspensivos tipográficos y el
marcador del monto con el formato de la persona.

**Hecho.**
- La lista de Registros (y Estadísticas › Registros, que es la misma) va por meses. Si cruza meses, el separador del mes
  queda fijo arriba con banda opaca: «Octubre de 2026 · 182 registros · S/ -6,420.00». Tocarlo abre un menú con los meses
  («Ir a otro mes») y elegir uno lleva la lista a su primer día. Con un solo mes a la vista no sale.
- La cabecera de día dice «jue 12 nov» y lo gastado ese día a la derecha (el mismo cálculo que el calendario); con año
  («vie 4 jul 2025») solo fuera del año en curso. Buscar y Grupos no cambian.
- Las cabeceras de día ya iban con el scroll desde 2.2 (no se montan sobre las filas); lo único fijo es el separador, y
  lleva fondo.
- «período/períodos» con tilde en los cuatro españoles (app, plurales y widgets). Los textos que van a Yala IA no se tocan.
- «Nota contiene…» en los 16 idiomas. El marcador del monto es un cero con los decimales de la persona y el separador de
  su región, y lo escrito se lee con ese separador («12,50» filtraba por 12 en una región con coma).

**Fuera.** Los otros campos de monto con «0.00» fijo (Nuevo registro, Grupos, Bandeja, transferencias) y los demás
textos con tres puntos: no eran de estas decisiones.

**Pruebas.** `YalaTests/RecordsMonthJump23Tests` (meses, año, cifra del día, cableado de la cabecera fija, «período» en
los catálogos, «…» en 16 idiomas, marcador y lectura del monto) y
`YalaUITests/RecordsMonthJump23UITests` (salto a un mes del año pasado con la semilla `realista`).
