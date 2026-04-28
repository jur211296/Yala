# Prompt: traducir Yala completo a zh-Hans (Chino simplificado)

> Copia todo el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` y pégalo en una sesión nueva de Claude Code dentro del repo `/Users/jur/Yala`.

--- BEGIN PROMPT ---

Tu tarea es traducir el archivo `Localizable.strings` de Yala (app iOS de finanzas personales) del **inglés al chino simplificado (zh-Hans)** con calidad de producción. Reemplazar la traducción rule-based v0 actual de `zh-Hans.lproj` con traducciones reales keys-por-keys.

## Archivos

**Reference (NO tocar):** `/Users/jur/Yala/Yala/Resources/en.lproj/Localizable.strings` — 3,041 keys, ~3,580 líneas, calidad nativa.

**A reemplazar:**
1. `/Users/jur/Yala/Yala/Resources/zh-Hans.lproj/Localizable.strings`
2. `/Users/jur/Yala/YalaWidgets/Resources/zh-Hans.lproj/Localizable.strings` (~80 keys)

**NO tocar:**
- `zh-Hans.lproj/Localizable.stringsdict` (regla `other` única ya traducida correctamente)
- `zh-Hans.lproj/InfoPlist.strings` (ya traducido)

## Approach técnico (CRÍTICO — evita stalls)

NO uses un `Write` enorme con todo el archivo. Eso falla por watchdog. En su lugar:

1. Lee `en.lproj/Localizable.strings` en chunks de ~500 líneas con `Read` con `offset`/`limit`.
2. Lee el archivo target `zh-Hans.lproj/Localizable.strings` actual (rule-based v0) en chunks similares.
3. Para cada chunk, emite **muchas `Edit` calls** que reemplazan secciones de ~10–30 strings cada una.
4. Recorre TODAS las 91 secciones MARK incremental.
5. Al final, valida con el script de paridad.

## Reglas estrictas (no negociables)

1. **Preserva las KEYS exactamente** — solo traducir el VALUE entre comillas.
2. **Preserva los placeholders** — `%@`, `%d`, `%lld`, `%1$@`, `%2$d`, `%@%%`, `\n`, `\"` en el mismo orden y count. Usa `%1$@ %2$d` cuando necesites reordenar.
3. **Preserva los comentarios** (`/* ... */`) y líneas vacías intactas.
4. **Mantén el formato** `"key" = "value";` con punto y coma final.
5. **Yala** como nombre del producto NUNCA se traduce — queda en alfabeto latino.
6. **NO usar caracteres tradicionales** (繁體) — solo simplificados (简体).
   - 资产 no 資產, 时间 no 時間, 删除 no 刪除, 个 no 個, 这 no 這.

## Tono y estilo (BRAND-VOICE adaptado a chino simplificado)

- **Pronombre informal `你`** — NO usar `您` formal. Yala es app personal, conversacional, dirigida a usuario individual.
- Tono cercano, amigable, claro. Lenguaje moderno pero no slang.
- **Nunca regañar**. "Has gastado demasiado" → "你已达到预算 — 我们可以调整一下吗？".
- Frases motivacionales con energía moderada.
- Emojis si aparecen en el original — preservarlos.

## Glosario financiero ZH canónico

| EN | ZH-Hans |
|---|---|
| Account | 账户 |
| Accounts | 账户 (sin diferencia plural) |
| Record / records | 记录 |
| Expense / Expenses | 支出 |
| Income | 收入 |
| Budget | 预算 |
| Category | 类别 |
| Subcategory | 子类别 |
| Tag | 标签 |
| Amount | 金额 |
| Date | 日期 |
| Transaction | 交易 |
| Scheduled payment | 计划支付 |
| Group / Member | 群组 / 成员 |
| Total | 总计 |
| Balance | 余额 |
| Currency | 货币 |
| Receipt | 收据 |
| Subscription | 订阅 |
| Settings | 设置 |
| Profile | 个人资料 |
| Available | 可用 |
| Spent | 已支出 |
| Remaining | 剩余 |
| Welcome | 欢迎 |
| Today / Yesterday | 今天 / 昨天 |
| Month / Year / Week / Day | 月 / 年 / 周 / 天 |
| Save | 保存 |
| Delete | 删除 |
| Edit | 编辑 |
| Cancel | 取消 |
| Add | 添加 |
| Done | 完成 |
| Search | 搜索 |
| Filter | 筛选 |
| Free / Pro | 免费 / Pro |

