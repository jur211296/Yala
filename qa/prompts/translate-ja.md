# Prompt: traducir Yala completo a ja (Japonés)

> Copia todo el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` y pégalo en una sesión nueva de Claude Code dentro del repo `/Users/jur/Yala`.

--- BEGIN PROMPT ---

Tu tarea es traducir el archivo `Localizable.strings` de Yala (app iOS de finanzas personales) del **inglés al japonés (ja-JP)** con calidad de producción. Reemplazar la traducción rule-based v0 actual de `ja.lproj` con traducciones reales keys-por-keys.

## Archivos

**Reference (NO tocar):** `/Users/jur/Yala/Yala/Resources/en.lproj/Localizable.strings` — 3,041 keys, ~3,580 líneas, calidad nativa.

**A reemplazar:**
1. `/Users/jur/Yala/Yala/Resources/ja.lproj/Localizable.strings` (3,041 keys)
2. `/Users/jur/Yala/YalaWidgets/Resources/ja.lproj/Localizable.strings` (115 keys)

**NO tocar:**
- `ja.lproj/Localizable.stringsdict` (regla `other` única ya traducida correctamente — japonés no diferencia singular/plural, NO añadir reglas one/few/many)
- `ja.lproj/InfoPlist.strings` (ya traducido)

## Pre-existencias importantes (NO son bugs)

- **El reference `en.lproj` tiene 31 keys duplicadas declaradas dos veces.** Apple usa el último valor cargado. Tu archivo `ja.lproj` debe **preservar las mismas duplicaciones**.
- **El parser de validación reporta 3010 unique keys**, no 3041 (porque dedupe). Esperarás `en=3010 ja=3010 missing=0 extra=0`.
- **Hay ~30 keys "huérfanas"** entre secciones MARK. Asegúrate de cubrirlas.

## Approach técnico (CRÍTICO — basado en sesión real exitosa nl-NL)

**NO uses un `Write` enorme.** El archivo es ~290KB. Usa Edits grandes:

1. **Lee `en.lproj/Localizable.strings` en chunks de 500–700 líneas** con `Read` con `offset`/`limit`.
2. **Lee el archivo target `ja.lproj/Localizable.strings` actual** (rule-based v0) en chunks similares.
3. **Aplica Edits grandes** que cubran ~50–150 keys por call.
4. **Recorre las ~91 secciones MARK incremental**.
5. **Después de cada ~5 Edits**, verifica `grep -c '^"' ja.lproj/Localizable.strings` — debe seguir devolviendo `3041`.
6. **Aplica Edits en paralelo** cuando son independientes.

Total esperado: ~17–20 Edits grandes. Sesión completa: 30–60 minutos.

## Reglas estrictas (no negociables)

1. **Preserva las KEYS exactamente** — solo traducir el VALUE.
2. **Preserva los placeholders** — `%@`, `%d`, `%lld`, `%1$@`, `%2$d`, `%@%%`, `\n`, `\"`. **CRÍTICO en japonés**: el orden gramatical puede diferir del inglés. Si reordenas placeholders, **debes usar el formato `%1$@ %2$@` etc** (no `%@ %@` simple). Ejemplo: EN `Owe %@ to %@` → JA `%2$@に%1$@支払い` (orden invertido, pero placeholders preservados).
3. **Preserva los comentarios** (`/* ... */`, `// MARK:`) y líneas vacías intactas.
4. **Mantén el formato** `"key" = "value";` con punto y coma final.
5. **Yala** como nombre del producto NUNCA se traduce — queda en alfabeto latino, no transliterar a katakana (no ヤラ).
6. **Duplicados pre-existentes**: preservar las 2 ocurrencias.

## Tono y estilo (BRAND-VOICE adaptado a japonés)

- **Forma です/ます (cortés casual)** — la convención estándar de apps de consumo modernas. NO usar 敬語 extremo (ございます, いたします), NO usar plain form (だ調 demasiado familiar).
- **Evita pronombres explícitos de 2ª persona** — japonés natural omite el sujeto. NO traducir literalmente "you" como あなた.
  - ❌ "あなたは100ドル使いました"
  - ✅ "100ドル使いました" (sujeto implícito)
  - ✅ "今月の支出は100ドルです" (reformulado)
- Tono cercano-cortés, neutral pero amigable.
- **Nunca regañar**. Reformular constructivamente:
  - ❌ "予算を超えました"
  - ✅ "予算に達しました — 調整しましょうか？"
- Frases motivacionales con energía moderada.

## Botones y labels: usar formas nominalizadas (no verbos)

Para botones cortos y labels, usa la forma **nominal** del verbo, no la conjugada:

