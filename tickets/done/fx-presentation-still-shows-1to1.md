---
id: fx-presentation-still-shows-1to1
status: done
priority: medium
area: currency
created: 2026-09-03
updated: 2026-09-16
source: residual explícito de fx-partial-rate-rows-silent-1to1 (decisión del owner, 2026-09-03)
qa-status: passed
qa-date: 2026-09-16
---

# Lo que se guarda ya es correcto; lo que se ve en pantalla todavía puede ser un 1:1 silencioso

## Qué le pasa al usuario

Cuando a la fila de tasas de un día le falta una divisa, el monto que la app **guarda** ya se convierte
bien desde `fx-partial-rate-rows-silent-1to1`. Pero las ~34 llamadas que solo PINTAN números siguen
usando `CurrencyConverter.convert`, que ante una divisa ausente devuelve el monto crudo sin decirlo.

Panel, Tendencias, Estadísticas y los saldos de Grupos pueden mostrar un número plausible y falso.

## Por qué está separado, y no es un olvido

**Decisión del owner del 2026-09-03**, con el coste delante: el daño duradero es el disco —lo guardado
viaja por la nube y alimenta informes—, así que ese se arregló primero. Cubrir la presentación exige
tocar el protocolo `CurrencyConverting` (`CurrencyConverter.swift:26-29`), sus tres dobles de test y
los ~28 ficheros que lo inyectan como parámetro por defecto.

**El efecto que hay que tener presente es que la divergencia se INVIRTIÓ.** Antes de aquel fix, la
pantalla se veía bien (leía de la caché en memoria, con el set completo) y el disco se envenenaba.
Ahora el disco está bien y la pantalla es la que puede mentir. No es una regresión —el número en
pantalla no era más correcto antes— pero sí cambia dónde mirar al diagnosticar.

## Punto de partida medido (2026-09-03, HEAD `85ba0077`)

- `CurrencyConverter.convertChecked` ya existe y devuelve `RateQuality`: la información está, solo hay
  que llevarla al protocolo y decidir qué hace la UI con ella.
- `ExchangeRateWidgetHelper` ya resuelve esto de otra forma —omite la divisa en vez de inventar un
  número— y es el precedente de diseño del repo. Su propio defecto está en
  `fx-widget-drops-missing-currency`.
- La decisión de producto que hay que tomar antes de escribir código: **qué ve el usuario** cuando el
  número es aproximado. Hoy `isExchangeRateProvisional` tiene CERO consumidores de UI (medido): se
  escribe, se lee en un `#Predicate` y se emite por nube. Sin superficie visible, la app pasa de
  mentir con seguridad a callarse.

## No confundir con

- `fx-partial-rate-rows-silent-1to1` (en `qa/`) — la persistencia, ya arreglada.
- `distribution-balance-kpi-skips-fx` — qué base de conversión usa cada vista, no si hay tasa.

## Decisión Jürgen (2026-09-06)

**Número con marca de «aproximado».** Elegida entre: (a) mostrar el mejor número disponible con un
indicador discreto (≈ o rotulito) cuando a alguna divisa le falta tasa, (b) omitir la divisa sin tasa
como hace el widget, (c) no decidir hoy. Eligió (a). Motivo, tal como se le puso delante y ratificó:
no oculta información y deja de mentir; la alternativa del widget da un número exacto pero incompleto.

Lo que implica: `CurrencyConverting` expone la calidad de la conversión (`convertChecked` /
`RateQuality` ya existen), los ~28 puntos de inyección la propagan, y las superficies que pintan totales
—Panel, Tendencias, Estadísticas, saldos de Grupos— muestran la marca cuando la calidad no es plena.
`isExchangeRateProvisional` gana por fin un consumidor de UI. Copy del rótulo en 16 `.lproj`. Cómo se
pinta la marca (símbolo vs texto, dónde) es diseño y se resuelve en el `/spec`, no aquí.

## Lo que se midió al implementar (2026-09-06, worktree sobre `6d87123e`)

**La premisa del ticket era falsa por un lado y se quedaba corta por el otro.** Se ejecutaron las dos
rutas contra un store real con la fila del día trayendo USD y PEN pero **no** JPY:

