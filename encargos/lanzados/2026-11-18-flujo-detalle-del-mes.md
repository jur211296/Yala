Yala
# Flujo de caja: el detalle del mes cuenta una sola historia, empezaste, entró, salió y terminas
---
toca: Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift,Yala/App/Views/Reports/CashFlow/CashFlowMonthCapsule.swift,Yala/App/Views/Reports/CashFlow/CashFlowMonthStrip.swift,Yala/App/Views/Reports/CashFlow/CashFlowRealEstimateBar.swift,Yala/App/Views/Reports/CashFlow/CashFlowTableView.swift,Yala/App/Views/Reports/CashFlow/DetalleMes/,Yala/Resources/de.lproj/FlujoDetalleMes.strings,Yala/Resources/en-GB.lproj/FlujoDetalleMes.strings,Yala/Resources/en.lproj/FlujoDetalleMes.strings,Yala/Resources/es-419.lproj/FlujoDetalleMes.strings,Yala/Resources/es-AR.lproj/FlujoDetalleMes.strings,Yala/Resources/es-ES.lproj/FlujoDetalleMes.strings,Yala/Resources/es.lproj/FlujoDetalleMes.strings,Yala/Resources/fr.lproj/FlujoDetalleMes.strings,Yala/Resources/it.lproj/FlujoDetalleMes.strings,Yala/Resources/ja.lproj/FlujoDetalleMes.strings,Yala/Resources/nl.lproj/FlujoDetalleMes.strings,Yala/Resources/pl.lproj/FlujoDetalleMes.strings,Yala/Resources/pt-BR.lproj/FlujoDetalleMes.strings,Yala/Resources/pt-PT.lproj/FlujoDetalleMes.strings,Yala/Resources/pt.lproj/FlujoDetalleMes.strings,Yala/Resources/zh-Hans.lproj/FlujoDetalleMes.strings,YalaTests/FlujoDetalleMes/,YalaUITests/FlujoDetalleMes/,tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/flujo-motor-del-mes
---

Decisiones de Jürgen del 18-nov (06:26 Lima), registradas: aceptó todo lo recomendado del análisis «Flujo de caja: replanteo» (ticket `tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md`, evidencia en `docs/analisis/2026-11-17-flujo-de-caja-replanteo/`):
- P1 modelo A: mes real + lo que falta.
- P2 línea excedida: cuenta lo real y no proyecta más.
- P3 al cambiar un límite, por defecto «desde este mes en adelante».
- P4 el límite es un monto fijo, sembrado con tu promedio al crear.
- P5 se retira el saldo inicial manual: se parte del saldo de tus cuentas.
- P6 lo que no tiene línea en meses futuros: gastos por la mediana de 6 meses; los ingresos no se proyectan.
- AJUSTE OBLIGATORIO: el nivel de detalle siempre llega a SUBCATEGORÍA, que es el id base. La categoría se deriva de sus subcategorías (suma) y se muestra como agrupador, puede ser colapsable. Nunca una línea solo a nivel categoría que pierda el detalle de subcategoría.

Sesión S2 del plan del ticket. Usa el motor de la sesión anterior (flujo-motor-del-mes).

## Qué hacer
- Una historia por mes: «Empezaste con · Entró · Salió · Terminas con», distinguiendo real y estimado.
- Fuera «Empezaste con S/ 0» y las tres cifras distintas para «cómo acabo el mes».
- En la tabla, cada categoría agrupa sus subcategorías y se puede colapsar; la subcategoría es la fila base.
- Arregla de paso que las cápsulas «Comparativa / Flujo de caja» floten sobre las filas y se lea el texto de detrás.
- 2 o 3 variantes en maquetas, implementa la recomendada. Actualiza el ticket marcando S2.

## Cómo entregar
- Base 2.3, un PR. Toca solo lo declarado; si algo imprescindible queda fuera, ponlo en una carpeta nueva dentro de lo declarado y anótalo.
- Tests de lo nuevo. Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad) cuando haya UI.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después y lo decidido.
- Commits y PR sin firma de IA. Textos nuevos solo en la tabla de strings declarada de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi; ninguna es vital ni irreversible): las recomendaciones se dan por buenas. Se
> discuten en el PR.

