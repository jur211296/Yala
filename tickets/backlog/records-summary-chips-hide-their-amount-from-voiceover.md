---
id: records-summary-chips-hide-their-amount-from-voiceover
status: backlog
priority: low
area: accessibility
created: 2026-09-09
updated: 2026-10-08
source: hallazgo de camino en fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# Un `accessibilityLabel` en el contenedor tapa el importe que el componente sí anuncia

## Qué le pasa al usuario

Un usuario de VoiceOver que llega a un chip de resumen oye «Ingresos» y nada más: el importe no se
lee. `AmountText` se etiqueta a sí mismo con el número ya formateado, pero cuando vive dentro de un
`Button` con `accessibilityLabel` propio, ese label **sustituye** al del elemento combinado.

## Dónde, medido el 2026-09-09

Los dos chips de `RecordsTabView` se arreglaron sobre la marcha al cablear la marca de aproximado
—llevan ahora un `accessibilityValue` con el importe— porque sin eso el «≈» tampoco se oía. Queda
**barrer el mismo patrón en el resto de la app**: es la misma forma que la regla ya documentada en
`.claude/rules/testing.md` sobre identificadores de accesibilidad que un contenedor pisa, aplicada
esta vez a la etiqueta.

Búsqueda de partida: un `.accessibilityLabel(` sobre un `Button`/`HStack` que contenga un
`AmountText`. Los chips del hero del Panel (`HeroMonthView`) y los de Tendencias son los primeros
candidatos, y hay más.

## Criterio de hecho (AC)

- [ ] Barrido completo del patrón, con la lista de instancias.
- [ ] Cada control que envuelve un importe lo anuncia (label descriptivo + `accessibilityValue` con
      el número, marca incluida).
- [ ] Un source-scan al molde de `ApproximateMarkWiringTests` que impida que vuelva a perderse.

## Medido en 2.1 (triage 2026-10-08)

- 29 ficheros de `Yala/` usan `AmountText` y `.accessibilityLabel(` a la vez; nadie ha hecho la lista de instancias ni el source-scan del tercer criterio.
- Candidato revisado: los chips de ingresos y gastos del hero (`HeroMonthView`) no llevan `accessibilityLabel` propio, así que el importe sí se oye; les falta lo contrario, decir si es ingreso o gasto (la flecha va con `accessibilityHidden`). Es un caso hermano para el mismo barrido.

Triage 2026-10-08: abierto · low → low · accesibilidad sin barrer; los dos chips de Registros ya se arreglaron y el resto sigue sin medir.
