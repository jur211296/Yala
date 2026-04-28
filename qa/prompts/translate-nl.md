# Prompt: traducir Yala completo a nl (Holandés)

> Copia todo el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` y pégalo en una sesión nueva de Claude Code dentro del repo `/Users/jur/Yala`.

--- BEGIN PROMPT ---

Tu tarea es traducir el archivo `Localizable.strings` de Yala (app iOS de finanzas personales) del **inglés al holandés (nl-NL)** con calidad de producción. Reemplazar la traducción rule-based v0 actual de `nl.lproj` con traducciones reales keys-por-keys.

## Archivos

**Reference (NO tocar):** `/Users/jur/Yala/Yala/Resources/en.lproj/Localizable.strings` — 3,041 keys, ~3,580 líneas, calidad nativa.

**A reemplazar:**
1. `/Users/jur/Yala/Yala/Resources/nl.lproj/Localizable.strings`
2. `/Users/jur/Yala/YalaWidgets/Resources/nl.lproj/Localizable.strings` (~80 keys)

**NO tocar:**
- `nl.lproj/Localizable.stringsdict` (plurales ya traducidos correctamente)
- `nl.lproj/InfoPlist.strings` (ya traducido)

## Approach técnico (CRÍTICO — evita stalls)

NO uses un `Write` enorme con todo el archivo. Eso falla por watchdog. En su lugar:

1. Lee `en.lproj/Localizable.strings` en chunks de ~500 líneas con `Read` con `offset`/`limit`.
2. Lee el archivo target `nl.lproj/Localizable.strings` actual (rule-based v0) en chunks similares.
3. Para cada chunk, emite **muchas `Edit` calls** que reemplazan secciones de ~10–30 strings cada una. Cada Edit debe ser pequeño y verificable.
4. Recorre TODAS las 91 secciones MARK del archivo de forma incremental.
5. Al final, valida con el script de paridad (ver "Validación").

**Por qué esto funciona:** distribuye output en docenas de Edit calls pequeñas en lugar de un Write monolítico. Cada Edit se ejecuta en milisegundos.

## Reglas estrictas (no negociables)

1. **Preserva las KEYS exactamente** — solo traducir el VALUE entre comillas después del `=`. Las keys son identificadores (e.g. `"panel.accounts"`) y NO se traducen jamás.
2. **Preserva los placeholders** — `%@`, `%d`, `%lld`, `%1$@`, `%2$d`, `%@%%`, `\n`, `\"` deben aparecer en el mismo orden y count en la traducción.
3. **Preserva los comentarios** (`/* ... */`) y líneas vacías intactas.
4. **Mantén el formato** `"key" = "value";` con punto y coma final.
5. **Yala** como nombre del producto NUNCA se traduce.

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
| Account | Rekening |
| Accounts | Rekeningen |
| Record / records | Boeking / Boekingen |
| Expense | Uitgave |
| Expenses | Uitgaven |
| Income | Inkomsten |
| Budget | Budget |
| Category | Categorie |
| Subcategory | Subcategorie |
| Tag / Tags | Label / Labels |
| Amount | Bedrag |
| Date | Datum |
| Transaction / Transactions | Transactie / Transacties |
| Scheduled payment | Geplande betaling |
| Group / Groups | Groep / Groepen |
| Member / Members | Lid / Leden |
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
| Save | Opslaan |
| Delete | Verwijderen |
| Edit | Bewerken |
| Cancel | Annuleren |
| Add | Toevoegen |
| Done | Klaar |
| Search | Zoeken |
| Filter | Filteren |
| Free / Pro | Gratis / Pro |

## Notas técnicas específicas a holandés

- **Compound words**: el holandés genera palabras largas (`bankrekening`, `uitgavencategorieën`). Traducirlos correctamente aunque queden largos.
- **Conjunciones**: "and" → "en", "or" → "of", "the" → "de"/"het" según contexto, "of" → "van", "to" → "naar"/"voor", "in" → "in", "for" → "voor", "with" → "met".
- **Imperativos en mensajes**: "Tap to..." → "Tik om...", "Scroll to..." → "Scroll om...".
- **Frases motivacionales** con naturalidad nativa, no literal: "Way to go!" → "Goed bezig!", "You've got this!" → "Jij kunt dit!".

## Glosario de keys complejas (referencias)

- `panel.health.total.headline.high` = "You're crushing it!" → **"Je doet het geweldig!"**
- `panel.health.activity.headline.low` = "A few minutes a day works wonders" → **"Een paar minuten per dag doen wonderen"**
- `cashFlowPlan.commentNegative` = "Starting in %@ your balance goes negative — check if you can adjust something" → **"Vanaf %@ wordt je saldo negatief — kun je iets aanpassen?"**

## Validación final

Tras escribir ambos archivos, ejecuta:

```bash
cd /Users/jur/Yala
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
```

Debe imprimir `missing=0 extra=0`.

Después corre tests:

```bash
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests 2>&1 | tail -3
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
- YalaWidgets/Resources/nl.lproj/Localizable.strings: ~80 keys idem
- Localizable.stringsdict y InfoPlist.strings sin cambios (ya tenían
  calidad real desde M12)

Tests verde — paridad completa con en.lproj reference, sin orphans,
placeholders consistentes.
```

## Reporta al final

- Cuántas keys traduciste (debe ser ~3,041 + ~80 widgets = ~3,121 total).
- Cualquier key compleja con la que tuviste duda (lista breve, ≤10).
- Confirma que Yala como nombre nunca fue traducido.
- Confirma que placeholders están preservados en el mismo count.

NO commitees automáticamente — espera la aprobación del user.

--- END PROMPT ---
