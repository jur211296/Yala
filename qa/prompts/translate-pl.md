# Prompt: traducir Yala completo a pl (Polaco)

> Copia todo el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` y pégalo en una sesión nueva de Claude Code dentro del repo `/Users/jur/Yala`.

--- BEGIN PROMPT ---

Tu tarea es traducir el archivo `Localizable.strings` de Yala (app iOS de finanzas personales) del **inglés al polaco (pl-PL)** con calidad de producción. Reemplazar la traducción rule-based v0 actual de `pl.lproj` con traducciones reales keys-por-keys.

## Archivos

**Reference (NO tocar):** `/Users/jur/Yala/Yala/Resources/en.lproj/Localizable.strings` — 3,041 keys, ~3,580 líneas, calidad nativa.

**A reemplazar:**
1. `/Users/jur/Yala/Yala/Resources/pl.lproj/Localizable.strings` (3,041 keys)
2. `/Users/jur/Yala/YalaWidgets/Resources/pl.lproj/Localizable.strings` (115 keys)

**NO tocar:**
- `pl.lproj/Localizable.stringsdict` (plurales 4-reglas one/few/many/other ya traducidos correctamente — **único locale con esas 4 reglas plurales**, no las pierdas)
- `pl.lproj/InfoPlist.strings` (ya traducido)

## Pre-existencias importantes (NO son bugs)

- **El reference `en.lproj` tiene 31 keys duplicadas declaradas dos veces.** Apple usa el último valor cargado. Tu archivo `pl.lproj` debe **preservar las mismas duplicaciones** — no consolidar a una sola.
- **El parser de validación reporta 3010 unique keys**, no 3041 (porque dedupe). Esto es correcto. Esperarás output `en=3010 pl=3010 missing=0 extra=0`.
- **Hay ~30 keys "huérfanas"** declaradas inline entre secciones MARK. Asegúrate de cubrirlas — un Edit por sección MARK aislada las perdería.

## Approach técnico (CRÍTICO — basado en sesión real exitosa nl-NL)

**NO uses un `Write` enorme con todo el archivo.** El archivo en.lproj son ~290KB (~70K tokens) — el modelo no puede outputear eso en una sola respuesta.

**Approach que funciona**:

1. **Lee `en.lproj/Localizable.strings` en chunks de 500–700 líneas** con `Read` con `offset`/`limit`.
2. **Lee el archivo target `pl.lproj/Localizable.strings` actual** (rule-based v0) en chunks similares.
3. **Aplica Edits grandes** que cubran ~50–150 keys por call (una sección MARK completa o varias adyacentes). Edits pequeños (<30 keys) consumen contexto sin acelerar.
4. **Recorre las ~91 secciones MARK incremental** desde top a bottom.
5. **Después de cada ~5 Edits**, verifica `grep -c '^"' pl.lproj/Localizable.strings` — debe seguir devolviendo `3041`. Si baja, has roto una key.
6. **Aplica Edits en paralelo** cuando son independientes (diferentes secciones MARK).

Total esperado: ~17–20 Edits grandes. Sesión completa: 30–60 minutos.

## Reglas estrictas (no negociables)

1. **Preserva las KEYS exactamente** — solo traducir el VALUE entre comillas después del `=`.
2. **Preserva los placeholders** — `%@`, `%d`, `%lld`, `%1$@`, `%2$d`, `%@%%`, `\n`, `\"` en el mismo orden y count.
3. **Preserva los comentarios** (`/* ... */`, `// MARK:`) y líneas vacías intactas.
4. **Mantén el formato** `"key" = "value";` con punto y coma final.
5. **Yala** como nombre del producto NUNCA se traduce.
6. **Caracteres polacos correctos** (ą, ć, ę, ł, ń, ó, ś, ź, ż) — usar UTF-8.
7. **Duplicados pre-existentes**: si una key aparece 2 veces en en.lproj, mantén 2 ocurrencias en pl.lproj con valores consistentes.

## Tono y estilo (BRAND-VOICE PL)

- **Pronombre informal `ty`/`twój`/`twoja`/`twoje`** — NO usar `pan/pani` formal. Yala es app personal moderna.
- Tono cercano, amigable, motivador.
- **Nunca regañar**. "Has gastado demasiado" → "Osiągnąłeś swój limit — możemy to dostosować?"
- Frases motivacionales positivas, naturales en polaco.
- Emojis si aparecen en el original — preservarlos.

