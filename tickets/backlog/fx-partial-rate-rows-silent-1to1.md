---
id: fx-partial-rate-rows-silent-1to1
status: backlog
priority: high
area: "currency, fx, integridad-datos"
created: 2026-08-28
updated: 2026-08-28
---

# Filas de tasas FX incompletas y conversión 1:1 silenciosa que se declara exacta

## Reporte

Frank, audit FX diario 2026-08-28, sobre `2.1` @ `68a7221c`. Solo lectura de código: **no** hubo
device-QA ni números de usuario real. Jürgen pide archivarlo en `backlog`, prioridad **alta**, y como
**una sola familia** — no tres tickets.

Todas las coordenadas `archivo:línea` de este ticket fueron **re-medidas en `68a7221c`** (el mismo
árbol del audit). Si al retomar el árbol ya no es ese commit, re-medir antes de obedecerlas: es un
grep y en este repo la documentación envejece más rápido que el código.

## Síntoma

Cuando la fila de tasas de un día **existe pero no trae la divisa que se necesita**, la app no
convierte: devuelve el monto crudo (1:1) y **además lo declara exacto**. Un gasto de €500 en una
cuenta en EUR se cuenta como S/500 en la moneda preferida, en vez de las ~4× que le corresponderían
al tipo de cambio real (múltiplo ilustrativo, no medido). No hay error, no hay log, no hay badge de
"tasa provisional": el número simplemente está mal y parece bueno.

El 1:1 no se queda en pantalla. Hay al menos tres caminos que lo **escriben a disco** en
`TransactionItem.amountInPreferredCurrency` / `exchangeRate`, y desde ahí alimenta Ingresos/Gastos,
cashflow, sankey, reportes y widgets (28 ficheros bajo `Yala/App/Logic/Calculators/` y
`Yala/Services/` leen `amountInPreferredCurrency`; medido en este pase). Uno de esos caminos también
lo **emite por el canal nube** (`Yala/Services/CloudSync/EntityEmissionMap.swift`), así que el monto
envenenado puede viajar a otros dispositivos.

## La familia: una causa, tres caras

La causa común es que **en todo el módulo FX "la fila existe" se usa como sinónimo de "la fila
sirve"**. Nadie pregunta *qué divisas* trae la fila, salvo un único sitio (ver H1). Las tres caras
que siguen son consecuencias de esa confusión, no bugs independientes.

Dato clave para quien implemente: **el predicado de completitud ya está escrito**.
`ExchangeRateService.rateHasAllCurrencies` (`Yala/Services/ExchangeRateService.swift:441-448`)
compara las claves guardadas contra `Set(CurrencyCode.allRawValues)` y hoy lo consume **un solo
callsite**, `forceRefreshRates:187`. El resto del módulo sigue usando `rateExists:435-437`. El fix es
cablear un helper que ya existe y ya corre en producción, no inventar lógica nueva.

### H1 (lectura) — falta la divisa ⇒ 1:1, y `hasExactRate` dice `true`

1. `Yala/Services/CurrencyConverter.swift:289-292` — `performConversion` (283-314):

```swift
// CurrencyConverter.swift:289-292
        guard let fromRate = rates[fromCode], let toRate = rates[toCode] else {
            // If rates not available, return original amount
            return amount
        }
```

   Si `rates` no trae `fromCode` **o** `toCode`, devuelve el monto sin tocar. Mismo retorno en el
   segundo guard (`294-296`, `fromRate > 0`). El llamador no puede distinguir "convertido" de "no
   convertido": la firma devuelve `Decimal`, no un opcional ni un `Result`.

2. `Yala/Services/CurrencyConverter.swift:245-248` — `hasExactRate` responde por **existencia de
   fila**, no por contenido:

```swift
// CurrencyConverter.swift:245-248
    func hasExactRate(for date: Date, context: ModelContext) -> Bool {
        let dateKey = dateFormatter.string(from: date)
        return fetchExchangeRate(for: dateKey, context: context) != nil
    }
```

   Para una fila parcial devuelve `true`. De ahí el "se declara exacto" del título.

3. `ExchangeRateService.ensureRates:227-249` → `findMissingDates:462-478` → línea 469
   `if !rateExists(for: dateKey, context: context)`. Una fecha con fila parcial **no** figura como
   faltante, así que no se refetchea nunca por esta vía.

   Precisión útil (medida): cuando `ensureRates` **sí** fetchea, pide el set COMPLETO —
   `fetchAndPersistRates:367-383` resuelve `symbolsToFetch = symbols ?? supportedSymbols` (línea 371)
   y `ensureRates:238` no pasa `symbols`. Es decir: el problema es la **decisión** de no fetchear, no
   el set que pide. Corregir el predicado basta para que este camino se auto-sane; no hay que tocar la
   lógica de símbolos.