| EN button | ❌ Verb form | ✅ Nominal |
|---|---|---|
| Save | 保存する | **保存** |
| Delete | 削除する | **削除** |
| Edit | 編集する | **編集** |
| Add | 追加する | **追加** |
| Cancel | (キャンセルする) | **キャンセル** |
| Done | (完了する) | **完了** |
| Search | 検索する | **検索** |

Para mensajes/oraciones completas, sí conjugar: "保存しました", "削除されました", etc.

## Glosario financiero JA canónico

| EN | JA |
|---|---|
| Account | 口座 |
| Accounts | 口座 (sin diferencia plural) |
| Record / Records | 記録 |
| Expense / Expenses | 支出 |
| Income | 収入 |
| Budget | 予算 |
| Category | カテゴリー (con ー larga, no カテゴリ) |
| Subcategory | サブカテゴリー |
| Tag / Tags | タグ |
| Amount | 金額 |
| Date | 日付 |
| Transaction / Transactions | 取引 |
| Scheduled payment | 予定支払い |
| Group / Members | グループ / メンバー |
| Total | 合計 |
| Balance | 残高 |
| Currency | 通貨 |
| Receipt | レシート |
| Subscription | サブスクリプション |
| Settings | 設定 |
| Profile | プロフィール |
| Available | 利用可能 |
| Spent | 支出済み |
| Remaining | 残り |
| Welcome | ようこそ |
| Today / Yesterday | 今日 / 昨日 |
| Month / Year / Week / Day | 月 / 年 / 週 / 日 |
| Save / Delete / Edit | 保存 / 削除 / 編集 |
| Cancel / Add / Done | キャンセル / 追加 / 完了 |
| Search / Filter | 検索 / フィルター |
| Free / Pro | 無料 / Pro |

## Notas técnicas específicas a japonés

### Counter words (助数詞) por contexto

- 件 (ken) — registros/transacciones genéricas: "5件の取引"
- 個 (ko) — items genéricos: "3個の項目"
- 日 (nichi) — días: "30日"
- 枚 (mai) — tarjetas, billetes: "3枚のカード"
- 回 (kai) — veces, intentos: "5回試した"
- ヶ月 (kagetsu) — meses: "3ヶ月前" (usa ヶ pequeño, no ケ)
- 年 (nen) — años: "1年前"
- つ (tsu) — items abstractos genéricos cuando dudas: "3つの選択肢"

### Espacios y typography

- **NO espacios entre caracteres japoneses**.
- **Espacios entre kanji y números/latín**: convención iOS — "5 件" o "5件" (ambos OK, prefiere sin espacio para counter words; con espacio cuando hay marca como `%@`).
- **Punctuación japonesa**: 「」（ ） 、 。 ！ ？ — NO usar comas/puntos ingleses en oraciones japonesas.
- **Imperativos**: "Tap to..." → "タップして..." o "...するにはタップ", "Scroll to..." → "スクロールして...".
- **Frases motivacionales**: "Way to go!" → "順調です！", "You've got this!" → "頑張ってください！", "Crushing it!" → "絶好調です！".

### Currency plurals

Japonés no pluraliza — "ドル" sirve para 1 y 100:
- "5ドル" (5 dollars)
- "ユーロ", "円", "ペソ" — todos invariables.

## Glosario de keys complejas (referencias)

- `panel.health.total.headline.high` = "You're crushing it!" → **"絶好調です！"**
- `panel.health.activity.headline.low` = "A few minutes a day works wonders" → **"1日数分でも、大きな変化が生まれます"**
- `cashFlowPlan.commentNegative` = "Starting in %@ your balance goes negative — check if you can adjust something" → **"%@から残高がマイナスになります — 何か調整できないか確認してください"**
- `weekday.short.*` — abreviaturas 日/月/火/水/木/金/土 (1 carácter por día — usa kanji estándar de calendario japonés)
- Botones: 保存/削除/編集 (no 保存する/削除する/編集する)

## ⚠️ Riesgo crítico: mojibake (encoding)

Japonés es vulnerable a errores de encoding. Si después de tus Edits ves `?` o cuadrados en el archivo, has roto el UTF-8.

**Verificación post-edit obligatoria**:
```bash
file -I Yala/Resources/ja.lproj/Localizable.strings
# Debe decir: charset=utf-8
```

**Device QA visual obligatorio** (ver sección al final).

## Validación final (7 checks obligatorios)