| ruta | resultado | veredicto |
|---|---|---|
| `convertWithLatestRate` | 1000 JPY → **1000 PEN** | el monto CRUDO, ~40× de más |
| `convertWithLatestRate`, sin fila ninguna | 1000 JPY → 24,79 PEN | convierte bien |
| `convert(_:on:)` | 1000 JPY → 24,99 PEN, `quality = .staticFallback` | convierte, pero no lo declaraba |

- **Para la ruta con fecha la premisa ya no valía**: `fx-partial-rate-rows-silent-1to1` destapó los
  tres escalones de `resolveRates`, así que `convert` ya no devolvía el monto crudo. Lo que faltaba
  ahí era exactamente lo que decidió Jürgen: **declararlo**.
- **Para la ruta del TC actual la premisa se quedaba corta**: ahí no era un número aproximado sin
  marcar, era un número mal. Su caché se llena con `needing: []` —no puede saber qué divisas le van a
  pedir— así que una fila parcial de hoy entraba entera y `performConversion` salía por su `guard`.
  Las dos primeras filas de la tabla juntas son el hallazgo: **la fila parcial volvía a ser
  estrictamente peor que no tener fila**, la misma forma exacta del bug ya cerrado, en la otra ruta.
  Y es la ruta que más pinta: saldo vivo del Panel, saldos de Grupos, presupuestos, pagos programados.

**La marca no hubo que diseñarla: ya existe y ya está en producción.** `AmountText.isEstimate`
antepone «≈ » en el run del símbolo (`AmountText.swift:32,191`) y los saldos de Grupos ya la usan
(`GroupBalancesView.swift:123`). Por eso **no hace falta copy nuevo en 16 `.lproj`**: el símbolo es
universal y el AC se cumple reutilizando el precedente en vez de inventar un rótulo paralelo.

**Los saldos de Grupos ya cumplían el AC y no se tocan.** `balancesWereConverted`
(`GroupDetailViewModel.swift:260`) se enciende cuando alguna divisa difiere del destino — exactamente
la condición bajo la que se llama al converter, o sea un superconjunto perfecto de «la tasa fue
inexacta». Marcan de más (también con tasas perfectas), que es una decisión de producto anterior y
más conservadora; revertirla sería quitarle información al usuario y nadie lo pidió.

**Residual conocido, con ticket propio: la marca infra-reporta.** El camino normal de estos totales
no pasa por el converter —suma el `amountInPreferredCurrency` ya guardado—, así que se apoya en el
flag `isExchangeRateProvisional`. Y hay diez escrituras que sellan ese flag en `false` aunque la tasa
fuera aproximada: `fx-manual-writes-seal-approximate-as-final` (high). Hasta que se cierre, la marca
aparece cuando debe pero **puede faltar** en totales cuyas transacciones nacieron mal selladas.

## Criterio de hecho (AC)

- [x] Con una divisa sin tasa ese día, todo total que la incluya lleva la marca de aproximado; con el
      set de tasas completo, ninguna marca. **En unit; falta confirmarlo en aparato.**
- [x] El número mostrado es el mismo que hoy (mejor disponible); lo que cambia es que se declara.
      **Y en la ruta del TC actual el número además pasó a ser correcto**, que no estaba pedido.
- [x] Ningún sitio de presentación queda usando `convert` a ciegas: barrido de las 36 llamadas con
      control positivo. **Clasificadas: 10 persisten (ticket propio) y 26 son de presentación.**
      Ninguna puede ya devolver el monto crudo — el arreglo está en el converter, no en el
      call-site. Las que no declaran calidad son las que no alimentan un total marcado.
- [x] Cálculo financiero ⇒ **review adversarial** antes del gate. Tres lentes; cazaron cinco
      defectos propios, los cinco arreglados y con test.

## Lo que falta para cerrar: device-QA

Cuenta multimoneda con la fila de tasas del día **incompleta**: comprobar que el «≈» aparece en el
Panel, Tendencias, Estadísticas y el saldo del panorama — y que **NO** aparece con el set completo.
En simulador no se reproduce un histórico real de tasas, así que el par «aparece / no aparece» es
justo lo que no puede afirmarse desde aquí.

Ojo al interpretarlo: hasta que se cierre `fx-manual-writes-seal-approximate-as-final`, la marca
puede **faltar** en totales cuyas transacciones nacieron mal selladas. Una ausencia de «≈» no
prueba, por sí sola, que la propagación esté rota.

---

## 2026-09-09 — el montaje que esperabas ya existe

