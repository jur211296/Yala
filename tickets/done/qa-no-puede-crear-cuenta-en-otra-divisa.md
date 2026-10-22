---
id: qa-no-puede-crear-cuenta-en-otra-divisa
status: done
priority: high
area: "testing, currency, qa"
created: 2026-09-08
updated: 2026-09-09
source: barrido de QA en simulador del 2026-09-08 (bloqueo medido)
---

# Sin poder elegir divisa desde la automatización, cuatro tickets de FX no se pueden cerrar

## Qué pasa

Toda la familia FX pendiente necesita el mismo estado de partida: **una cuenta en una divisa que no
esté en la fila de tasas del día** (las filas sembradas traen solo `PEN`, `EUR` y `USD` —
`DevSeedExchangeRates.swift:56-60` — así que cualquier otra sirve: JPY, CLP…).

El camino de usuario es Perfil → Cuentas → Añadir → **Moneda**. Medido el 2026-09-08: ese selector
es un `NavigationLink` (`AccountFormView.swift:250-253`) y **no responde a los taps sintéticos de
la automatización de QA**. Se intentó cuatro veces (tap, tap tras cerrar teclado, `touch` down/up
con retardo, y `wait_for_ui` a `settled`) y la pila de navegación no cambia.

**No es un bug de la app**, y conviene dejarlo escrito para que nadie lo persiga por ahí: en la
misma pantalla el campo de texto del nombre **sí** acepta escritura, y los botones normales
(«Añadir», «Cuentas») **sí** responden. El control cruzado lo confirma: el otro `NavigationLink`
del mismo formulario («Tipo») tampoco abre, así que el fallo va con el patrón, no con la moneda.

> **Las dos coordenadas de arriba se re-midieron el 2026-09-09 y siguen siendo ciertas.**

## Qué bloquea, concretamente

> **Corregido el 2026-09-09 tras medirlo: no son cuatro, son SIETE**, y la lista original mezclaba
> tres cosas distintas. El barrido de las seis carpetas de `tickets/` dio esto:

| Ticket | ¿basta este montaje? | qué dice su propio texto |
|---|---|---|
| `fx-approximate-mark-missing-on-secondary-surfaces` | **sí, entero** | pide exactamente «una cuenta en divisa ausente de la fila de tasas» (:213) |
| `fx-presentation-still-shows-1to1` | **sí, entero** | pide «cuenta multimoneda con la fila del día incompleta» (:116) |
| `bridge-de-grupos-pierde-la-marca-de-sus-patas` | sí, con seed más rico | pide además «dos patas selladas con coberturas distintas» (:112) |
| `chat-rows-sealed-before-the-fix-have-no-repair-path` | sí, con seed más rico | pide además una fila sembrada con `exchangeRate = 1.0` (:156) |
| `fx-manual-writes-seal-approximate-as-final` | **parcial** | su texto pide además **red** (:108) |
| `fx-partial-rate-rows-silent-1to1` | **parcial** | pide **red** (:397) y, en su AC nº3, cambiar la divisa preferida |
| `chat-assistant-plants-exchange-rate-one` | **parcial** | pide además «el chat contra el LLM real» (:131) |

Y dos que la lista original contaba de más:

- `approximate-mark-ors-over-whole-period` **no declara bloqueo alguno** — cero menciones de
  device-QA o de simulabilidad en sus 223 líneas. Su AC es unit y su decisión ya está tomada.
- `chat-draft-stamps-its-own-currency-not-the-account` necesita justo lo contrario: dictar en una
  divisa en la que **no** se tenga cuenta (:130). Este montaje se la crearía.

**Y una premisa falsa que conviene enterrar**, porque está escrita en dos tickets vivos
(`chat-assistant-plants-exchange-rate-one:130`, `bridge-de-grupos…:113`): «ningún seed es
multi-divisa». Lo es desde siempre — `DevSeedAccounts` crea PEN + USD — y dos tickets ya cerrados lo
habían medido (`done/fx-pnl-education-card:213`, `done/distribution-balance-kpi-skips-fx:281`). Lo
que faltaba no era multi-divisa: era **una divisa fuera de la fila**.

## Salidas posibles (elegir una)

1. **Un launch arg** tipo `-uitest-seed-foreign-account <ISO>` que siembre una cuenta en esa divisa
   con saldo. Es lo más barato y lo que deja los cuatro tickets cerrables en una tarde.
2. **Un perfil de seed** `multi-divisa-parcial` que ya traiga la cuenta y un par de movimientos con
   fecha dentro del histórico sembrado.
3. **Cambiar la divisa preferida por arg** (`-uitest-preferred-currency <ISO>`): ejercita además
   `CurrencyChangeService`, que el ticket `fx-manual-writes` señala como «el peor de los diez
   sitios» porque reescribe el histórico entero.