**Hechos de partida (medidos).** El motor de la sesión anterior (PR del motor del mes, en cola de auto-merge) ya da por
mes `openingBalance`, `realIncome`/`realExpense`, `incomeLeft`/`expenseLeft`, `accumulatedBalance` y los grupos por
categoría. Esta rama nace sobre la del motor (`depende:`) y se rebasa sobre `2.3` cuando aterrice. El cierre de un mes
pasado y el «hoy» del mes en curso salen del saldo REAL de las cuentas, así que `empezaste + entró − salió` no tiene por
qué dar `terminas` (ajustes de saldo, movimientos sin cuenta, divisas).

**D1 · Forma de la historia** → variante A, «libro del mes»: cuatro filas apiladas (Empezaste con · Entró · Salió ·
Terminas con) con la cifra grande en «Terminas con». Se maquetan también B (cascada horizontal) y C (dos columnas Real /
Falta) en el artifact. Por qué: se lee de arriba abajo como una suma, cabe en un SE a AX5 sin gráficos y reutiliza el
hero claro. Descartadas: B pide un gráfico que con texto grande no cabe; C duplica columnas en cada fila.

**D2 · Real y estimado** → en el mes en curso, Entró y Salió dicen lo real y debajo «+ S/ X por entrar/salir
(estimado)»; «Terminas con» lleva «≈». Un mes pasado es todo real (en pasado: «Empezaste / Entró / Salió / Terminaste»);
uno que viene, todo estimado y en condicional («Empezarías / Entraría / Saldría / Terminarías»). Por qué: el tiempo verbal
y el «≈» dicen qué es real sin leyenda aparte.

**D3 · Cuando la suma no cuadra** → fila «Ajustes de saldo» con la diferencia, solo si no se pinta como cero. Por qué: la
historia tiene que sumar; esconder la diferencia haría que la pantalla se contradiga. Alternativa descartada: forzar
«Terminas» = empezaste + neto (rompería la paridad «Al 30» con el Panel).

**D4 · Sin cuentas que sumen** (`openingBalance == nil`) → solo Entró y Salió, y la cifra grande es lo que queda (el neto,
como antes). Por qué: sin saldo no hay «empezaste» honesto.

**D5 · Lo que sale** → fuera «Empezaste con S/ X · Cambiar», «Este mes te quedaría», «Si sigue así, a fin de … tendrías»
y el desglose «Tienes hoy / Falta entrar / Falta salir». Se quedan «Llevas el N %» y la línea de origen del saldo de hoy.
La hoja del saldo inicial deja de presentarse desde la tabla (nadie la abre ya); el flag del ViewModel queda (no es de lo
declarado). La cápsula pasa a decir con cuánto terminas el mes (la misma cifra grande), con «≈» si es estimado; sin
cuentas, el neto.

**D6 · Tabla por categoría** → cada categoría es un grupo plegable (cabecera con icono, nombre, total y chevron); las
filas son las líneas por subcategoría (fila base). Una línea por categoría que exista de antes se pinta dentro de su
grupo con su desglose por subcategoría debajo, de solo lectura, para no perder ese detalle. Lo anotado en la categoría
madre sin subcategoría sale como fila «Sin subcategoría» dentro del grupo, para que el grupo sume sus filas. Las líneas
sin categoría (libres o de pago sin categoría) van después de los grupos. Abierto por defecto; plegar vive en la pantalla
(no se guarda). Por qué: el ajuste obligatorio de Jürgen (la subcategoría es el id base; la categoría, su suma).

**D7 · Cápsulas «Comparativa / Flujo de caja» flotando** → la barra pasa de `safeAreaInset` a `safeAreaBar` en
`FinancialReportView`, que difumina el borde del scroll bajo ella (regla de `swiftui-ds.md`). Es una línea fuera de lo
declarado y no cabe en una carpeta nueva: se anota en el PR.

**D8 · Textos** → todos los nuevos en `FlujoDetalleMes.strings` de los 16 `.lproj`, leídos con `L10n.FlujoDetalleMes`
(molde de `HojaCuentaTarjeta`), con su test de paridad de claves.

**D9 · Pruebas** → unit de la lógica pura (filas de la historia por tiempo, ajuste, sin cuentas; grupos y sumas) y un
XCUITest que abre el plan, ve las cuatro filas y pliega un grupo. Capturas con un conductor propio
(`FlujoDetalleMesCapturasUITests`, se salta sin carpeta): iPhone 17 Pro claro y oscuro, AX, SE e iPad si el simulador
existe en la máquina.
