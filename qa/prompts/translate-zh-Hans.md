# Prompt: traducir Yala completo a zh-Hans (Chino simplificado)

> Copia todo el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` y pégalo en una sesión nueva de Claude Code dentro del repo `/Users/jur/Yala`.

--- BEGIN PROMPT ---

Tu tarea es traducir el archivo `Localizable.strings` de Yala (app iOS de finanzas personales) del **inglés al chino simplificado (zh-Hans)** con calidad de producción. Reemplazar la traducción rule-based v0 actual de `zh-Hans.lproj` con traducciones reales keys-por-keys.

## Archivos

**Reference (NO tocar):** `/Users/jur/Yala/Yala/Resources/en.lproj/Localizable.strings` — 3,041 keys, ~3,580 líneas, calidad nativa.

**A reemplazar:**
1. `/Users/jur/Yala/Yala/Resources/zh-Hans.lproj/Localizable.strings` (3,041 keys)
2. `/Users/jur/Yala/YalaWidgets/Resources/zh-Hans.lproj/Localizable.strings` (115 keys)

**NO tocar:**
- `zh-Hans.lproj/Localizable.stringsdict` (regla `other` única ya traducida correctamente — chino no diferencia singular/plural)
- `zh-Hans.lproj/InfoPlist.strings` (ya traducido)

## Pre-existencias importantes (NO son bugs)

- **El reference `en.lproj` tiene 31 keys duplicadas declaradas dos veces.** Apple usa el último valor cargado. Tu archivo `zh-Hans.lproj` debe **preservar las mismas duplicaciones**.
- **El parser de validación reporta 3010 unique keys**, no 3041. Esperarás `en=3010 zh-Hans=3010 missing=0 extra=0`.
- **Hay ~30 keys "huérfanas"** entre secciones MARK. Asegúrate de cubrirlas.

## Approach técnico (CRÍTICO — basado en sesión real exitosa nl-NL)

**NO uses un `Write` enorme.** El archivo es ~290KB. Usa Edits grandes:

1. **Lee `en.lproj/Localizable.strings` en chunks de 500–700 líneas**.
2. **Lee el archivo target `zh-Hans.lproj/Localizable.strings` actual** en chunks similares.
3. **Aplica Edits grandes** que cubran ~50–150 keys por call.
4. **Recorre las ~91 secciones MARK incremental**.
5. **Después de cada ~5 Edits**, verifica `grep -c '^"' zh-Hans.lproj/Localizable.strings` — debe seguir devolviendo `3041`.
6. **Aplica Edits en paralelo** cuando son independientes.

Total esperado: ~17–20 Edits grandes. Sesión completa: 30–60 minutos.

## Reglas estrictas (no negociables)

1. **Preserva las KEYS exactamente** — solo traducir el VALUE.
2. **Preserva los placeholders** — `%@`, `%d`, `%lld`, `%1$@`, `%2$d`, `%@%%`, `\n`, `\"`. Usa `%1$@ %2$d` cuando reordenes (común en zh por estructura S-V-O similar al inglés pero modificadores antes del nombre).
3. **Preserva los comentarios** y líneas vacías intactas.
4. **Mantén el formato** `"key" = "value";` con punto y coma final.
5. **Yala** como nombre del producto NUNCA se traduce — queda en alfabeto latino, no transliterar (no 雅拉, no 亚拉).
6. **Duplicados pre-existentes**: preservar las 2 ocurrencias.
7. **🚨 CARACTERES SIMPLIFICADOS ÚNICAMENTE (简体)** — NUNCA usar tradicionales (繁體):
   - ✅ 资产 ❌ 資產
   - ✅ 时间 ❌ 時間
   - ✅ 删除 ❌ 刪除
   - ✅ 个 ❌ 個
   - ✅ 这 ❌ 這
   - ✅ 们 ❌ 們
   - ✅ 后 ❌ 後
   - ✅ 国 ❌ 國
   - ✅ 学 ❌ 學
   - ✅ 体 ❌ 體
   - ✅ 关 ❌ 關
   - ✅ 买/卖 ❌ 買/賣
   - ✅ 见 ❌ 見