4. Quién crea las filas parciales: `preloadHistoricalIfNeeded:72-123`, línea 93
   `let requiredCurrencies = Array(getRequiredCurrencies(context: context))`, pasado como `symbols:`
   en la línea 109. `getRequiredCurrencies:511-539` = preferida + secundarias + divisas de las
   cuentas **existentes en ese momento**. Se escriben así 12 chunks mensuales (`for monthOffset in
   0..<12`, línea 100).

   El agujero es temporal: si el usuario **añade después** una cuenta en una divisa nueva, todas esas
   fechas ya están en disco sin esa divisa, cuentan como presentes (punto 3) y convierten 1:1
   (punto 1). Nada las revisita salvo `forceRefreshRates`, que solo se dispara desde Ajustes de
   moneda (`CurrencySettingsView:392` y `:436`).

   Ventana en la que corre el preload (guards `77-90`): primer arranque, después de un borrado de
   datos, o re-corrida a los 30 días si `countExistingRates <= 300`.

**Instancia extra del mismo patrón, medida en este pase (no venía en el audit):**
`updateTodayIfNeeded:127-149` también decide por existencia — línea 131
`if rateExists(for: todayKey, context: context) { return }`. Si la fila de hoy ya está en disco pero
parcial, el fetch del set completo se salta entero. Combinado con H3, en un **relanzamiento el mismo
día** la fila de hoy se queda parcial hasta que cambie el día. La regla del repo pide barrer todas las
instancias del patrón antes de declarar un fix completo: los sitios que hoy deciden por existencia son
`findMissingDates:469`, `updateTodayIfNeeded:131` y `hasExactRate:245-248`.

### H1-b (la cara que persiste sola, sin que el usuario toque nada)

`hasExactRate` no es solo un flag de presentación: **gatea una escritura** que corre en cada arranque.

`Yala/Services/TransactionUpdateService.swift:28-117`, `updateProvisionalTransactions`:

- línea 59 → `ensureRates` (el camino existence-only de H1) → con filas parciales en disco no fetchea nada.
- línea 68 → `if CurrencyConverter.shared.hasExactRate(...)` → `true` para la fila parcial.
- línea 71 → `convert(...)` → 1:1 por la divisa ausente.
- líneas 90-94 → persiste `exchangeRate = abs(1.0)`, `amountInPreferredCurrency` = monto crudo, y
  **`isExchangeRateProvisional = false`**.

Ese último flag es el que hace daño duradero: el `FetchDescriptor` de la línea 37 solo busca
`isExchangeRateProvisional == true`, así que al marcarla como definitiva **el servicio no la vuelve a
mirar nunca**. La transacción queda con un 1:1 sellado como oficial, y ya no hay proceso automático
que lo repare.

Corre en `AppBootstrapper.loadExchangeRates:2156` (cada arranque), en `UserDataResetView:265`
(post-wipe) y en `ImportIntroSheet:583` y `:692` (post-import).

Los 4 sitios de `Yala/Utils/TransactionCSVImportService.swift` que hacen
`isExchangeRateProvisional: !hasExactRate` (`:163/195`, `:1079/1111`, `:1472/1502`, `:1629/1659`)
escriben ese mismo flag desde la misma señal equivocada: una TX importada en una fecha con fila
parcial nace 1:1 y **no** provisional.

### H2 (persistencia; la peor para el usuario) — migrar antes de tener tasas

`Yala/App/Views/Settings/CurrencySettingsView.swift:401-455`, `updatePreferredCurrency`. Orden real
dentro del `Task` (línea 414):

| Orden | Línea | Qué hace |
|---|---|---|
| 1.º | 417-423 | `CurrencyChangeService.updateAllTransactions(to:)` — **migra y guarda todos los montos** |
| 2.º | 426 | `appPreferences.defaultCurrencyCode = newCurrency` |
| 3.º | 429 | `forceUpdateToday` |
| 4.º | 434-437 | `forceRefreshRates` (1 año) |

Las tasas llegan en los pasos 3 y 4, **después** de que el paso 1 ya escribió los montos. Y
`forceRefreshRates` solo repuebla `ExchangeRate`: **no re-migra** `TransactionItem`. Los montos
envenenados se quedan en disco.

Cadena dentro de `Yala/Services/CurrencyChangeService.swift:25-86`:

- `41-46` — `await ExchangeRateService.shared.ensureRates(...)`: es el camino existence-only de H1.
  Con filas parciales ya en disco, decide que no falta nada y no fetchea.