La 1 y la 3 son complementarias y cubren lados distintos del problema.

## Cómo se sabe que está bien

Desde un solo launch, sin tocar la UI de creación de cuentas, se puede llegar a un estado donde
existe una transacción en una divisa ausente de la fila del día, y comprobar en su detalle que la
tasa guardada **no** es 1,0000 y que el importe convertido aparece marcado como aproximado.

---

## Resuelto — 2026-09-09 · salida 1

`-uitest-seed-foreign-account <ISO>`, aditivo al perfil y **apagado por defecto**.

```
-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista \
        -uitest-seed-foreign-account JPY
```

Siembra la cuenta «QA FX» con un ingreso y dos gastos fechados HOY. Lo que hace utilizable el
fixture, y lo que lo separa del resto del seed: **las tres filas se recalculan con
`recalculatePreferredCurrency`, nunca con la tasa escrita a mano**. El resto de
`DevSeedTransactions` planta `exchangeRate: basePenRate` directamente y deja
`isExchangeRateProvisional` en su default `false`, así que cualquier aserción sobre ese flag sobre
el corpus normal es **vacua por construcción**. Aquí la calidad la decide `CurrencyConverter`: la
fila del día existe pero no trae JPY ⇒ `resolveRates` baja hasta la tabla estática ⇒
`.staticFallback` ⇒ `isExact == false` ⇒ marca.

**Los importes se derivan, no se escriben.** El objetivo se fija en la divisa PREFERIDA (1.500 de
ingreso, 400 + 350 de gasto) y el importe nativo sale de convertirlo. Con importes nativos fijos el
mismo comando pesaría cosas distintas según el ISO —12.000 unidades son ~285 soles en yenes y ~45 en
pesos chilenos— y la marca es una PROPORCIÓN (5 %, `ApproximateMarkThreshold`).

### AC verificado en el simulador (iPhone 17 Pro, un solo launch)

Detalle de la transacción de ingreso: **`≈ S/ 1500.00 (TC: 0.0237)`**. Tasa ≠ 1,0000 ✓, marca de
aproximado ✓.

Y el par «aparece / no aparece» que pedía `fx-presentation-still-shows-1to1`, con el filtro **Este
mes**:

| número del Panel | con el arg | sin el arg | Δ |
|---|---|---|---|
| Disponible | **≈** S/ 5.327,00 | S/ 4.577,00 | 750,00 |
| Ingresos | **≈** S/ 10.000,00 | S/ 8.500,00 | 1.500,00 |
| Gastos | **≈** S/ 4.673,00 | S/ 3.923,00 | 750,00 |
| Saldo agregado | **≈** S/ 79.011,40 · **3 cuentas** | S/ 78.261,40 · **2 cuentas** | 750,00 |

Las cuatro diferencias son exactamente los importes objetivo, al céntimo, y el «≈» aparece **solo**
con el arg — que es lo que lo hace señal y no ruido.

### Una trampa del montaje, para que nadie la lea como fallo

**Con el filtro «Todo el tiempo» el fixture NO marca**, y es correcto: 750 sobre los 206.725 de
gasto del histórico de 730 días son el 0,36 %, por debajo del umbral del 5 %. Es el mismo efecto que
`.claude/rules/currency-fx.md` documenta como «la marca se perdía justo en quien más historial
tiene». **Para ver la marca hay que acotar el período** (Este mes / Esta semana / Últimos 30 días).

### Redes

- `YalaTests/DevSeedForeignCurrencyAccountTests` — 8 casos. **Matriz de mutación de 5**, y cada
  aserción central muere con la suya: tasa escrita a mano, sin recalcular, importe nativo fijo,
  marcar siempre (mata el control negativo) y quitar el lado ingreso.
- `YalaUITests/ForeignCurrencyAccountSeedUITests` — 2 casos en pareja, el **cableado** arg → store,
  que es lo único que los unit tests no pueden ver. Mutado retirando la llamada del
  `AppBootstrapper`: mata el positivo y deja el negativo verde.
- El arg va **nombrado** en `launchForUITest(foreignAccount:)`, no por `extraArguments:`, por la
  razón que ese helper ya documenta cuatro veces: un typo en un string suelto se ignora en silencio
  y da un VERDE que mide el corpus sin filas aproximadas creyendo medirlo con ellas.

### Lo que NO se hizo, y por qué

La salida 3 (`-uitest-preferred-currency <ISO>`) no entra: el AC no la pide y ejercita otro objeto
—`CurrencyChangeService`, que reescribe el histórico entero—. La pide el AC nº3 de
`fx-partial-rate-rows-silent-1to1`; queda anotada allí.

Hallazgo de camino, en ticket propio: **`preferred-currency-has-three-different-defaults`**.