## Género verbal (CRÍTICO en polaco)

Polaco usa formas verbales con género (masc/fem/neutro). Para 2da persona en copy genérico:

- **Prefiere formas neutras o reformulaciones impersonales** cuando sea posible.
  - "Twoje wydatki są wyższe" (neutro) ✅ mejor que "Wydałeś więcej" (masc explícito)
  - "Brak danych do wyświetlenia" (impersonal) ✅ mejor que "Nie masz danych" (con género)
- Si necesitas concreto, **usa masculino por defecto** (convención iOS Apple).
- Para imperativos (Save → Zapisz, Cancel → Anuluj) no hay problema de género.
- **Reformula con sustantivos** cuando ayuda: "Twoja aktywność" en vez de "Jesteś aktywny/a".

## Casos polacos (declinaciones)

Polaco flexiona sustantivos en 7 casos. Aplica el caso correcto según contexto sintáctico:

- Mianownik (nominative): sujeto — "Konto jest aktywne"
- Dopełniacz (genitive): después de negación, cantidades — "5 wydatków" (no "5 wydatki"), "brak konta" (no "brak konto")
- Biernik (accusative): objeto directo — "Dodaj wydatek"
- Narzędnik (instrumental): "Z kontem", "Płać kartą"
- Miejscownik (locative): después de "w/o/przy" — "W tym miesiącu"

Errores comunes a evitar:
- ❌ `5 wydatki` → ✅ `5 wydatków` (genitive plural after números 5+)
- ❌ `brak transakcje` → ✅ `brak transakcji` (genitive after "brak")
- ❌ `do konto` → ✅ `do konta` (genitive after "do")

## Glosario financiero PL canónico

| EN | PL |
|---|---|
| Account / Accounts | Konto / Konta |
| Record / Records | Wpis / Wpisy |
| Expense / Expenses | Wydatek / Wydatki |
| Income | Dochód |
| Budget / Budgets | Budżet / Budżety |
| Category / Subcategory | Kategoria / Podkategoria |
| Tag / Tags | Etykieta / Etykiety |
| Amount | Kwota |
| Date | Data |
| Transaction / Transactions | Transakcja / Transakcje |
| Scheduled payment | Zaplanowana płatność |
| Group / Members | Grupa / Członkowie |
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
| Save / Delete / Edit | Zapisz / Usuń / Edytuj |
| Cancel / Add / Done | Anuluj / Dodaj / Gotowe |
| Search / Filter | Szukaj / Filtruj |
| Free / Pro | Darmowy / Pro |

## Notas técnicas específicas a polaco

- **Polish flexiona, no compone**: "podkategorie wydatków" no "wydatkypodkategorie".
- **Imperativos**: "Tap to..." → "Stuknij, aby...", "Scroll to..." → "Przewiń, aby...".
- **Frases motivacionales** naturales: "Way to go!" → "Świetnie!", "You've got this!" → "Dasz radę!", "Crushing it!" → "Świetnie sobie radzisz!".
- **Currency plurals**: usa formas declinadas — "5 złotych" (no "5 złoty"), "10 dolarów" (no "10 dolar"). Aplica genitive plural.
- **Días de semana en minúsculas** dentro de oraciones (poniedziałek, wtorek...). Solo capitalizar al inicio.

## Glosario de keys complejas (referencias)

- `panel.health.total.headline.high` = "You're crushing it!" → **"Świetnie sobie radzisz!"** (neutro, sin género)
- `panel.health.activity.headline.low` = "A few minutes a day works wonders" → **"Kilka minut dziennie czyni cuda"**
- `cashFlowPlan.commentNegative` = "Starting in %@ your balance goes negative — check if you can adjust something" → **"Od %@ Twoje saldo będzie ujemne — sprawdź, czy możesz coś dostosować"**
- `weekday.short.*` — abreviaturas N/Pn/Wt/Śr/Cz/Pt/So (siguiendo convención polaca; verificar si Apple iOS prefiere algo distinto)

## ⚠️ Falsos positivos en detección de "residuos"

