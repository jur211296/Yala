---
id: preferred-currency-has-three-different-defaults
status: backlog
priority: medium
area: "currency, preferences"
created: 2026-09-09
updated: 2026-10-08
source: hallazgo de camino de `qa-no-puede-crear-cuenta-en-otra-divisa` (2026-09-09)
---

# Cuatro sitios leen la divisa preferida y, si falta, se responden tres cosas distintas

## Qué pasa

`defaultCurrencyCode` es una key de `UserDefaults`. La escriben el onboarding y los ajustes, y la
**borra** «Empiezo de cero» (`DataWipeService.swift:566`). Cuando no está —usuario recién barrido,
o cualquier arranque que salte el onboarding— cada lector se inventa un default distinto:

| dónde | qué devuelve si la key falta |
|---|---|
| `Yala/Utils/CurrencyUtils.swift:829` (`CurrencyDefaults.currentPreferred`) | **la región del dispositivo** (`detectCurrencyFromRegion()`) |
| `Yala/App/Services/AppPreferences.swift:81` | **`.pen`** |
| `Yala/Services/ExchangeRateService.swift:693` | **`"PEN"`** |
| `Yala/Services/WidgetDataCache.swift:372` | **`"USD"`** |

Los cuatro medidos el 2026-09-09 en el árbol de `encargo/2026-09-09-qa-no-puede-crear-cuenta-en-otra-divisa`.

La línea del widget es la más llamativa por lo que tiene justo encima:

```swift
// Get preferred currency from user settings (single source of truth)
let preferredCurrency = UserDefaults.standard.string(forKey: CurrencyDefaults.preferredCurrencyKey) ?? "USD"
```

El comentario dice «single source of truth» y la línea es la que más se aparta de las otras tres.

Hay una quinta dimensión, y conviene mirarla en el mismo pase: dos de los cuatro leen
`UserDefaults.standard` y dos leen `SessionDefaults.current`. Bajo sesión secundaria esos dominios
divergen a propósito (`SessionDefaults.swift`), así que la pregunta «¿de quién es esta divisa?»
también tiene hoy dos respuestas.

## Por qué importa

`CurrencyDefaults.currentPreferred` es lo que usa `TransactionItem.recalculatePreferredCurrency`
para decidir la divisa DESTINO de una conversión que se **persiste en disco** y se emite al canal
nube. Si ese lector dice USD (región `US`) mientras `AppPreferences` pinta PEN, la app enseña un
total en soles construido con importes convertidos a dólares. No es una preferencia de formato: es
el número.

El caso de usuario que lo dispara está escrito en el propio wipe — «Empiezo de cero» borra la key y
deja la app leyéndola de cuatro sitios que no coinciden.

## Lo que NO es

No se ha observado el síntoma en pantalla. Esto es un hallazgo **estructural, medido en el código**,
no un bug reproducido: en la Mac del owner el simulador es `es_PE`, así que
`detectCurrencyFromRegion()` devuelve PEN y los cuatro defaults coinciden por casualidad del
entorno. **Esa coincidencia es justo lo que lo hace invisible aquí y visible fuera.**

## Cómo se sabe que está bien

- Un solo sitio decide el default de la divisa preferida cuando la key falta, y los otros tres lo
  llaman. Un source-scan que impida que vuelva a aparecer un `?? "PEN"` o un `?? "USD"` suelto,
  al estilo del que ya protege el centinela del seed (`UITestSeamPersistenceIsolationTests`).
- Un test que fije la región a una NO peruana y compruebe que los cuatro lectores coinciden.
  `detectCurrencyFromRegion(regionCode:)` ya es inyectable, así que no hace falta tocar el entorno.
- Decidir cuál es el default correcto es parte del ticket, y no es obvio: la región es más útil para
  un usuario nuevo, y un literal es más predecible para el reparador de tasas.

## Medido en 2.1 (triage 2026-10-08)

- Siguen los cuatro defaults:
  - `CurrencyUtils.swift:829` → región (`defaultCode`, `:820`).
  - `AppPreferences.swift:81` → `.pen`.
  - `ExchangeRateService.swift:693` → `"PEN"`.
  - `WidgetDataCache.swift:350` → `"USD"`.
- La quinta dimensión se cerró: 1cf0030b1 dejó un solo dominio de preferencias, y los cuatro leen `UserDefaults.standard`.
- «Empiezo de cero» sigue borrando la key (`Yala/Utils/DataWipeService.swift:1217`).

## Pregunta para Jürgen (triage 2026-10-08)

¿Qué divisa preferida vale si la key falta?

- **A** (recomendada): la de la región del dispositivo, que es lo que ya usa `CurrencyDefaults.currentPreferred`, el lector que decide la conversión persistida. Los otros tres la llaman.
- **B**: PEN literal en los cuatro.
- **C**: USD literal en los cuatro.

Con A, la prioridad es `medium`.

Triage 2026-10-08: abierto · medium → medium · siguen cuatro defaults distintos (región / `.pen` / `"PEN"` / `"USD"` en `WidgetDataCache.swift:350`); solo se cerró lo del dominio, en 1cf0030b1.

## Medido de camino (2026-10-09, `exchange-rate-detail-shows-zero-for-low-denomination-currencies`)

Otra cara del mismo defecto, en un fixture de QA. Arranque con `-uitest -uitest-reset -uitest-skip-onboarding
-uitest-pro -uitest-seed realista -uitest-seed-foreign-account VND -AppleLanguages (es) -AppleLocale es_ES`:
el Panel y Registros enseñan todo en **S/**, pero los gastos «QA-FX VND» se guardaron convertidos a **EUR**
(el detalle dice «≈ € -350,00»). `DevSeedForeignCurrencyAccount` lee la preferida de
`CurrencyDefaults.currentPreferred` (L104); inferido, sin medir: con `es_ES` esa lectura cae a la región (EUR).
Un `/qa` de la familia FX con ese fixture mide otra divisa de la que cree medir.
