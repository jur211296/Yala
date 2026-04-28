# Prompt: traducir Yala completo a ja (Japonés)

> Copia todo el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` y pégalo en una sesión nueva de Claude Code dentro del repo `/Users/jur/Yala`.

--- BEGIN PROMPT ---

Tu tarea es traducir el archivo `Localizable.strings` de Yala (app iOS de finanzas personales) del **inglés al japonés (ja-JP)** con calidad de producción. Reemplazar la traducción rule-based v0 actual de `ja.lproj` con traducciones reales keys-por-keys.

## Archivos

**Reference (NO tocar):** `/Users/jur/Yala/Yala/Resources/en.lproj/Localizable.strings` — 3,041 keys, ~3,580 líneas, calidad nativa.

**A reemplazar:**
1. `/Users/jur/Yala/Yala/Resources/ja.lproj/Localizable.strings`
2. `/Users/jur/Yala/YalaWidgets/Resources/ja.lproj/Localizable.strings` (~80 keys)

**NO tocar:**
- `ja.lproj/Localizable.stringsdict` (regla `other` única ya traducida correctamente)
- `ja.lproj/InfoPlist.strings` (ya traducido)

## Approach técnico (CRÍTICO — evita stalls)

NO uses un `Write` enorme con todo el archivo. Eso falla por watchdog. En su lugar:

1. Lee `en.lproj/Localizable.strings` en chunks de ~500 líneas con `Read` con `offset`/`limit`.
2. Lee el archivo target `ja.lproj/Localizable.strings` actual (rule-based v0) en chunks similares.
3. Para cada chunk, emite **muchas `Edit` calls** que reemplazan secciones de ~10–30 strings cada una.
4. Recorre TODAS las 91 secciones MARK incremental.
5. Al final, valida con el script de paridad.

## Reglas estrictas (no negociables)

1. **Preserva las KEYS exactamente** — solo traducir el VALUE entre comillas.
2. **Preserva los placeholders** — `%@`, `%d`, `%lld`, `%1$@`, `%2$d`, `%@%%`, `\n`, `\"` en el mismo orden y count. **CRÍTICO en japonés**: el orden puede diferir del inglés, usa `%1$@` `%2$d` cuando necesites reordenar.
3. **Preserva los comentarios** (`/* ... */`) y líneas vacías intactas.
4. **Mantén el formato** `"key" = "value";` con punto y coma final.
5. **Yala** como nombre del producto NUNCA se traduce — queda en alfabeto latino.

## Tono y estilo (BRAND-VOICE adaptado a japonés)

- **Forma です/ます (cortés casual)** — NO usar 敬語 (keigo formal extremo, e.g. ございます), NO usar plain form (だね style demasiado familiar).
- **Evita pronombres explícitos de 2ª persona** — en japonés natural es raro decir あなたは. En lugar de "Has gastado..." → "%@円使いました" o reformular: "今月の支出は…".
- Tono cercano-cortés, neutral pero amigable.
- **Nunca regañar**. Reformular constructivamente: "予算を超えました" → "予算に達しました — 調整しましょうか？".
- Frases motivacionales con energía moderada.

## Glosario financiero JA canónico

| EN | JA |
|---|---|
| Account | 口座 |
| Accounts | 口座 (sin diferencia plural) |
| Record / records | 記録 |
| Expense / Expenses | 支出 |
| Income | 収入 |
| Budget | 予算 |
| Category | カテゴリー |
| Subcategory | サブカテゴリー |
| Tag | タグ |
| Amount | 金額 |
| Date | 日付 |
| Transaction | 取引 |
| Scheduled payment | 予定支払い |
| Group / Member | グループ / メンバー |
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
| Save | 保存 |
| Delete | 削除 |
| Edit | 編集 |
| Cancel | キャンセル |
| Add | 追加 |
| Done | 完了 |
| Search | 検索 |
| Filter | フィルター |
| Free / Pro | 無料 / Pro |

## Notas técnicas específicas a japonés

- **Counter words** apropiados según contexto:
  - 件 (ken) para registros/transacciones (e.g. 5件の取引)
  - 個 (ko) para items genéricos
  - 日 (nichi) para días
  - 枚 (mai) para tarjetas
  - 回 (kai) para veces/intentos
- **Espacios entre números y kanji**: convención iOS — "5 件" no "5件" (espacio antes del counter).
- **Imperativos**: "Tap to..." → "タップして..." o "...するにはタップ", "Scroll to..." → "スクロールして...".
- **Frases motivacionales**: "Way to go!" → "順調です！", "You've got this!" → "頑張ってください！".

## Glosario de keys complejas (referencias)

- `panel.health.total.headline.high` = "You're crushing it!" → **"絶好調です！"**
- `panel.health.activity.headline.low` = "A few minutes a day works wonders" → **"1日数分でも、大きな変化が生まれます"**
- `cashFlowPlan.commentNegative` = "Starting in %@ your balance goes negative — check if you can adjust something" → **"%@から残高がマイナスになります — 何か調整できないか確認してください"**

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
ja = keys("Yala/Resources/ja.lproj/Localizable.strings")
print(f"en={len(ref)} ja={len(ja)} missing={len(ref-ja)} extra={len(ja-ref)}")
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
feat(l10n): traducción ja real keys-por-keys reemplaza rule-based v0

Reemplaza el archivo ja.lproj generado en M14 con traducción de calidad
keys-por-keys respetando BRAND-VOICE adaptado al japonés (です/ます
cortés casual, sin keigo extremo, sin pronombres 2ª pers explícitos)
+ glosario financiero canónico.

Counter words usados correctamente: 件 (registros/transacciones),
日 (días), 枚 (tarjetas), 回 (veces). Espacios entre números y kanji
según convención iOS.

Cambios:
- Yala/Resources/ja.lproj/Localizable.strings: 3,041 keys
- YalaWidgets/Resources/ja.lproj/Localizable.strings: ~80 keys
- stringsdict (regla `other` única) y InfoPlist.strings sin cambios
  (calidad real desde M14)

Tests verde.
```

## Reporta al final

- Cuántas keys traduciste.
- Cualquier key compleja con duda (≤10).
- Confirma que Yala nunca fue traducido.
- Confirma placeholders preservados (especialmente reordenados con %1$@/%2$@).
- Confirma tono です/ます consistente, sin keigo extremo.

NO commitees automáticamente — espera aprobación del user.

--- END PROMPT ---
