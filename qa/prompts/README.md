# Translation Prompts (sesiones paralelas)

Estos prompts permiten ejecutar las 4 traducciones de calidad real (nl, pl, ja, zh-Hans) en sesiones de Claude Code separadas — una por idioma — en paralelo. Reemplazan las traducciones rule-based v0 generadas en M12-M15 por traducciones reales keys-por-keys.

## Estado

- ✅ **nl-NL** completada (commit 2026-04-28). Sirve como referencia exitosa para los próximos.
- ⏳ pl, ja, zh-Hans pendientes.

## Cómo usar

1. Abre 1–4 sesiones nuevas de Claude Code en el repo `/Users/jur/Yala` (una pestaña/ventana por idioma).
2. En cada sesión, copia el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` del archivo correspondiente y pégalo como primer mensaje:
   - `translate-pl.md` → sesión pl
   - `translate-ja.md` → sesión ja
   - `translate-zh-Hans.md` → sesión zh-Hans
3. Cada sesión es independiente — no comparten contexto. Eso es intencional para que el budget de output de cada modelo se dedique a un solo idioma.
4. Al terminar cada sesión:
   - El agente reportará cuántas keys tradujo + complejidades + paridad verde + tests verde + screenshots de device QA (para ja/zh).
   - Tú verificas el commit message sugerido y apruebas el commit.

## Por qué sesiones separadas

- El archivo `en.lproj/Localizable.strings` (~290KB / ~70K tokens) consume buena parte del context budget al leerlo.
- Producir un idioma traducido requiere **17–20 Edits grandes** (~50–150 keys cada uno) — output sostenido de ~60-100K tokens.
- 4 idiomas × 80K output = ~320K tokens output total, que NO cabe en una sola sesión.
- Sub-agents `general-purpose` tienen un watchdog (600s sin progreso = killed) que mata cualquier intento de Write enorme.
- **Solución**: 4 sesiones independientes, cada una enfocada en un solo idioma con muchos Edits grandes progresivos.

## Lecciones de la sesión nl-NL exitosa (aplicadas a los 3 prompts pendientes)

### Approach técnico
- ❌ NO usar Write monolítico (modelo no puede outputear 70K tokens).
- ❌ NO usar muchas Edits pequeñas de <30 keys (consume contexto sin acelerar).
- ✅ **17–20 Edits grandes** de 50–150 keys cada uno cubriendo secciones MARK completas o adyacentes.
- ✅ Read en chunks de 500–700 líneas para tener contexto de varias secciones.
- ✅ Edits en paralelo cuando son independientes.
- ✅ Verificar `grep -c '^"' file` cada ~5 Edits para detectar pérdidas de keys.

### Pre-existencias del reference (NO son bugs)
- **31 keys duplicadas** existen en en.lproj. Apple usa el último valor. Tu archivo target debe preservar las mismas duplicaciones.
- **Parser reporta 3010 unique keys**, no 3041 (porque dedupe). Output esperado: `en=3010 xx=3010 missing=0 extra=0`.
- **~30 keys "huérfanas"** entre secciones MARK (declaradas inline). Asegúrate de cubrirlas — Edits muy localizados las pierden.

### Validaciones (6–8 checks por idioma)
1. Paridad de keys (3010 unique)
2. Placeholders preservados (count + orden)
3. NEEDS_TRANSLATION marker = 0
4. Yala preservado ≥80 ocurrencias en latín (NUNCA traducido o transliterado)
5. Duplicados consistentes con en.lproj reference
6. Line count idéntico al reference (3581 líneas)
7. **(ja/zh)** UTF-8 encoding verificado con `file -I`
8. **(zh)** 0 caracteres tradicionales (繁體)

### xcodebuild test obligatorio antes de reportar
Cada sesión DEBE ejecutar:
```bash
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests \
  -only-testing:YalaTests/StringsdictParityTests \
  -only-testing:YalaTests/BundleLocaleDriftTests 2>&1 | tail -3
```
Debe imprimir `** TEST SUCCEEDED **`.

### Device QA visual obligatorio para ja/zh
Por riesgo de mojibake (encoding) o caracteres tradicionales contaminantes:
- Build `Yala Dev`, install, setear idioma del simulador, tomar screenshots de Panel + Records + Profile + Statistics.
- Verificar que NO haya `?` ni cuadrados □ ni caracteres erróneos.

### Falsos positivos en grep de "residuos"
Cada idioma tiene preposiciones/conjunciones que coinciden con palabras inglesas:
- **nl**: `naar` (to), `even` (a moment), `in/of/voor/met/van`
- **pl**: `do/i/w/z/za/o/na/po`
- **ja**: ningún false positive (script alphabets disjuntos)
- **zh**: ningún false positive (script disjunto)

NO uses grep de palabras inglesas como heurística general — busca patrones específicos del rule-based v0.

## Diferencias clave por idioma (ver prompts individuales)

| Aspecto | nl | pl | ja | zh-Hans |
|---|---|---|---|---|
| Plurales stringsdict | one/other | **one/few/many/other** ⭐ | only `other` | only `other` |
| Pronombre 2ª pers | je/jou (informal) | ty (informal) | omitir, NO あなた | 你 (informal, no 您) |
| Compound words | sí (largos) | flexión, no compone | kanji compuestos | caracteres compuestos |
| Currency plurals | singular | declinaciones (genitive plural) | invariable | invariable |
| Risks específicos | — | género verbal | mojibake, keigo | mojibake, tradicionales |
| Validaciones extra | — | caracteres polacos UTF-8 | UTF-8 + sin あなた | UTF-8 + 0 tradicionales |
| Device QA | recomendado | recomendado | **OBLIGATORIO** | **OBLIGATORIO** |

## Validación cruzada (post-merge de los 4)

Una vez tengas los 4 commits listos en main/branch, ejecuta el suite completo:

```bash
cd /Users/jur/Yala
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests \
  -only-testing:YalaTests/StringsdictParityTests \
  -only-testing:YalaTests/BundleLocaleDriftTests \
  -only-testing:YalaTests/LocaleResolutionTests \
  -only-testing:YalaTests/LSFallbackTests
```

Debe pasar `** TEST SUCCEEDED **`.

## Después de las 4 traducciones

Considera abrir un ticket de seguimiento para:
- LQA visual con nativos en simulador (top 5 vistas: Panel, NewTransaction, Records, Profile, Statistics)
- Truncation audit para nl (compound words largos) y zh-Hans (CJK + measure words)
- ASC metadata para los 4 nuevos locales (subtitle, description, keywords, screenshots)
- Aliases catch-all si aplican (e.g., `zh` → fallback a `zh-Hans` para usuarios sin variante)