## Notas técnicas específicas a chino simplificado

- **Measure words** (量词) según contexto:
  - 笔 (bǐ) para transacciones/pagos (5 笔交易)
  - 个 (gè) para items genéricos
  - 天 (tiān) para días
  - 张 (zhāng) para tarjetas
  - 项 (xiàng) para ítems de listas
- **Espacios entre números/latín y chino**: convención iOS — "5 笔" no "5笔", "Yala 应用" no "Yala应用".
- **Imperativos**: "Tap to..." → "点击以..." o "...请点击", "Scroll to..." → "滚动以...".
- **Frases motivacionales**: "Way to go!" → "做得好！", "You've got this!" → "你能做到！".

## Glosario de keys complejas (referencias)

- `panel.health.total.headline.high` = "You're crushing it!" → **"你做得太棒了！"**
- `panel.health.activity.headline.low` = "A few minutes a day works wonders" → **"每天几分钟，效果显著"**
- `cashFlowPlan.commentNegative` = "Starting in %@ your balance goes negative — check if you can adjust something" → **"从 %@ 起你的余额将为负 — 看看是否可以调整一些项目"**

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
zh = keys("Yala/Resources/zh-Hans.lproj/Localizable.strings")
print(f"en={len(ref)} zh-Hans={len(zh)} missing={len(ref-zh)} extra={len(zh-ref)}")

# Verifica que NO hay caracteres tradicionales
import re as r2
trad_chars = '個處這那說見間問語讀開時與來樣個會點長聞國學門關買賣'
with open("Yala/Resources/zh-Hans.lproj/Localizable.strings") as f:
    content = f.read()
for c in trad_chars:
    if c in content:
        print(f"⚠️  Encontrado caracter tradicional: {c}")
PY
```

Debe imprimir `missing=0 extra=0` y SIN ningún warning de carácter tradicional.

Luego:

```bash
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests 2>&1 | tail -3
```

Debe imprimir `** TEST SUCCEEDED **`.

## Commit message sugerido

```
feat(l10n): traducción zh-Hans real keys-por-keys reemplaza rule-based v0

Reemplaza el archivo zh-Hans.lproj generado en M15 con traducción de
calidad keys-por-keys respetando BRAND-VOICE adaptado al chino
simplificado (你 cercano, no 您 formal, no regañar, motivacional)
+ glosario financiero canónico.

Measure words usados correctamente: 笔 (transacciones), 天 (días),
张 (tarjetas), 项 (items). Espacios entre números/latín y caracteres
chinos según convención iOS. Solo caracteres simplificados (简体),
ningún tradicional (繁體).

Cambios:
- Yala/Resources/zh-Hans.lproj/Localizable.strings: 3,041 keys
- YalaWidgets/Resources/zh-Hans.lproj/Localizable.strings: ~80 keys
- stringsdict (regla `other` única) y InfoPlist.strings sin cambios
  (calidad real desde M15)

zh-Hant (Taiwan/HK) sigue out of scope — usuarios zh-Hant-TW caerán
a fallback en por decisión documentada en plan original.

Tests verde.
```

## Reporta al final

- Cuántas keys traduciste.
- Cualquier key compleja con duda (≤10).
- Confirma que Yala nunca fue traducido.
- Confirma placeholders preservados.
- Confirma 0 caracteres tradicionales (verificar con grep).

NO commitees automáticamente — espera aprobación del user.

--- END PROMPT ---
