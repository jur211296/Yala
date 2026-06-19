# Prompt: traducir Yala completo a nl (Holandés)

> Copia todo el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` y pégalo en una sesión nueva de Claude Code dentro del repo `/Users/jur/Yala`.

--- BEGIN PROMPT ---

Tu tarea es traducir el archivo `Localizable.strings` de Yala (app iOS de finanzas personales) del **inglés al holandés (nl-NL)** con calidad de producción. Reemplazar la traducción rule-based v0 actual de `nl.lproj` con traducciones reales keys-por-keys.

## Archivos

**Reference (NO tocar):** `/Users/jur/Yala/Yala/Resources/en.lproj/Localizable.strings` — 3,041 keys, ~3,580 líneas, calidad nativa.

**A reemplazar:**
1. `/Users/jur/Yala/Yala/Resources/nl.lproj/Localizable.strings` (3,041 keys)
2. `/Users/jur/Yala/YalaWidgets/Resources/nl.lproj/Localizable.strings` (115 keys)

**NO tocar:**
- `nl.lproj/Localizable.stringsdict` (plurales ya traducidos correctamente)
- `nl.lproj/InfoPlist.strings` (ya traducido)

## Pre-existencias importantes (NO son bugs)

- **El reference `en.lproj` tiene 31 keys duplicadas declaradas dos veces.** Apple usa el último valor cargado. Tu archivo `nl.lproj` debe **preservar las mismas duplicaciones** — no consolidar a una sola. Si una key aparece 2 veces en en.lproj, también aparece 2 veces en nl.lproj con valores consistentes (idealmente idénticos).
- **El parser de validación reporta 3010 unique keys**, no 3041 (porque dedupe). Esto es correcto. Esperarás output `en=3010 nl=3010 missing=0 extra=0`.
- **Hay ~30 keys "huérfanas"** declaradas inline entre secciones MARK (e.g., `common.recent`, `tag.new`, `settings.currencyAndExchange` aparecen entre las secciones `Profile` y `Export` sin pertenecer a ninguna). Asegúrate de cubrirlas — un Edit por sección MARK aislada las perdería.

## Approach técnico (CRÍTICO — basado en sesión real exitosa)

**NO uses un `Write` enorme con todo el archivo.** El archivo en.lproj son ~290KB (~70K tokens) — el modelo no puede outputear eso en una sola respuesta.

**Approach que funciona** (validado en sesión nl-NL real):

1. **Lee `en.lproj/Localizable.strings` en chunks de 500–700 líneas** con `Read` con `offset`/`limit`. Suficiente contexto para entender ~3 secciones MARK por chunk.
2. **Lee el archivo target `nl.lproj/Localizable.strings` actual** (rule-based v0) en chunks similares para conocer el old_string exacto de cada Edit.
3. **Aplica Edits grandes** que cubran ~50–150 keys por call (una sección MARK completa o varias adyacentes). Edits pequeños (<30 keys) consumen contexto sin acelerar.
4. **Recorre las ~91 secciones MARK incremental** desde top a bottom.
5. **Después de cada ~5 Edits**, verifica `grep -c '^"' nl.lproj/Localizable.strings` — debe seguir devolviendo `3041`. Si baja, has roto una key.
6. **Aplica Edits en paralelo** cuando son independientes (diferentes secciones MARK). Acelera ~3x.

Total esperado: ~17–20 Edits grandes para los 3,041 keys. Sesión completa: 30–60 minutos.

## Reglas estrictas (no negociables)

1. **Preserva las KEYS exactamente** — solo traducir el VALUE entre comillas después del `=`. Las keys son identificadores (e.g. `"panel.accounts"`) y NO se traducen jamás.
2. **Preserva los placeholders** — `%@`, `%d`, `%lld`, `%1$@`, `%2$d`, `%@%%`, `\n`, `\"` deben aparecer en el mismo orden y count en la traducción.
3. **Preserva los comentarios** (`/* ... */`, `// MARK:`) y líneas vacías intactas.
4. **Mantén el formato** `"key" = "value";` con punto y coma final.
5. **Yala** como nombre del producto NUNCA se traduce.
6. **Duplicados pre-existentes**: si una key aparece 2 veces en en.lproj, mantén 2 ocurrencias en nl.lproj (Apple toma el último valor).

