---
id: live-anchor-breakdown-doubles-the-approximate-glyph
status: backlog
priority: low
area: "currency, ui, l10n"
created: 2026-09-09
updated: 2026-10-08
source: device-QA de fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# En el desglose por divisa, la marca de tasa dudosa sale como «≈ ≈» y no se distingue de la otra

## Qué le pasa al usuario

En la hoja «¿Cuánto tienes hoy?» → **Ver por moneda**, cada divisa muestra su equivalente en la
divisa preferida. Ese texto **ya llevaba un «≈» propio**, que significa «al cambio de hoy,
aproximadamente». Desde `fx-approximate-mark-missing-on-secondary-surfaces` el importe puede traer
**otro** «≈» delante cuando su tasa no era la del día, y los dos se suman.

Medido en simulador el 2026-09-09 (iPhone 17 Pro, iOS 26.5, `Yala Dev`, launch
`-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY`):

| divisa | tasa del día | lo que se ve |
|---|---|---|
| USD | sí (la fila la trae) | `≈ S/ 111,711.40 hoy` |
| JPY | **no** (fuera de la fila) | `≈ ≈ S/ 750.00 hoy` |

Captura: `qa/evidencia-fx-20260909/03-doble-glifo-detalle.png`.

**Las dos consecuencias, y la segunda es la que importa:**

1. El doble glifo se lee como un error tipográfico.
2. **La señal no comunica nada.** La divisa con tasa buena y la divisa con tasa dudosa se
   distinguen sólo por *cuántas veces* aparece el mismo símbolo. Nadie lee eso. O sea que el
   cableado que el ticket padre añadió aquí —que es correcto y está bien medido— no llega al
   usuario.

## Dónde, medido

- El glifo fijo vive en el **copy**: `panel.liveAnchorEducation.breakdownRowConvertedFormat`
  (`Yala/Resources/es.lproj/Localizable.strings:749`, `"≈ %@ hoy"`).
- El glifo variable lo antepone el formateador:
  `BalanceLiveAnchorEducationSheet.swift:171-177` pasa
  `appPreferences.currency(..., isEstimate: row.convertedIsApproximate)`.

**Está en los 16 `.lproj`**: 14 con «≈» literal, `ja` con `本日 ≈ %@` (también «≈») y `zh-Hans` con
`今天约 %@`, donde 约 ya significa «aproximadamente» — ahí el resultado es la mezcla de dos marcas
distintas, `今天约 ≈ …`.

## Por qué NO se arregló en el device-QA

Elegir qué se queda es **copy y diseño**, no cableado: hay que decidir si el «≈» decorativo del
formato desaparece (y entonces el glifo pasa a significar sólo «tasa dudosa», que es lo que
significa en el resto de la app) o si la marca de tasa se distingue de otra forma en esta fila.
Cambiar 16 ficheros de copy no entra en un `/qa`, y `BRAND-VOICE.md` manda sobre el texto.

## La próxima colisión ya está programada

Sólo hay **3 claves** con «≈» en todo el `Localizable.strings` (medido en las 16 locales). La
segunda es `stats.insights.need.dailyFormat` (`es.lproj:4214`, `"≈ %@/día"`), usada en
`InsightsTabView.swift:801` con `appPreferences.currency(...)` **sin** `isEstimate:`. Hoy imprime un
solo glifo — pero los buckets de necesidad están explícitamente en la tabla de
[[fx-category-totals-unmarked]], así que quien implemente ese ticket creará ahí el mismo doble
glifo. La tercera, `groups.stats.convertedToNote`, no aplica: su `%@` es un código de divisa, no un
importe.

Hay además un cuarto «≈» **hardcodeado en Swift**, no en el copy:
`TransactionDetailSheet.swift:458` antepone `"≈ "` al importe convertido de una transacción. Hoy no
colisiona porque ese importe no pasa por `isEstimate:`; es la misma clase de fragilidad.

## Criterio de hecho (AC)

- [ ] En el desglose por divisa, una divisa con tasa del día y otra sin ella se distinguen por algo
      que un usuario pueda leer, y nunca aparecen dos glifos de aproximación seguidos.
- [ ] La decisión queda escrita donde se lee (el docblock de la fila), porque el glifo fijo del copy
      es anterior y su motivo no es el mismo.
- [ ] Un test que falle si el formato vuelve a traer el glifo Y el importe puede traerlo — la
      comprobación tiene que mirar las **16** locales, no sólo `es`.
- [ ] `stats.insights.need.dailyFormat` queda anotado en [[fx-category-totals-unmarked]] para que su
      implementación no repita el patrón.

## Relacionados

- [[fx-approximate-mark-missing-on-secondary-surfaces]] — el ticket que cableó la señal aquí.
- [[approximate-mark-ors-over-whole-period]] — de dónde sale el criterio de cuándo marcar.
- [[dos-criterios-de-aproximado-en-la-misma-pantalla]] — el «≈» ya significa dos cosas en el Panel;
  esto es una tercera lectura del mismo símbolo, en la misma hoja.

## Pregunta para Jürgen (triage 2026-10-08)

Sigue igual: `"≈ %@ hoy"` (`es.lproj:743`) + `isEstimate: row.convertedIsApproximate` (`BalanceLiveAnchorEducationSheet.swift:175-177`). ¿Qué queda?

- **A** · Quitar el «≈» del copy en los 16 `.lproj` (y el «约» de `zh-Hans`): el glifo pasa a significar solo «tasa dudosa», como en el resto de la app.
- **B** · Dejar el copy y marcar la tasa dudosa con otra señal en esta fila (texto «tasa de otro día» o un icono).
- **C** · Dejarlo como está.

Recomendación: **A**, que es lo que el «≈» ya significa en el resto de la app. Con A la prioridad es `low`.

Triage 2026-10-08: abierto · medium → low · el doble glifo sigue: formato `"≈ %@ hoy"` (`es.lproj:743`) más `isEstimate:` en `BalanceLiveAnchorEducationSheet.swift:175`; falta decidir el copy.
