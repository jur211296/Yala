---
description: Auditoría de localización — corre la batería de paridad y busca strings sin localizar en el código
allowed-tools: Bash(xcodebuild:*), Bash(python3 -I qa/scripts/suites-de-fichero.py:*), Bash(grep:*), Bash(bash qa/scripts/sim-lock.sh:*), Bash(bash qa/scripts/add-l10n-key.sh:*), Grep, Glob, Read
argument-hint: "[locale concreto, o vacío para todo]"
---

La verdad sobre la localización de Yala es **ejecutable**: vive en `YalaTests/LocalizationParityTests.swift` y en `YalaTests/WidgetLocalizationParityTests.swift`. Este comando corre **todas** sus suites y las interpreta; no reimplementa sus comprobaciones a mano.

## 1 · Batería de paridad

Primero, las suites. **No se piden por el nombre del fichero**: `-only-testing` casa por el TIPO, y `LocalizationParityTests.swift` declara tres (`LocalizationParityTests`, `BundleLocaleDriftTests` y `StringsdictParityTests`), ninguna con `@Suite`. Hasta el 2026-11-04 este comando pedía solo la primera y se dejaba cuatro casos sin correr: la deriva entre el bundle y `SupportedLocale` y las tres comprobaciones de los `.stringsdict`.

```bash
python3 -I qa/scripts/suites-de-fichero.py --only-testing YalaTests \
  YalaTests/LocalizationParityTests.swift YalaTests/WidgetLocalizationParityTests.swift
```

Y la corrida, con esos filtros:

```bash
bash qa/scripts/sim-lock.sh -- \
  xcodebuild -scheme "Yala Dev" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test <los -only-testing de arriba> 2>&1 \
  | grep -E "(Test run with|passed|failed|error:)"
```

**Sin `-quiet`, y no es cosmético**: `-quiet` suprime la línea `Test run with N tests in M suites`, la única con el conteo, y los marcadores `Test Case`/`Executed` son de XCTest, que este repo no usa en `YalaTests`. Sin esa línea, una corrida que no ejecutó nada sale con `TEST SUCCEEDED` y no hay forma de verlo.

**Criterio del conteo**: M ≥ el número de suites pedidas, y N igual a los `@Test` de los dos ficheros (`grep -c '^ *@Test' YalaTests/LocalizationParityTests.swift YalaTests/WidgetLocalizationParityTests.swift`). Si no cuadra, la batería no corrió entera y el veredicto no vale. No escribas aquí el número: cambia cada vez que alguien añade un test.

`sim-lock.sh` es la cola del simulador: esta batería corre *dentro* de él, así que compite con el
gate de las otras sesiones igual que cualquier otra corrida. Si está tomado, **espera** y lo dice;
no falla. Por qué existe: `.claude/rules/testing.md`, la regla del simulador compartido.

Qué cubre cada fallo, para que sepas leerlo:

| Test | Qué significa que falle |
|---|---|
| `everyBaseLocale_hasAllKeys_fromReference` | Falta una key en un locale base |
| `variants_haveAllKeys_fromParent` | Una variante (`es-ES`/`es-AR`/`en-GB`/`pt-PT`) quedó sparse — **iOS NO hace fallback per-key con idioma de sistema**, así que ahí se ve la key cruda |
| `aliases_haveIdenticalValues_toTheirBase` | `es` o `pt` divergieron de `es-419`/`pt-BR`. Son **artefactos generados**: se regeneran por copia, no se editan |
| `noDuplicateKeys_inAnyLocale` | Key repetida en un `.strings`: gana la última, en silencio |
| `placeholders_matchAcrossLocales` | Riesgo de crash en runtime |
| `noNeedsTranslationMarker_anywhere` | Quedó un `[NEEDS_TRANSLATION]` del script sin traducir |
| `noEmptyValues_anywhere` | La UI mostraría vacío |
| `bundleLocales_matchSupportedLocaleEnum` | El bundle trae un idioma que `SupportedLocale` no conoce, o al revés |
| `baseLocalesWithStringsdict_haveSameKeys` | Un `.stringsdict` de un locale base perdió o ganó una key de plural |
| `pluralRule_pl_hasOneFewManyOther` | Al polaco le falta alguna de sus cuatro formas de plural (`one`/`few`/`many`/`other`) |
| `variants_doNotCreateOwnStringsdict` | Una variante trae su propio `.stringsdict`: es todo o nada por fichero, y obligaría a duplicar todos los plurales del padre |

## 2 · Strings sin localizar en el código

Esto es lo único que los tests **no** ven, y por tanto lo único que aporta este comando:

```
Grep: Text\("[A-ZÁÉÍÓÚÑ] en Yala/ --include=*.swift
```

Descarta: SF Symbols, `.accessibilityIdentifier`, texto de debug bajo `#if DEBUG`, formatos numéricos, y `Yala/Widgets/` (tiene sus propias strings). Reporta `archivo:línea` con el literal.

## 3 · Si hay que añadir keys

`bash qa/scripts/add-l10n-key.sh "mi.key" "Texto en es-419" "Comment"` — materializa la key en los 10 locales base **y regenera los alias `es`/`pt`**. No edites los `.strings` a mano para añadir: el script existe justamente porque hacerlo a mano fue lo que rompió el invariante de los alias durante tres meses.

Después de añadir, traduce cada locale y vuelve al paso 1.

## Reporte

Veredicto (`LIMPIO` o `N ISSUES`), los tests en rojo con su lectura de la tabla, y la lista de literales sin localizar. Nada más.

## Reglas

- **No cuentes locales a mano ni asumas cuántos hay**: los tests leen `SupportedLocale` y el bundle real. Si tu recuento y el suyo difieren, el equivocado eres tú.
- Un test de paridad en rojo es **bloqueante para release**. Un literal sin localizar es deuda, no bloqueo.