## Tono y estilo (BRAND-VOICE NL)

- **Pronombre informal `je`/`jou`/`jouw`** — NO usar `u` formal. Yala es app personal, conversacional.
- Tono cercano, amigable, motivador (como "un amigo financiero que sabe de finanzas").
- **Nunca regañar**. "Has gastado demasiado" → "Je hebt je budget bereikt — laten we kijken hoe we dit aanpassen?"
- Frases motivacionales positivas. Celebrar logros con energía moderada.
- Emojis si aparecen en el original — preservarlos.
- Términos profesionales pero claros (no jerga bancaria opaca).

## Glosario financiero NL canónico (usar consistentemente)

| EN | NL |
|---|---|
| Account / Accounts | Rekening / Rekeningen |
| Record / Records | Boeking / Boekingen |
| Expense / Expenses | Uitgave / Uitgaven |
| Income | Inkomsten |
| Budget / Budgets | Budget / Budgetten |
| Category / Subcategory | Categorie / Subcategorie |
| Tag / Tags | Label / Labels |
| Amount | Bedrag |
| Date | Datum |
| Transaction / Transactions | Transactie / Transacties |
| Scheduled payment | Geplande betaling |
| Group / Members | Groep / Leden |
| Total | Totaal |
| Balance | Saldo |
| Currency | Valuta |
| Receipt | Bonnetje |
| Subscription | Abonnement |
| Settings | Instellingen |
| Profile | Profiel |
| Available | Beschikbaar |
| Spent | Uitgegeven |
| Remaining | Resterend |
| Welcome | Welkom |
| Today / Yesterday | Vandaag / Gisteren |
| Month / Year / Week / Day | Maand / Jaar / Week / Dag |
| Save / Delete / Edit | Opslaan / Verwijderen / Bewerken |
| Cancel / Add / Done | Annuleren / Toevoegen / Klaar |
| Search / Filter | Zoeken / Filteren |
| Free / Pro | Gratis / Pro |

## Notas técnicas específicas a holandés

- **Compound words**: el holandés genera palabras largas (`bankrekening`, `uitgavencategorieën`, `topcategorieën`). Traducirlos correctamente aunque queden largos.
- **Conjunciones**: "and" → "en", "or" → "of", "the" → "de"/"het" según contexto, "of" → "van", "to" → "naar"/"voor", "in" → "in", "for" → "voor", "with" → "met".
- **Imperativos en mensajes**: "Tap to..." → "Tik om...", "Scroll to..." → "Scroll om...".
- **Frases motivacionales** con naturalidad nativa, no literal: "Way to go!" → "Goed bezig!", "You've got this!" → "Jij kunt dit!", "Crushing it!" → "Je doet het geweldig!".
- **Currency plurals en NL son singulares con números**: "5 dollar", "100 euro" (no "dollars/euros").

## ⚠️ Falsos positivos en detección de "residuos"

`naar` (NL para "to"), `even` (NL para "a moment"), `in/of/voor/met/van` son palabras válidas en NL que coinciden con inglés. **NO uses grep de "palabras inglesas" como heurística de residuos** — da muchos falsos positivos.

Si necesitas detectar residuos, busca patrones del rule-based v0 anterior:
```bash
# Patrones rule-based reales (mezcla EN/NL):
grep -nE '" = "[^"]*\bgeen [a-z]+ [a-z]+ed\b' file  # "geen X-ed" pattern
grep -nE '" = "[^"]*\bje can [a-z]+\b' file          # "je can X" mid-sentence
```

## Glosario de keys complejas (referencias)

- `panel.health.total.headline.high` = "You're crushing it!" → **"Je doet het geweldig!"**
- `panel.health.activity.headline.low` = "A few minutes a day works wonders" → **"Een paar minuten per dag doen wonderen"**
- `cashFlowPlan.commentNegative` = "Starting in %@ your balance goes negative — check if you can adjust something" → **"Vanaf %@ wordt je saldo negatief — kun je iets aanpassen?"**
- `subscription.legalFooter` (largo, lenguaje legal) — adaptar al fraseo legal NL natural, no traducción literal del inglés.
- `weekday.short.*` — abreviaturas Z/M/D/W/D/V/Z (zo, ma, di, wo, do, vr, za).

## Validación final (6 checks obligatorios)