El estado de partida se siembra desde un solo launch con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY` (ticket `qa-no-puede-crear-cuenta-en-otra-divisa`, **done**). Deja la cuenta «QA FX» con un ingreso y dos gastos fechados HOY, marcados `isExchangeRateProvisional` por el camino de producción — la fila del día existe y no trae JPY, así que la conversión es `.staticFallback`.

**Aviso para no leer un falso negativo:** con el filtro «Todo el tiempo» el fixture NO marca (750 sobre 206.725 son el 0,36 %, bajo el umbral del 5 %). **Acota el período** — con «Este mes» los tres números del Panel llevan «≈» y sin el arg ninguno.

**Queda desbloqueado ENTERO**, y el par «aparece / no aparece» que tu :118-119 daba por imposible en simulador está medido: con «Este mes», Disponible ≈ S/ 5.327,00 · Ingresos ≈ S/ 10.000,00 · Gastos ≈ S/ 4.673,00 **con** el arg, y S/ 4.577,00 · S/ 8.500,00 · S/ 3.923,00 **sin** él. Las diferencias son los importes del fixture al céntimo.

---

## Device-QA hecho · 2026-09-09 — PASS

Simulador iPhone 17 Pro (`9D0F6D32`), iOS 26.5, scheme `Yala Dev`. Lanzamiento:
`-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY`.

**El par «aparece / no aparece», que tu :118-119 daba por imposible en simulador, está medido en
este árbol** — no heredado del ticket ancla. Con «Este mes»:

| número | CON el arg | SIN el arg | Δ |
|---|---|---|---|
| Disponible | **≈ S/ 5.327,00** | S/ 4.577,00 | 750,00 |
| Ingresos | **≈ S/ 10.000,00** | S/ 8.500,00 | 1.500,00 |
| Gastos | **≈ S/ 4.673,00** | S/ 3.923,00 | 750,00 |

Las tres diferencias son los importes del fixture al céntimo (ingreso 1.500; gastos 400 + 350 = 750),
así que el testigo aritmético cierra: la marca aparece exactamente cuando entran esas filas y no
antes. Capturas `qa/evidencia-fx-20260909/01` y `/09`.

**Coherencia entre pantallas, con el mismo lanzamiento y el mismo filtro** — el número grande de
Estadísticas y su hero, los chips de Resumen y Tendencias, el hero de Registros y sus dos chips
(incluida la etiqueta de VoiceOver, que anuncia `≈ S/ 10.000,00`), el KPI de Flujo de Efectivo y el
panorama «Tienes ≈ S/ 79.011,40 en 3 cuentas»: **todos dicen lo mismo a la vez**.

**Y el falso negativo que avisabas es real y conviene no perderlo**: con «Todo el tiempo» ninguno de
los tres marca (750 sobre 206.725 son el 0,36 %, por debajo del 5 %). No es un fallo — es el umbral
haciendo su trabajo.

**Lo único que sigue fuera del simulador** es lo que tu propio texto ya decía: un histórico REAL de
tasas. El fixture reproduce la fila incompleta, no la historia.

## QA Visual · 2026-09-16 — PASS (re-verificado)

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`, seed `realista`, filtro «Este mes»:

| | CON `-uitest-seed-foreign-account JPY` | SIN el arg | Δ |
|---|---|---|---|
| Disponible | ≈ S/ 7,270.40 | S/ 6,520.40 | 750.00 |
| Ingresos | ≈ S/ 12,856.40 | S/ 11,356.40 | 1,500.00 |
| Gastos | ≈ S/ 5,586.00 | S/ 4,836.00 | 750.00 |

Las diferencias son los importes del fixture al céntimo: la marca aparece cuando entran esas filas, y
no antes. Con «Todo el tiempo» la Δ es la misma y nada marca (umbral del 5 %); el panorama sin el arg
dice S/ 69,930.45, 750 menos.

Capturas: [con el arg](../../qa/evidencia-barrido-20260916/07-fx-panel-este-mes-con-marca-CON-arg.jpg) · [sin el arg](../../qa/evidencia-barrido-20260916/10-fx-panel-este-mes-SIN-arg-sin-marca.jpg).

Lo que el simulador no da —un histórico **real** de tasas— sigue en la cola de device con
`fx-partial-rate-rows-silent-1to1` y `repair-queue-has-no-exit-for-partial-rate-rows`.
