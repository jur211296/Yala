# Prompt: traducir Yala completo a pl (Polaco)

> Copia todo el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` y pégalo en una sesión nueva de Claude Code dentro del repo `/Users/jur/Yala`.

--- BEGIN PROMPT ---

Tu tarea es traducir el archivo `Localizable.strings` de Yala (app iOS de finanzas personales) del **inglés al polaco (pl-PL)** con calidad de producción. Reemplazar la traducción rule-based v0 actual de `pl.lproj` con traducciones reales keys-por-keys.

## Archivos

**Reference (NO tocar):** `/Users/jur/Yala/Yala/Resources/en.lproj/Localizable.strings` — 3,041 keys, ~3,580 líneas, calidad nativa.

**A reemplazar:**
1. `/Users/jur/Yala/Yala/Resources/pl.lproj/Localizable.strings`
2. `/Users/jur/Yala/YalaWidgets/Resources/pl.lproj/Localizable.strings` (~80 keys)

**NO tocar:**
- `pl.lproj/Localizable.stringsdict` (plurales 4-reglas one/few/many/other ya traducidos correctamente — único locale con esas 4 reglas)
- `pl.lproj/InfoPlist.strings` (ya traducido)

## Approach técnico (CRÍTICO — evita stalls)

NO uses un `Write` enorme con todo el archivo. Eso falla por watchdog. En su lugar:

1. Lee `en.lproj/Localizable.strings` en chunks de ~500 líneas con `Read` con `offset`/`limit`.
2. Lee el archivo target `pl.lproj/Localizable.strings` actual (rule-based v0) en chunks similares.
3. Para cada chunk, emite **muchas `Edit` calls** que reemplazan secciones de ~10–30 strings cada una.
4. Recorre TODAS las 91 secciones MARK incremental.
5. Al final, valida con el script de paridad.

## Reglas estrictas (no negociables)

1. **Preserva las KEYS exactamente** — solo traducir el VALUE entre comillas después del `=`.
2. **Preserva los placeholders** — `%@`, `%d`, `%lld`, `%1$@`, `%2$d`, `%@%%`, `\n`, `\"` deben aparecer en el mismo orden y count.
3. **Preserva los comentarios** (`/* ... */`) y líneas vacías intactas.
4. **Mantén el formato** `"key" = "value";` con punto y coma final.
5. **Yala** como nombre del producto NUNCA se traduce.
6. **Caracteres polacos correctos** (ą, ć, ę, ł, ń, ó, ś, ź, ż) — usar UTF-8.

## Tono y estilo (BRAND-VOICE PL)

- **Pronombre informal `ty`/`twój`/`twoja`/`twoje`** — NO usar `pan/pani` formal.
- Tono cercano, amigable, motivador.
- **Nunca regañar**. "Has gastado demasiado" → "Osiągnąłeś swój limit — możemy to dostosować?"
- Frases motivacionales positivas, naturales en polaco.
- Emojis si aparecen en el original — preservarlos.

## Género verbal (CRÍTICO en polaco)

Polaco usa formas verbales con género (masc/fem). Para 2da persona en copy genérico:
- **Prefiere formas neutras o reformulaciones impersonales** cuando sea posible.
- Si necesitas concreto, **usa masculino por defecto** (convención iOS).
- Mejor: "Twoje wydatki są wyższe" (neutro) que "Wydałeś więcej" (masc explícito).
- Para imperativos (Save → Zapisz, Cancel → Anuluj) no hay problema de género.

## Glosario financiero PL canónico

| EN | PL |
|---|---|
| Account | Konto |
| Accounts | Konta |
| Record / records | Wpis / Wpisy |
| Expense | Wydatek |
| Expenses | Wydatki |
| Income | Dochód |
| Budget | Budżet |
| Category | Kategoria |
| Subcategory | Podkategoria |
| Tag / Tags | Etykieta / Etykiety |
| Amount | Kwota |
| Date | Data |
| Transaction / Transactions | Transakcja / Transakcje |
| Scheduled payment | Zaplanowana płatność |
| Group / Groups | Grupa / Grupy |
| Member / Members | Członek / Członkowie |
| Total | Razem (o Łącznie según contexto) |
| Balance | Saldo |
| Currency | Waluta |
| Receipt | Paragon |
| Subscription | Subskrypcja |
| Settings | Ustawienia |
| Profile | Profil |
| Available | Dostępne |
| Spent | Wydano |
| Remaining | Pozostało |
| Welcome | Witaj |
| Today / Yesterday | Dzisiaj / Wczoraj |
| Month / Year / Week / Day | Miesiąc / Rok / Tydzień / Dzień |
| Save | Zapisz |
| Delete | Usuń |
| Edit | Edytuj |
| Cancel | Anuluj |
| Add | Dodaj |
| Done | Gotowe |
| Search | Szukaj |
| Filter | Filtruj |
| Free / Pro | Darmowy / Pro |

## Notas técnicas específicas a polaco

- **Casos polacos** (mianownik/dopełniacz/biernik/etc.): aplica correctamente según contexto sintáctico.
- **Imperativos**: "Tap to..." → "Stuknij, aby...", "Scroll to..." → "Przewiń, aby...".
- **Frases motivacionales** naturales: "Way to go!" → "Świetnie!", "You've got this!" → "Dasz radę!".

## Glosario de keys complejas (referencias)

- `panel.health.total.headline.high` = "You're crushing it!" → **"Świetnie sobie radzisz!"** (neutro)
- `panel.health.activity.headline.low` = "A few minutes a day works wonders" → **"Kilka minut dziennie czyni cuda"**
- `cashFlowPlan.commentNegative` = "Starting in %@ your balance goes negative — check if you can adjust something" → **"Od %@ Twoje saldo będzie ujemne — sprawdź, czy możesz coś dostosować"**

## Validación final

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
pl = keys("Yala/Resources/pl.lproj/Localizable.strings")
print(f"en={len(ref)} pl={len(pl)} missing={len(ref-pl)} extra={len(pl-ref)}")
PY
```

Debe imprimir `missing=0 extra=0`. Luego:

```bash
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests 2>&1 | tail -3
```

Debe imprimir `** TEST SUCCEEDED **`.

## Commit message sugerido

```
feat(l10n): traducción pl real keys-por-keys reemplaza rule-based v0

Reemplaza el archivo pl.lproj generado en M13 con traducción de calidad
keys-por-keys respetando BRAND-VOICE (tono ty informal, neutral en
género verbal, no regañar) + glosario financiero canónico polaco.

Caracteres polacos especiales (ą, ć, ę, ł, ń, ó, ś, ź, ż) preservados.
Género verbal manejado con preferencia neutra (reformulaciones
impersonales o masculino por defecto cuando concreto necesario).

Cambios:
- Yala/Resources/pl.lproj/Localizable.strings: 3,041 keys
- YalaWidgets/Resources/pl.lproj/Localizable.strings: ~80 keys
- stringsdict y InfoPlist.strings sin cambios (ya tenían calidad real
  desde M13, incluyendo las 4 reglas plurales one/few/many/other)

Tests verde.
```

## Reporta al final

- Cuántas keys traduciste.
- Cualquier key compleja con duda (≤10).
- Confirma que Yala nunca fue traducido.
- Confirma placeholders preservados.
- Confirma manejo de género verbal consistente.

NO commitees automáticamente — espera aprobación del user.

--- END PROMPT ---