- `59-65` — `CurrencyConverter.shared.convert(...)` → 1:1 para la divisa ausente.
- `68-74` — `effectiveRate = amountInPreferred / amount` → exactamente `1.0`.
- `77-80` — persiste `amountInPreferredCurrency` (= monto crudo), `exchangeRate = abs(effectiveRate)`
  = `1.0` y `preferredCurrencyCode = newCurrencyCode`.
- `84` — `try context.save()`.

Resultado: una cuenta multi-moneda que cambia de moneda preferida puede quedar con filas a `1.0`
para toda divisa que faltara en las filas parciales, y eso es lo que leen después Ingresos/Gastos,
cashflow, sankey, reportes y widgets.

### H3 (escritura) — `persistRate` sobrescribe el blob en vez de fusionarlo

`Yala/Services/ExchangeRateService.swift:396-400`:

```swift
// ExchangeRateService.swift:396-400
        if let existing = fetchExchangeRate(for: dateKey, context: context) {
            // Update existing rate
            let data = try JSONEncoder().encode(rates)
            existing.rates = data
            existing.timestamp = timestamp
        }
```

`existing.rates = data` reemplaza el blob completo: lo que la fila ya tenía y el `rates` nuevo no
trae, **se pierde**. Y `timestamp` es un parámetro con default `nil` (línea 386) que se asigna
incondicionalmente, así que un llamador que no lo pasa **borra** el timestamp que había.

El mismo arranque hace las dos cosas, en este orden — `AppBootstrapper.loadExchangeRates:2148-2157`:

1. `updateTodayIfNeeded:2150` → persiste hoy con `supportedSymbols` (= `CurrencyCode.allRawValues`) y
   `timestamp: result.timestamp` de la API.
2. `preloadHistoricalIfNeeded:2153` → en `monthOffset == 0` el chunk termina en `today` (línea 101),
   así que el rango **incluye hoy**; persiste vía `fetchAndPersistRates:381`, que llama a
   `persistRate` **sin** `timestamp`.

Neto: la fila de hoy queda con el set parcial y `timestamp = nil`. El trabajo bueno del paso 1 se
pisa a sí mismo en el mismo arranque.

Segundo callsite con el mismo orden: `Yala/App/Views/Settings/UserDataResetView.swift:263-264`
(post-wipe) — y post-wipe es justo cuando los guards del preload no cortocircuitan, así que ahí el
pisado es lo esperable, no lo excepcional.

**Además, divergencia caché ↔ store.** `persistRate` no postea `.yalaExchangeRatesUpdated`; los
únicos que lo postean son `updateTodayIfNeeded:142` y `forceUpdateToday:164`. El observer
(`AppBootstrapper.observeExchangeRateUpdates:932-940` → `invalidateLatestRatesCache`) por tanto no se
dispara cuando el preload pisa la fila. La caché en memoria de `CurrencyConverter`
(`latestRatesCache:65`, con clave de día en `cachedLatestRates:272-281`) se queda con el set COMPLETO
del paso 1 mientras el store ya tiene el parcial.

Esto explica por qué el bug es difícil de ver a ojo, y conviene tenerlo presente al reproducir:
`convertWithLatestRate` (Panel, saldo vivo) sigue dando un número plausible desde la caché, mientras
`convert(on: date)` — el que usan los caminos que **escriben** — devuelve 1:1 leyendo el store. La
pantalla se ve bien y el disco se envenena.

## Por qué es un solo ticket y no tres

H3 crea las filas parciales y borra el timestamp. H1 las acepta como buenas y las declara exactas.
H1-b y H2 las convierten en montos persistidos a 1:1. Arreglar solo H2 (reordenar el cambio de
moneda preferida) deja el 1:1 entrando por el arranque vía H1-b. Arreglar solo H1 sin H3 deja la fila
de hoy perdiendo divisas y timestamp en cada primer arranque. Comparten el predicado
(`rateExists` vs `rateHasAllCurrencies`) y el mismo helper de conversión.

## Distinto de (ya existen; no duplicar)

- `tickets/backlog/distribution-balance-kpi-skips-fx.md` — KPI de Balance Panel vs Distribución
  (stock vs flujo). Ese es *qué base de conversión* usa cada vista; este es que **no hay tasa** y
  nadie lo dice.
- `tickets/qa/cloud-fx-rates-blob-two-faces.md` — decode del blob `rates` tras el round-trip por
  nube (strings escala-8 vs doubles), fix read-side en `ExchangeRate.decodedRates()`. Aquí el blob se
  decodifica bien: el problema es que **le faltan claves** porque `persistRate` local lo sobrescribió.
  Nota: ese ticket ya mencionaba el sobrescribir de `persistRate`, pero como **atenuante** que
  enmascaraba su bug, nunca como defecto propio.
