---
id: panel-balance-chart-contradicts-its-own-figure
status: backlog
priority: medium
area: panel
created: 2026-10-12
updated: 2026-10-12
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