## Tono y estilo (BRAND-VOICE adaptado a chino simplificado)

- **Pronombre informal `你`** — NO usar `您` formal. Yala es app personal, conversacional, dirigida a usuario individual.
- Tono cercano, amigable, claro. Lenguaje moderno pero no slang excesivo.
- **Nunca regañar**. "Has gastado demasiado" → "你已达到预算 — 我们可以调整一下吗？"
- Frases motivacionales con energía moderada.
- Emojis si aparecen en el original — preservarlos.

## Glosario financiero ZH canónico

| EN | ZH-Hans |
|---|---|
| Account | 账户 |
| Accounts | 账户 (sin diferencia plural) |
| Record / Records | 记录 |
| Expense / Expenses | 支出 |
| Income | 收入 |
| Budget | 预算 |
| Category | 类别 |
| Subcategory | 子类别 |
| Tag / Tags | 标签 |
| Amount | 金额 |
| Date | 日期 |
| Transaction | 交易 |
| Scheduled payment | 计划付款 |
| Group / Members | 群组 / 成员 |
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
| Save / Delete / Edit | 保存 / 删除 / 编辑 |
| Cancel / Add / Done | 取消 / 添加 / 完成 |
| Search / Filter | 搜索 / 筛选 |
| Free / Pro | 免费 / Pro |

## Notas técnicas específicas a chino simplificado

### Measure words (量词) según contexto

- 笔 (bǐ) — transacciones/pagos: "5 笔交易"
- 个 (gè) — items genéricos: "3 个项目"
- 天 (tiān) — días: "30 天"
- 张 (zhāng) — tarjetas, hojas: "3 张卡"
- 项 (xiàng) — items de listas formales: "5 项设置"
- 条 (tiáo) — registros, mensajes: "3 条记录"
- 次 (cì) — veces, intentos: "5 次"
- 个月 (gè yuè) — meses: "3 个月" (siempre con 个)

### Espacios y typography

- **NO espacios entre caracteres chinos**: "你的账户" no "你 的 账户".
- **Espacios entre chino y números/latín**: convención iOS Apple — "5 笔" preferred over "5笔", "Yala 应用" preferred over "Yala应用".
- **Espacios entre chino y placeholders %@/%d**: "你有 %d 个新通知" (sí espacios alrededor de %d).
- **Punctuación china OBLIGATORIA** en oraciones chinas:
  - ❌ `, . ! ?` (inglesas) → ✅ `， 。 ！ ？` (chinas)
  - ❌ `"texto"` → ✅ `"texto"` o `『texto』`
  - ❌ `(paréntesis)` → ✅ `（paréntesis）`
- **Imperativos**: "Tap to..." → "点击以..." o "...请点击", "Scroll to..." → "滚动以...".
- **Frases motivacionales**: "Way to go!" → "做得好！", "You've got this!" → "你能做到！", "Crushing it!" → "你做得太棒了！"

### Currency plurals

Chino no pluraliza — "美元" sirve para 1 y 100:
- "5 美元" (5 dollars)
- "100 欧元", "50 元" — todos invariables.

### Días de la semana abreviaturas

- 日/一/二/三/四/五/六 (1 carácter, calendario chino estándar)
- O 周日/周一/周二/周三/周四/周五/周六 (2 caracteres con prefijo 周)

## Glosario de keys complejas (referencias)

- `panel.health.total.headline.high` = "You're crushing it!" → **"你做得太棒了！"**
- `panel.health.activity.headline.low` = "A few minutes a day works wonders" → **"每天几分钟，效果显著"**
- `cashFlowPlan.commentNegative` = "Starting in %@ your balance goes negative — check if you can adjust something" → **"从 %@ 起你的余额将为负 — 看看是否可以调整一些项目"**
- `weekday.short.*` — abreviaturas 日/一/二/三/四/五/六