- `tickets/backlog/fx-pnl-education-card.md` — idea de card educativa de P&L por FX.
- `tickets/backlog/groups-guest-currency-from-region.md` — moneda del invitado derivada de la región.

## Orden de fix recomendado (NO implementar en este ticket)

**Paso 1 — H3 + H1 juntos** (uno sin el otro deja el agujero abierto):

- `persistRate`: **fusionar** en vez de reemplazar (partir del `decodedRates()` existente y
  sobrescribir solo las claves entrantes), y no pisar `timestamp` con `nil` cuando el llamador no lo
  pasa.
- Decidir por **completitud**, no por existencia, en los tres sitios listados en H1
  (`findMissingDates:469`, `updateTodayIfNeeded:131`, `hasExactRate:245-248`). `rateHasAllCurrencies`
  ya existe (`:441-448`); hoy es `private` y solo la usa `forceRefreshRates:187`.
  Ojo al criterio: `rateHasAllCurrencies` exige las **53** divisas de `CurrencyCode` (medido en
  `Yala/Utils/CurrencyUtils.swift`, casos en `:61-126`; tanto el audit como `CLAUDE.md` dicen "~48" —
  cifra desactualizada, re-medir antes de reusarla). Para el camino de lectura puede bastar
  "¿está *esta* divisa?" en vez de "¿están las 53?"; elegir explícitamente y dejarlo escrito, porque
  el criterio estricto puede marcar como incompletas casi todas las filas históricas.
- Que una divisa ausente **deje de ser un 1:1 silencioso**: que el camino de conversión pueda decir
  "no pude" (opcional / `Result` / flag) y que quien persiste trate ese caso como provisional en vez
  de sellarlo. Sin esto, H1-b sigue marcando `isExchangeRateProvisional = false`.

**Paso 2 — H2:**

- Refrescar tasas **antes** de migrar en `updatePreferredCurrency` (mover `forceUpdateToday` /
  `forceRefreshRates` delante de `updateAllTransactions`).
- Re-convertir las filas ya persistidas con `exchangeRate == 1.0` donde las divisas de origen y
  destino difieren (candidatas a migración one-shot idempotente). Decidir si se limita a
  `currencyCode != preferredCurrencyCode`, para no tocar las filas donde 1.0 es legítimo.

## Notas para quien implemente

- `exchangeRate == 1.0` es **legítimo** cuando origen y destino son la misma divisa. Cualquier barrido
  o migración tiene que filtrar por `currencyCode != preferredCurrencyCode`; si no, reconvierte filas
  sanas.
- `effectiveRate` también cae a `1.0` por una razón distinta y benigna: monto ~0
  (`CurrencyChangeService:70-74` y `TransactionUpdateService:82-87`, `abs(amount) > 0.0001`). No
  confundir ese caso con el envenenado.
- `persistRate` tiene un gate de quiescencia de import al inicio (`:391-394`) que hace `return` sin
  escribir. Cualquier cambio de merge debe quedar **después** de ese guard.
- `ExchangeRate` vive en el store personal y viaja por nube; el blob puede llegar con valores string
  (ver `cloud-fx-rates-blob-two-faces`). Un merge debe construirse sobre `decodedRates()`, que ya
  tolera las dos caras — no sobre un decode estricto propio.
- Al implementar aplica la regla anti-drift del repo: tocar código bajo `Yala/` obliga a actualizar el
  área correspondiente de la SSOT de cobertura en el MISMO commit. Este ticket no toca código, así que
  aquí no hay nada que actualizar todavía.

## HOLD

Sin implementación en este ticket: cero Swift. `status` sigue `backlog`. No inventar PASS. Sin App
Store, sin tag de release, sin TestFlight.

## Acceptance Criteria

- [ ] Una fecha con fila **parcial** preescrita por el preload, y después una cuenta en una divisa
      nueva: la conversión en esa fecha **no** es 1:1 y **no** se marca como exacta
      (`hasExactRate` / `isExchangeRateProvisional` reflejan que falta la tasa).
- [ ] `persistRate` con un set parcial **no** descarta las divisas que la fila de hoy ya tenía, y el
      `timestamp` de hoy **no** queda borrado por el preload histórico del mismo arranque.
- [ ] Cambiar la moneda preferida a una divisa que faltaba en las filas parciales **no** persiste
      `exchangeRate == 1.0`; después del cambio, los KPI de flujo (Ingresos/Gastos) coinciden con una
      conversión correcta.

Verificación pendiente: los tres criterios se comprueban cuando se implemente el fix. Hoy no hay
device-QA y no se inventa PASS.
