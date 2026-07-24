---
description: Auditoría de localización — corre la batería de paridad y busca strings sin localizar en el código
allowed-tools: Bash(xcodebuild:*), Bash(bash qa/scripts/add-l10n-key.sh:*), Grep, Glob, Read
argument-hint: "[locale concreto, o vacío para todo]"
---

La verdad sobre la localización de Yala es **ejecutable**: vive en `YalaTests/LocalizationParityTests.swift` (15 tests) y en `YalaTests/WidgetLocalizationParityTests.swift`. Este comando los corre e interpreta; no reimplementa sus comprobaciones a mano.

## 1 · Batería de paridad

```bash
xcodebuild -scheme "Yala Dev" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet test -only-testing:YalaTests/LocalizationParityTests \
  -only-testing:YalaTests/WidgetLocalizationParityTests 2>&1 \
  | grep -E "(Test Case|Executed|passed|failed|error:)"
```

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