## ⚠️ Riesgo crítico: caracteres tradicionales y mojibake

zh-Hans es vulnerable a:
1. **Contaminación con caracteres tradicionales** (繁體) si copias de fuentes Taiwan/HK
2. **Mojibake de encoding** si pierdes UTF-8

**Verificación post-edit obligatoria** (ver scripts en validación final).

## Validación final (8 checks obligatorios)

```bash
cd /Users/jur/Yala

# 1. Paridad de keys (esperado: en=3010 zh-Hans=3010 missing=0 extra=0)
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
zh = parse("Yala/Resources/zh-Hans.lproj/Localizable.strings")
ph = re.compile(r'%(?:\d+\$)?[@dlf]|%%')
mismatches = []
for k in en:
    if k not in zh: continue
    if sorted(ph.findall(en[k])) != sorted(ph.findall(zh[k])):
        mismatches.append((k, en[k], zh[k]))
print(f"placeholder_mismatches={len(mismatches)}")
for m in mismatches[:10]: print(m)
PY

# 3. NEEDS_TRANSLATION marker (esperado: 0)
grep -c '\[NEEDS_TRANSLATION\]' Yala/Resources/zh-Hans.lproj/Localizable.strings

# 4. Yala preservado en latín (NO transliterado a 雅拉/亚拉/etc.)
grep -c '"Yala"' Yala/Resources/zh-Hans.lproj/Localizable.strings  # ≥80
grep -E '雅拉|亚拉|耶拉|押拉' Yala/Resources/zh-Hans.lproj/Localizable.strings  # debe estar vacío

# 5. Duplicados consistentes con reference
diff \
  <(grep -E '^"' Yala/Resources/en.lproj/Localizable.strings | awk -F'"' '{print $2}' | sort | uniq -d) \
  <(grep -E '^"' Yala/Resources/zh-Hans.lproj/Localizable.strings | awk -F'"' '{print $2}' | sort | uniq -d)

# 6. UTF-8 encoding correcto (NO mojibake)
file -I Yala/Resources/zh-Hans.lproj/Localizable.strings
# Debe decir: charset=utf-8

# 7. NO caracteres tradicionales (esperado: 0 ocurrencias por cada uno)
python3 - <<'PY'
trad_to_simp = {
    '個': '个', '處': '处', '這': '这', '那': '那(ok)', '說': '说',
    '見': '见', '間': '间', '問': '问', '語': '语', '讀': '读',
    '開': '开', '時': '时', '與': '与', '來': '来', '樣': '样',
    '會': '会', '點': '点', '長': '长', '聞': '闻', '國': '国',
    '學': '学', '門': '门', '關': '关', '買': '买', '賣': '卖',
    '們': '们', '後': '后', '體': '体', '無': '无', '為': '为',
    '對': '对', '應': '应', '從': '从', '當': '当', '經': '经',
    '記': '记', '錄': '录', '類': '类', '別': '别', '預': '预',
    '帳': '账', '戶': '户', '設': '设', '備': '备', '訂': '订',
    '閱': '阅', '貨': '货', '幣': '币', '餘': '余', '額': '额',
    '時': '时', '間': '间', '網': '网', '絡': '络', '請': '请',
    '確': '确', '認': '认', '檔': '档', '導': '导', '齣': '出',
}
found = []
with open("Yala/Resources/zh-Hans.lproj/Localizable.strings") as f:
    content = f.read()
for trad, simp in trad_to_simp.items():
    cnt = content.count(trad)
    if cnt > 0:
        found.append((trad, simp, cnt))
if found:
    print(f"⚠️  Encontrados {len(found)} caracteres tradicionales:")
    for trad, simp, cnt in found:
        print(f"  '{trad}' debería ser '{simp}' (encontrado {cnt}x)")
else:
    print("✅ Sin caracteres tradicionales detectados")
PY

# 8. Caracteres chinos presentes (esperado: >5000)
grep -cE '[一-龯]' Yala/Resources/zh-Hans.lproj/Localizable.strings
```

