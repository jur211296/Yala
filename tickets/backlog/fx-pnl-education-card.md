---
id: fx-pnl-education-card
status: backlog
priority: medium
area: panel/finance
created: 2026-05-03
updated: 2026-08-26
source: YalaWiki/Ideas/idea-fx-pnl-card.md
---


# Card educativa de Ganancia/Pérdida Cambiaria (FX P&L)

## Problema

> Tras el fix Live Balance ([[rvw_live-balance-multi-currency-fix]]), el usuario multi-divisa puede ver que su balance no coincide exactamente con la suma del cashflow histórico. La diferencia es ganancia/pérdida cambiaria latente (FX P&L) — información valiosa pero invisible. Las sheets informativas explican el porqué, pero no muestran la magnitud.

## Solución

Añadir card en el Panel (sección Tendencias o Para ti) que muestre:
- **FX P&L acumulado**: diferencia entre balance live y cashflow histórico acumulado, en moneda preferida.
- **Por moneda**: desglose breakdown por moneda nativa, mostrando saldo nativo, TC actual, valor en preferida, y P&L parcial.
- Mensaje cálido tipo: "Tus dólares se han **revalorizado/depreciado** un X% desde que entraron a tu cuenta."
- Visualización: chip tinta verde (ganancia) / gris (pérdida). NO usar rojo.

Indicador adicional: cuando `isExchangeRateProvisional` aplica al saldo (TC fallback porque API está caída o cuenta tiene transacciones recientes sin TC del día), mostrar etiqueta "TC estimado" en la card de balance.

## Acceptance Criteria

- [ ] Solo aparece cuando hay >1 moneda con saldo no-cero.
- [ ] Solo aparece si `|FX P&L| > umbral` (ej. >0.5% del balance) — evita ruido.
- [ ] Visualización breakdown por moneda en sheet detalle.
- [ ] Etiqueta "TC estimado" cuando aplica.
- [ ] Free vs Pro: revisar comercial. Probable Free (es informativa, no IA).

## Diseño

Pendiente. Inspiración: Wise, Revolut muestran FX P&L en transferencias. Yala lo mostraría a nivel cuenta/balance.

## Notas Técnicas

- `LiveBalanceCalculator.liveBalanceBreakdown(...)` ya retorna `nativeBalances` por moneda.
- Cashflow histórico acumulado: nueva agregación basada en `amountInPreferredCurrency`.
- FX P&L = balance live − Σ(cashflow histórico).
- Por-moneda: `(saldo_nativo × TC_actual) − Σ(cashflow_de_esa_moneda)`.

## Referencias

- Spec base que habilita: [[rvw_live-balance-multi-currency-fix]]
- Anexo B del plan (filosofía coexistencia honesta): `~/.claude/plans/crea-el-spec-y-reactive-cloud.md`

migrated from YalaWiki Ideas/idea-fx-pnl-card.md @ 1934e8ad
