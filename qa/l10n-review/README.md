# Revisión de traducciones con Sonnet

Revisa los catálogos de la app en los 16 idiomas contra el español de referencia (`es-419`) y deja un informe por
idioma. Se corre **antes de cada release**, sobre lo que cambió desde la anterior. Nació en el lote 12.4 (2026-10-25,
card «Revisión de traducciones con Sonnet antes de cada release»), que hizo la primera corrida sobre el catálogo entero.

## Antes de cada release

```bash
python3 qa/l10n-review/review.py --since v2.2.0          # la etiqueta de la release ANTERIOR
python3 qa/l10n-review/apply.py qa/l10n-review/informes/<fecha> --skip-keys qa/l10n-review/descartadas.txt
python3 qa/l10n-review/propagate_variants.py HEAD          # el respaldo de es-ES, es-AR y en-GB, al día con su padre
python3 qa/l10n-review/review.py --since HEAD --out qa/l10n-review/informes/<fecha>-pase2   # segunda pasada
```

La segunda pasada revisa solo lo que la primera cambió: caza lo que el arreglo estropeó y lo que se quedó a medias. Se
aplica igual que la primera. Después, el `/gate`: `LocalizationParityTests` y `TranslationLot124GuardTests` comprueban
paridad, placeholders y los arreglos fijados.

## Qué hace cada pieza

- **`review.py`**: dos capas. La determinista (sin LLM) busca claves que faltan, placeholders distintos de la
  referencia, textos idénticos al inglés o al español y alias (`es`, `pt`) que dejaron de ser copia de su base. La de
  Sonnet manda trozos de 150 claves con la clave, el texto en `es-419`, en `en` y en el idioma, más una guía por idioma
  (registro de la marca, vocabulario regional) y un glosario sacado de la propia app (cómo se llaman hoy las pestañas y
  los conceptos). Devuelve un JSON por defecto con categoría, gravedad, propuesta y motivo.
  - Completo en es-419, en, de, fr, it, nl, pl, pt-BR, pt-PT, ja y zh-Hans. En en-GB, es-ES y es-AR solo sus
    overrides (lo que difiere del padre): el resto es copia. pt-PT va entero porque su respaldo era el pt-BR viejo.
  - Incluye los plurales del `.stringsdict` y los textos de permisos (`InfoPlist.strings`).
  - **Caché** en `~/Library/Caches/Yala/l10n-review/`: una corrida cortada se retoma sin repetir trozos.
- **`apply.py`**: aplica solo lo que pasa los filtros del Paso 0 del lote 12.4 (D4). Ortografía, sin traducir,
  regional y significado de gravedad media o alta; registro solo hacia el trato de la marca (informal), salvo es-AR y
  pt-PT. **Nunca terminología** (se contradice entre trozos y toca decisiones de producto), nunca lo que cambia el
  nombre del asistente («Yala AI/IA/KI»), nunca una clave protegida y nunca una propuesta que cambie placeholders o cuyo
  texto de partida ya no sea el del catálogo. Regenera los alias al final.
- **`claves-protegidas.txt`**: las claves que la app EMPAREJA POR TEXTO con lo que ya guardó (categorías de sistema,
  «Sin asignar», textos por defecto de avisos). Cambiar su valor sin migrar duplica categorías. Cada una dice quién la
  empareja.
- **`descartadas.txt`**: propuestas que se miraron a mano y se rechazaron, con su motivo (admite `*`).
- **`propagate_variants.py`**: el respaldo materializado de las variantes no se entera de las correcciones del padre.
  Lo pone al día solo donde la variante seguía siendo copia exacta del valor viejo; los overrides regionales no se tocan.

## Coste y tiempo

- **Por defecto va con el CLI de Claude Code** (`claude -p --model sonnet`), con la suscripción: sin clave ni gasto de
  API. Corre desde una carpeta temporal vacía, sin herramientas y con `--setting-sources project`, así que no dispara
  los hooks de casa (ni avisos a Grok).
- Corrida completa (16 idiomas, ~440 trozos, 6 en paralelo): **~25 min**. Una de release con `--since`: un par de
  minutos.
- `--backend api` usa la API de Anthropic con `ANTHROPIC_API_KEY` del entorno (no la lee de ningún fichero). Una
  corrida completa con Sonnet costaría del orden de 15-30 USD; no se ha usado.

## Lo que la primera corrida dejó fuera (2026-10-25)

- **Terminología**: ~1.000 propuestas, ninguna aplicada. La más repetida es que la prosa dice «Panel» mientras la
  pestaña se llama «Home», «Accueil», «Início»… en 10 idiomas; y pt-BR mezcla «Ajustes» y «Configurações».
  Resuelto el 2026-10-26 a mano, clave a clave (ticket `l10n-terminology-follows-the-tab-names`): la pestaña es «Panel»
  en todos los idiomas y pt-BR dice «Ajustes». Las guardas de `LocalizationParityTests` lo fijan; `apply.py` sigue sin
  aplicar terminología.
- Las propuestas de gravedad baja.
- Los catálogos de los widgets (`YalaWidgets/Resources`): no entran todavía en `review.py`.