```bash
cd /Users/jur/Yala

# 1. Paridad de keys (esperado: en=3010 nl=3010 missing=0 extra=0 — 3010 NO 3041)
python3 - <<'PY'
import re
def keys(p):
    s = set()
    with open(p) as f:
        for line in f:
            m = re.match(r'^"([^"]+)"\s*=', line)
            if m: s.add(m.group(1))
    return s
ref = keys("Yala/Resources/en.lproj/Localizable.strings")
nl = keys("Yala/Resources/nl.lproj/Localizable.strings")
print(f"en={len(ref)} nl={len(nl)} missing={len(ref-nl)} extra={len(nl-ref)}")
PY

# 2. Placeholders preservados (esperado: placeholder_mismatches=0)
python3 - <<'PY'
import re
def parse(p):
    items = {}
    with open(p) as f:
        for line in f:
            m = re.match(r'^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";', line)
            if m: items[m.group(1)] = m.group(2)
    return items
en = parse("Yala/Resources/en.lproj/Localizable.strings")
nl = parse("Yala/Resources/nl.lproj/Localizable.strings")
ph = re.compile(r'%(?:\d+\$)?[@dlf]|%%')
mismatches = []
for k in en:
    if k not in nl: continue
    if sorted(ph.findall(en[k])) != sorted(ph.findall(nl[k])):
        mismatches.append((k, en[k], nl[k]))
print(f"placeholder_mismatches={len(mismatches)}")
for m in mismatches[:10]: print(m)
PY

# 3. NEEDS_TRANSLATION marker (esperado: 0)
grep -c '\[NEEDS_TRANSLATION\]' Yala/Resources/nl.lproj/Localizable.strings

# 4. Yala preservado (esperado: ≥80, idealmente ~108)
grep -c '"Yala"' Yala/Resources/nl.lproj/Localizable.strings

# 5. Duplicados consistentes con reference (esperado: vacío)
diff \
  <(grep -E '^"' Yala/Resources/en.lproj/Localizable.strings | awk -F'"' '{print $2}' | sort | uniq -d) \
  <(grep -E '^"' Yala/Resources/nl.lproj/Localizable.strings | awk -F'"' '{print $2}' | sort | uniq -d)

# 6. Line count idéntico al reference (esperado: ambos 3581)
wc -l Yala/Resources/en.lproj/Localizable.strings Yala/Resources/nl.lproj/Localizable.strings
```

Repetir validaciones 1–4 para `YalaWidgets/Resources/nl.lproj/Localizable.strings` (ajustando paths y esperando 115 keys).

## Validación con tests (OBLIGATORIO antes de reportar)

```bash
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests \
  -only-testing:YalaTests/StringsdictParityTests \
  -only-testing:YalaTests/BundleLocaleDriftTests 2>&1 | tail -3
```

Debe imprimir `** TEST SUCCEEDED **`.

## Commit message sugerido

```
feat(l10n): traducción nl real keys-por-keys reemplaza rule-based v0

Reemplaza el archivo nl.lproj generado en M12 (rule-based con glossary
de ~80 patrones EN→NL) con traducción de calidad keys-por-keys
respetando BRAND-VOICE (tono je/jij informal, no regañar, motivacional)
+ glosario financiero canónico.

Cambios:
- Yala/Resources/nl.lproj/Localizable.strings: 3,041 keys traducidas
  con calidad de producción
- YalaWidgets/Resources/nl.lproj/Localizable.strings: 115 keys idem
- Localizable.stringsdict y InfoPlist.strings sin cambios (ya tenían
  calidad real desde M12)

Tests verde — paridad completa con en.lproj reference, sin orphans,
placeholders consistentes, 31 duplicados pre-existentes preservados.
```

## Reporta al final

- Total keys traducidas: 3,041 (main) + 115 (widgets) = 3,156.
- Output del script de paridad (`en=3010 nl=3010 missing=0 extra=0`).
- Output del script de placeholders (`placeholder_mismatches=0`).
- Confirmación: NEEDS_TRANSLATION = 0, Yala preservado ≥80 ocurrencias.
- Lista breve (≤10) de keys complejas con las que tuviste duda.
- Output de `xcodebuild test` (`** TEST SUCCEEDED **`).

NO commitees automáticamente — espera la aprobación del user.

--- END PROMPT ---
