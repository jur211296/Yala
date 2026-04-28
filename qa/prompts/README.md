# Translation Prompts (sesiones paralelas)

Estos prompts permiten ejecutar las 4 traducciones de calidad real (nl, pl, ja, zh-Hans) en sesiones de Claude Code separadas — una por idioma — en paralelo. Reemplazan las traducciones rule-based v0 generadas en M12-M15 por traducciones reales keys-por-keys.

## Cómo usar

1. Abre 4 sesiones nuevas de Claude Code en el repo `/Users/jur/Yala` (una pestaña/ventana por idioma).
2. En cada sesión, copia el bloque entre `--- BEGIN PROMPT ---` y `--- END PROMPT ---` del archivo correspondiente y pégalo como primer mensaje:
   - `translate-nl.md` → sesión nl
   - `translate-pl.md` → sesión pl
   - `translate-ja.md` → sesión ja
   - `translate-zh-Hans.md` → sesión zh-Hans
3. Cada sesión es independiente — no comparten contexto. Eso es intencional para que el budget de output de cada modelo se dedique a un solo idioma.
4. Al terminar cada sesión:
   - El agente reportará cuántas keys tradujo + complejidades + paridad verde.
   - Tú verificas el commit message sugerido y apruebas el commit.

## Por qué sesiones separadas

- El archivo `en.lproj/Localizable.strings` (~80K tokens) consume buena parte del context budget al leerlo.
- Producir un idioma traducido requiere ~60-100K tokens output sostenidos.
- 4 idiomas × 80K output = ~320K tokens output total, que NO cabe en una sola sesión.
- Sub-agents general-purpose tienen un watchdog (600s sin progreso = killed) que mata cualquier intento de Write enorme.
- **Solución:** 4 sesiones independientes, cada una enfoque en un solo idioma con muchos Edit calls pequeños progresivos.

## Approach técnico recomendado en cada sesión

Cada prompt incluye instrucciones explícitas sobre el approach:

1. Read en chunks de ~500 líneas (no leer el archivo completo de una vez).
2. Edit calls de ~10-30 strings cada uno (no Write monolítico).
3. Recorrer las 91 secciones MARK del archivo incremental.
4. Validar con el script de paridad al final.

## Validación cruzada (post-merge de las 4)

Una vez que tengas los 4 commits listos en main/branch, ejecuta el suite completo:

```bash
cd /Users/jur/Yala
xcodebuild test -scheme Yala -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/LocalizationParityTests \
  -only-testing:YalaTests/StringsdictParityTests \
  -only-testing:YalaTests/BundleLocaleDriftTests
```

Debe pasar `** TEST SUCCEEDED **`.

## Después de las 4 traducciones

Considera abrir un ticket de seguimiento para:
- LQA visual con nativos en simulador (top 5 vistas: Panel, NewTransaction, Records, Profile, Statistics)
- Truncation audit para nl (compound words largos) y zh-Hans (CJK + measure words)
- ASC metadata para los 4 nuevos locales (subtitle, description, keywords, screenshots)