```bash
cd /Users/jur/Yala

# 1. Paridad de keys (esperado: en=3010 ja=3010 missing=0 extra=0)
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
ja = keys("Yala/Resources/ja.lproj/Localizable.strings")
print(f"en={len(ref)} ja={len(ja)} missing={len(ref-ja)} extra={len(ja-ref)}")
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
ja = parse("Yala/Resources/ja.lproj/Localizable.strings")
ph = re.compile(r'%(?:\d+\$)?[@dlf]|%%')
mismatches = []
for k in en:
    if k not in ja: continue
    if sorted(ph.findall(en[k])) != sorted(ph.findall(ja[k])):
        mismatches.append((k, en[k], ja[k]))
print(f"placeholder_mismatches={len(mismatches)}")
for m in mismatches[:10]: print(m)
PY

# 3. NEEDS_TRANSLATION marker (esperado: 0)
grep -c '\[NEEDS_TRANSLATION\]' Yala/Resources/ja.lproj/Localizable.strings

# 4. Yala preservado en latín (NO transliterado a katakana ヤラ)
grep -c '"Yala"' Yala/Resources/ja.lproj/Localizable.strings  # ≥80
grep -c 'ヤラ' Yala/Resources/ja.lproj/Localizable.strings    # debe ser 0

# 5. Duplicados consistentes con reference
diff \
  <(grep -E '^"' Yala/Resources/en.lproj/Localizable.strings | awk -F'"' '{print $2}' | sort | uniq -d) \
  <(grep -E '^"' Yala/Resources/ja.lproj/Localizable.strings | awk -F'"' '{print $2}' | sort | uniq -d)

# 6. UTF-8 encoding correcto (NO mojibake)
file -I Yala/Resources/ja.lproj/Localizable.strings
# Debe decir: charset=utf-8

# 7. Caracteres japoneses presentes (esperado: >5000)
grep -cE '[ぁ-んァ-ヶ一-龯]' Yala/Resources/ja.lproj/Localizable.strings
```

Repetir validaciones 1–4 y 6 para `YalaWidgets/Resources/ja.lproj/Localizable.strings`.

## Validación con tests (OBLIGATORIO antes de reportar)

```bash
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests \
  -only-testing:YalaTests/StringsdictParityTests \
  -only-testing:YalaTests/BundleLocaleDriftTests 2>&1 | tail -3
```

## Device QA visual (CRÍTICO para japonés — encoding risk)

Para confirmar que los caracteres japoneses se renderizan correctamente (no mojibake):

```bash
# 1. Build Yala Dev con cambios
xcodebuild -scheme "Yala Dev" -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/YalaDevBuild build

# 2. Install
xcrun simctl install booted "/tmp/YalaDevBuild/Build/Products/Debug-Dev-iphonesimulator/Yala.app"

# 3. Setear idioma del simulador a japonés
xcrun simctl spawn booted defaults write com.jurgenschmidt.yala.dev AppleLanguages -array ja
xcrun simctl launch booted com.jurgenschmidt.yala.dev

# 4. Tomar screenshot de Panel + Records + Profile + Statistics
agent-device screenshot /tmp/yala-qa-ja-panel.png
# Verificar: ningún ? ni cuadrado □ en lugar de caracteres
```

Cualquier `?` o cuadrado en el screenshot indica encoding broken — debes arreglarlo antes de reportar.

## Commit message sugerido

```
feat(l10n): traducción ja real keys-por-keys reemplaza rule-based v0

Reemplaza el archivo ja.lproj generado en M14 con traducción de calidad
keys-por-keys respetando BRAND-VOICE adaptado al japonés (です/ます
cortés casual, sin keigo extremo, sin pronombres 2ª pers explícitos
あなた) + glosario financiero canónico.

Counter words usados correctamente: 件 (registros/transacciones),
日 (días), 枚 (tarjetas), 回 (veces), ヶ月 (meses), 年 (años), つ
(items abstractos). Botones en forma nominal (保存/削除/編集 no
保存する) según convención iOS japonesa. Yala preservado en latín
(no transliterado a katakana).

Cambios:
- Yala/Resources/ja.lproj/Localizable.strings: 3,041 keys
- YalaWidgets/Resources/ja.lproj/Localizable.strings: 115 keys
- stringsdict (regla `other` única) y InfoPlist.strings sin cambios
  (calidad real desde M14)

Tests verde + UTF-8 encoding verificado + device QA visual con
screenshots confirmados (ningún mojibake en Panel/Records/Profile/
Statistics). 31 duplicados pre-existentes preservados.
```

## Reporta al final

- Total keys traducidas: 3,041 (main) + 115 (widgets) = 3,156.
- Output del script de paridad y placeholders.
- Confirmación: NEEDS_TRANSLATION = 0, Yala latín preservado, ヤラ = 0.
- Output de `file -I` confirmando charset=utf-8.
- Output de `xcodebuild test` (`** TEST SUCCEEDED **`).
- **Screenshots de device QA visual** (Panel + Records + Profile + Statistics) confirmando renderizado correcto sin mojibake.
- Lista breve (≤10) de keys complejas — especialmente decisiones de **counter word** y **reordenación de placeholders**.

NO commitees automáticamente — espera aprobación del user.

--- END PROMPT ---