`do/i/w/z/za/o/na/po` son preposiciones y conjunciones polacas comunes. **NO uses grep de "palabras inglesas" como heurística de residuos** — busca patrones específicos del rule-based v0.

## Validación final (6 checks obligatorios)

```bash
cd /Users/jur/Yala

# 1. Paridad de keys (esperado: en=3010 pl=3010 missing=0 extra=0)
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

# 2. Placeholders preservados
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
pl = parse("Yala/Resources/pl.lproj/Localizable.strings")
ph = re.compile(r'%(?:\d+\$)?[@dlf]|%%')
mismatches = []
for k in en:
    if k not in pl: continue
    if sorted(ph.findall(en[k])) != sorted(ph.findall(pl[k])):
        mismatches.append((k, en[k], pl[k]))
print(f"placeholder_mismatches={len(mismatches)}")
for m in mismatches[:10]: print(m)
PY

# 3. NEEDS_TRANSLATION marker (esperado: 0)
grep -c '\[NEEDS_TRANSLATION\]' Yala/Resources/pl.lproj/Localizable.strings

# 4. Yala preservado (esperado: ≥80)
grep -c '"Yala"' Yala/Resources/pl.lproj/Localizable.strings

# 5. Duplicados consistentes con reference (esperado: vacío)
diff \
  <(grep -E '^"' Yala/Resources/en.lproj/Localizable.strings | awk -F'"' '{print $2}' | sort | uniq -d) \
  <(grep -E '^"' Yala/Resources/pl.lproj/Localizable.strings | awk -F'"' '{print $2}' | sort | uniq -d)

# 6. Caracteres polacos presentes (esperado: >100 — confirma encoding UTF-8 correcto)
grep -cE '[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]' Yala/Resources/pl.lproj/Localizable.strings
```

Repetir validaciones 1–4 para `YalaWidgets/Resources/pl.lproj/Localizable.strings` (ajustando paths y esperando 115 keys).

## Validación con tests (OBLIGATORIO antes de reportar)

```bash
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests \
  -only-testing:YalaTests/StringsdictParityTests \
  -only-testing:YalaTests/BundleLocaleDriftTests 2>&1 | tail -3
```

Debe imprimir `** TEST SUCCEEDED **`. **CRÍTICO para PL**: `StringsdictParityTests` valida las 4 reglas plurales (one/few/many/other) — confirma que el stringsdict no se haya tocado.

## Commit message sugerido

```
feat(l10n): traducción pl real keys-por-keys reemplaza rule-based v0

Reemplaza el archivo pl.lproj generado en M13 con traducción de calidad
keys-por-keys respetando BRAND-VOICE (tono ty informal, neutral en
género verbal, no regañar) + glosario financiero canónico polaco.

Caracteres polacos especiales (ą, ć, ę, ł, ń, ó, ś, ź, ż) preservados
en UTF-8. Casos polacos (mianownik/dopełniacz/biernik/etc.) aplicados
según contexto sintáctico — números 5+ con genitive plural, "brak X"
con genitive, etc. Género verbal manejado con preferencia neutra
(reformulaciones impersonales o masculino por defecto cuando concreto
necesario).

Cambios:
- Yala/Resources/pl.lproj/Localizable.strings: 3,041 keys
- YalaWidgets/Resources/pl.lproj/Localizable.strings: 115 keys
- stringsdict (4 reglas plurales one/few/many/other) y InfoPlist.strings
  sin cambios (calidad real desde M13)

Tests verde — paridad completa, placeholders consistentes,
StringsdictParityTests confirma 4 reglas plurales intactas, 31
duplicados pre-existentes preservados.
```

## Reporta al final

- Total keys traducidas: 3,041 (main) + 115 (widgets) = 3,156.
- Output del script de paridad.
- Output del script de placeholders.
- Confirmación: NEEDS_TRANSLATION = 0, Yala preservado ≥80, caracteres polacos >100.
- Lista breve (≤10) de keys complejas — especialmente decisiones de **género verbal**.
- Output de `xcodebuild test` confirmando StringsdictParityTests verde (las 4 reglas plurales intactas).

NO commitees automáticamente — espera aprobación del user.

--- END PROMPT ---