Repetir validaciones 1–4, 6, 7 para `YalaWidgets/Resources/zh-Hans.lproj/Localizable.strings`.

## Validación con tests (OBLIGATORIO antes de reportar)

```bash
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests \
  -only-testing:YalaTests/StringsdictParityTests \
  -only-testing:YalaTests/BundleLocaleDriftTests 2>&1 | tail -3
```

Debe imprimir `** TEST SUCCEEDED **`.

## Device QA visual (CRÍTICO para chino — encoding + tradicionales risk)

```bash
# 1. Build Yala Dev
xcodebuild -scheme "Yala Dev" -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/YalaDevBuild build

# 2. Install
xcrun simctl install booted "/tmp/YalaDevBuild/Build/Products/Debug-Dev-iphonesimulator/Yala.app"

# 3. Setear idioma del simulador a chino simplificado
xcrun simctl spawn booted defaults write com.jurgenschmidt.yala.dev AppleLanguages -array zh-Hans
xcrun simctl launch booted com.jurgenschmidt.yala.dev

# 4. Tomar screenshots
agent-device screenshot /tmp/yala-qa-zh-panel.png
agent-device screenshot /tmp/yala-qa-zh-records.png
# Verificar visualmente:
# - Ningún ? ni cuadrado □ (mojibake)
# - Ningún caracter tradicional 個/這/說/etc.
# - Espaciado correcto entre chino y números/latín
# - Punctuación china correcta (， 。 ！ ？)
```

## Commit message sugerido

```
feat(l10n): traducción zh-Hans real keys-por-keys reemplaza rule-based v0

Reemplaza el archivo zh-Hans.lproj generado en M15 con traducción de
calidad keys-por-keys respetando BRAND-VOICE adaptado al chino
simplificado (你 cercano, no 您 formal, no regañar, motivacional)
+ glosario financiero canónico.

Measure words usados correctamente: 笔 (transacciones), 天 (días),
张 (tarjetas), 项 (items formales), 条 (registros), 次 (veces),
个月 (meses). Espacios entre números/latín y caracteres chinos según
convención iOS Apple. Punctuación china (， 。 ！ ？ "" ：) en
oraciones chinas, no inglesa. Solo caracteres simplificados (简体),
ningún tradicional (繁體) — verificado con script de detección.

Yala preservado en latín (no transliterado a 雅拉/亚拉/etc.).

Cambios:
- Yala/Resources/zh-Hans.lproj/Localizable.strings: 3,041 keys
- YalaWidgets/Resources/zh-Hans.lproj/Localizable.strings: 115 keys
- stringsdict (regla `other` única) y InfoPlist.strings sin cambios
  (calidad real desde M15)

zh-Hant (Taiwan/HK) sigue out of scope — usuarios zh-Hant-TW caerán
a fallback en por decisión documentada en plan original.

Tests verde + UTF-8 encoding verificado + 0 tradicionales detectados
+ device QA visual con screenshots confirmados. 31 duplicados
pre-existentes preservados.
```

## Reporta al final

- Total keys traducidas: 3,041 (main) + 115 (widgets) = 3,156.
- Output del script de paridad y placeholders.
- Confirmación: NEEDS_TRANSLATION = 0, Yala latín preservado, 0 transliteraciones (雅拉/亚拉).
- Output de `file -I` confirmando charset=utf-8.
- **Output del script de detección de tradicionales**: "✅ Sin caracteres tradicionales detectados".
- Output de `xcodebuild test` (`** TEST SUCCEEDED **`).
- **Screenshots de device QA visual** (Panel + Records + Profile + Statistics) confirmando:
  - Renderizado correcto sin mojibake
  - Ningún caracter tradicional visible
  - Punctuación china correcta
- Lista breve (≤10) de keys complejas — especialmente decisiones de **measure word** y **espaciado chino-latín**.

NO commitees automáticamente — espera aprobación del user.

--- END PROMPT ---
