---
id: short-dates-keep-day-month-order-in-en-us
status: done
priority: low
area: l10n
created: 2026-10-16
updated: 2026-10-25
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

## Resuelto (lote 12.4, 2026-10-25)

~40 formatos fijos (`d MMM`, `d MMM yyyy`, `d MMM yy`, `MMM yy`, `MMM yyyy`, `MMMM yyyy`, `EEE d MMM`) pasan a `setLocalizedDateFormatFromTemplate`, con el `locale` puesto ANTES de la plantilla (se movió en 9 sitios donde iba después). En en-US: «Oct 13», «Oct 13, 2026», «Tue, Oct 13»; en pt-BR y español, «outubro de 2026» / «octubre de 2026»; en alemán, «13. Okt.». En español de Perú no cambia nada.
- Ejes de las gráficas (app y widget): plantilla en el `cachedFormatter`. La hora del tipo de cambio conserva «, HH:mm» (la plantilla con hora mete «at» en inglés).
- Fuera, a propósito: los compactos de `PreviousPeriodHelper` («vs 29dic-4ene», y el «vs oct 2026» que se capitaliza palabra a palabra: con la plantilla pt saldría «Out De 2026») y la etiqueta del prompt de Yala IA (`FullFinancialContextBuilder`).
- Lo fija `ShortDatesFollowTheLocaleOrderTests` (scan de Yala/ y YalaWidgets/ sin formatos fijos, locale antes de la plantilla, y lo que da cada plantilla en en_US, en_GB, es_419, pt_BR).
