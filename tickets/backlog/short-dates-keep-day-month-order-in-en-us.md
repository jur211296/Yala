---
id: short-dates-keep-day-month-order-in-en-us
status: backlog
priority: low
area: l10n
created: 2026-10-16
updated: 2026-10-16
source: revisión de Lola de las capturas App Store 2.1 en inglés (16-oct, opcional «en-US con fechas de EE. UU.»)
---

# Las fechas cortas salen «13 Oct» también en inglés de EE. UU.

## Qué se ve

Con el iPhone en en-US, Últimos registros, la ficha de un registro y los selectores de período escriben «13 Oct». En
Estados Unidos se escribe «Oct 13». Lo vio Lola en las capturas de la ficha en inglés.

## Causa [medido con grep el 16-oct]

33 sitios fijan el formato a mano (`dateFormat = "d MMM"` y parecidos) en vez de pedir una plantilla
(`setLocalizedDateFormatFromTemplate("dMMM")`), que da el orden de cada idioma. Lista: `grep -rn 'dateFormat = "d MMM\|"d MMM"' Yala YalaWidgets`.
El mismo fallo, en la fecha larga del detalle de un pago planificado («Thursday, 15 October 2026», y en pt-BR sin
«de»), se arregló el 16-oct en `ScheduledPaymentDetailView` con la plantilla `EEEEdMMMMyyyy`.

## Qué hay que hacer

Pasar los 33 a plantilla, mirando en cada uno si el ancho cabe (en inglés «Sept 13» es más largo que «13 Sep») y si
algún test fija el texto. Y los `"MMMM yyyy"` (8 sitios): en pt-BR y en español falta el «de» («outubro de 2026»).
