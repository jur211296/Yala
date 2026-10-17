---
id: panel-balance-chart-contradicts-its-own-figure
status: done
priority: medium
area: panel
created: 2026-10-12
updated: 2026-10-16
---

# Panel: la gráfica de Saldo dice «+179,062» y dibuja una curva entre 200K y 220K

## Qué ve el usuario

En el Panel, con «Este mes», el widget Saldo pone **+179,062** y «Aumento +2%», pero la curva cae de ~218K a ~201K con el eje entre 180K y 220K. La cifra y el dibujo no cuentan lo mismo. Con «Todo el tiempo» la curva llega a ~200K y la cifra sigue en 179,062.

## Cómo reproducirlo (medido el 2026-10-12, Yala Dev, iPhone 17 Pro Max iOS 27)

1. Lanzar con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed ficha-mx-vida -AppleLanguages "(es-MX)" -AppleLocale es_MX -defaultCurrencyCode MXN -userTheme 1`.
2. Panel → periodo «Este mes» → widget Saldo.

## Sin verificar

Si es un bug de la cifra, de la curva o de la semilla (la cuenta en USD convierte con tipos distintos: el histórico de la fila vs. el tipo vivo 18.30). Puede que la curva use otro tipo de cambio que la cifra «al tipo de cambio actual». Medir con la semilla `realista` antes de culpar a `ficha-mx-vida`.

Lo vio la crítica de las capturas de la ficha 2.1 (encargo `2026-10-12-capturas-grupos-6-9`).

## Resuelto (2026-10-16)

**Medido:** ni la cifra ni la semilla. La brecha era solo de divisa, y sale igual con `realista`: la cifra vale los
dólares al tipo de hoy (saldo vivo) y la curva sumaba cada movimiento al tipo de SU día. Con `ficha-mx-vida`, 15.279
USD daban 279.606 MXN a 18,30 y 282.662 sumados fila a fila. Ninguna fila con fecha futura.

**Decisión de Jürgen (2026-10-16):** «cada día a su tipo de cambio». Cada punto vale el saldo nativo de ese día por la
tasa de ESA fecha, y el de hoy con la regla del saldo vivo, así que la curva acaba en la cifra. Un periodo cerrado
vale su saldo al cierre con la tasa del cierre.

**Qué cambió:** `BalanceValuation` (nuevo) valora; `CurrencyConverting.rateFactors` lee en bloque las tasas de todos
los días (misma escalera que la conversión día a día). Lo usan la curva del Panel y su comparativa, Estadísticas
(agregada, por cuenta y el hero de un periodo cerrado) y el widget de inicio (saldo del periodo y curva). Regla
durable en `.claude/rules/currency-fx.md`.

**Evidencia:** `PanelBalanceFigureCurveParityTests` (las dos semillas, cinco periodos que incluyen hoy, cada punto
pasado contra una conversión fecha a fecha, el periodo cerrado, la vista por cuenta y el tiempo: 37 ms la curva de
«Todo» con dos años), `CurrencyConverterDailyFactorsTests` (bloque = fecha a fecha, con filas parciales, huecos,
ceros, duplicados y cinco zonas horarias). Capturas: `_capturas/2026-10-16-saldo-flujo-caja/` — en «Este mes» antes
«+169,473 · +1.7%» con la curva de ~215K a ~190K; después la misma cifra, «−10.8%» y la curva acaba en el punto «Hoy».

**Encontrado, con ticket:** `balance-figure-counts-future-dated-rows-the-curve-never-draws`,
`ficha-mx-vida-rates-jump-on-the-last-day`, y una nota en `hoja-del-saldo-vivo-ignora-los-filtros-de-sesion` (con
filtros, en Estadísticas la cifra y la curva cuentan distinto, ya antes de esto).
