# Banco de calidad de modelos de IA

Mide qué modelo hace bien cada tarea de IA de Yala, y a qué coste. De aquí sale cada fila de la tabla
tarea → modelo del gateway (`src/ai/routes.ts`). El principio es **primero calidad medida, después
precio**: gana el modelo más barato que pase el listón de su tarea.

## Revisión periódica: cuándo y quién

- **Cada trimestre, el día 6 de enero, abril, julio y octubre.** La dispara una rutina de Frank (el agente de Yala), que ya
  existe; no hace falta acordarse. La revisión corre el comando de abajo con los candidatos del día y, si una fila cambia,
  la propone con su tabla en un PR.
- **Y además, siempre que OpenAI anuncie un apagado** que toque un modelo de la tabla
  (https://developers.openai.com/api/docs/deprecations). Un apagado del modelo de una fila es urgente aunque falten meses
  para el trimestre: el 2026-10-07 la página anunciaba el de `gpt-4.1-nano` a 16 días.
- Lo que se mira, por este orden: (1) la página de apagados del proveedor de cada fila; (2) los modelos nuevos del
  mercado, que entran como una línea en `candidates.ts`; (3) los precios del día.

## Revisión periódica: un comando

```bash
cd gateway
npm ci
npm run bench -- --task all          # todas las tareas registradas, todos los candidatos con clave
npm run bench -- --report            # rehace las tablas desde los .jsonl sin llamar a nadie
```

Deja una línea por llamada en `bench/results/<fecha>/<tarea>.jsonl` y la tabla en `<tarea>.md`. Es
reanudable: si se corta, se vuelve a lanzar el mismo comando y solo repite lo que falte (los fallos de red,
429 y 5xx se repiten; los demás errores cuentan como fallo del candidato).

Antes de una revisión:

1. **Precios y modelos del día.** Actualiza `candidates.ts` con lo que digan las páginas oficiales (están
   enlazadas arriba del fichero) y cambia `CHECKED`. Un modelo nuevo del mercado entra como una línea más.
2. **Claves.** `~/Secrets/yala-ai-bench/{openai,gemini,anthropic,xai}.key`. Nunca las del Worker. Workers AI usa
   el login de wrangler (`npx wrangler whoami`). Sin clave, ese proveedor se salta y lo dice.
3. **Presupuesto.** Una corrida completa de las tres tareas cuesta unos pocos dólares; la foto es lo caro.
   Para no gastar de más, dos pasadas: primero todos los candidatos a resolución original
   (`--task photo.read --edges 0`) y después el barrido de resolución y detalle solo de los que pasan
   (`--only openai:gpt-6-luna,… --edges 0,2048,1536,1024,768 --details low,high`).

4. **Latencia: mídela en serie.** Con `--concurrency` > 1 y fotos subiendo a la vez, la subida satura la conexión y
   las latencias de TODO lo que corre en paralelo salen infladas (medido el 2026-10-07: sugerencias de 17–30 s que en
   serie eran de 3–4 s). Primero criba en paralelo; después, para las finalistas, `--reps 2 --concurrency 1` sin nada
   más corriendo, y lee la latencia solo de esa pasada.

## Opciones

| Opción | Qué hace |
|---|---|
| `--task chat.intent\|chat.suggestions\|photo.read\|all` | Tarea(s) a medir |
| `--only openai:gpt-6-luna,gemini` | Solo esos candidatos (id exacto, prefijo o proveedor) |
| `--efforts none,low` | Esfuerzos de razonamiento a probar (por defecto, los del candidato) |
| `--edges 0,2048,1024` | Foto: lado mayor en px antes de mandar (0 = original). Nunca amplía |
| `--details low,high` | Foto: `detail` de la imagen |
| `--cases id1,id2` · `--limit N` | Solo esos casos / los N primeros |
| `--reps N` | Repeticiones por caso (variabilidad) |
| `--concurrency N` | Llamadas en paralelo (4 por defecto) |
| `--date AAAA-MM-DD` | Carpeta de resultados (por defecto, hoy). `smoke` no se commitea |
| `--max-usd 0.50` | Tope de gasto de la corrida: al llegar, no lanza más llamadas (lo que falte se repite al reanudar) |

## Cómo está hecho, y por qué

- **Mismo cuerpo que la app.** `lib/appRequests.ts` construye la petición con los prompts LEÍDOS del código
  Swift (`lib/swift.ts` extrae los literales `"""…"""`), así que si alguien cambia un prompt en la app el
  banco mide el nuevo sin tocar nada. Lo fija `test/ai.bench.test.ts`.
- **Mismo adaptador que el gateway.** Se llama a `src/ai/providers/*` con la fila candidata: lo que se mide
  es exactamente lo que el gateway mandaría.
- **Criterio explícito por tarea** (`lib/grading.ts`, y en el campo `criterion` de cada fichero de casos).
  Primero se replica el parser de la app: si la app rechazaría la respuesta, es fallo aunque el modelo
  «acertara».
- **Casos sin datos personales** (`cases/`). Clasificador: frases en los 10 idiomas de la app con
  variantes regionales. Sugerencias: contextos de usuario inventados por idioma. Foto: los ejemplos que
  enseña la app y capturas generadas con datos ficticios (`fixtures/make_photos.py`; una captura es un
  render, así que una captura sintética es igual de real). Fotos reales de recibos de usuarios, si se
  añaden, van anonimizadas.

## Añadir una tarea

1. Su fichero en `tasks/<tarea>.ts` (un `BenchTask`: el cuerpo exacto de la app con los prompts leídos del Swift, los
   parámetros de hoy y el criterio, que replica primero el parser de la app) y una línea en `tasks/index.ts`.
2. Sus casos en `cases/<tarea>.json`, con su campo `criterion`.
3. `npm run bench -- --task <tarea>` y, con el resultado, su fila en `ROUTES` (`src/ai/routes.ts`). Si el proveedor no
   tiene JSON libre (Anthropic), su esquema va con los demás.

## Los jueces (2026-10-08)

**Claude Sonnet 5.5 juzga a todos los proveedores menos al suyo**, en `chat.answer` y en Insights y Tendencias
(`lib/insightsJudge.ts`, `JUDGES`). A los candidatos de Anthropic los juzgan otros: Gemini en `chat.answer`; Gemini y
Grok en Insights. Se queda así para la revisión trimestral: se paga con los créditos de Anthropic. Acuerdo medido con
las muestras a mano, en `docs/ai-model-bench-2026-10-claude.md`: en Insights no decide (55 %, κ 0,23), como ninguno antes.

**Excepción, el mismo 2026-10-08: en las tres tareas `insights.*` juzga Gemini 3.8 Flash solo** (`judgeOrder` y
`judgesFor`). A los candidatos de Gemini los juzga Sonnet. Ahí Sonnet coincidía con la nota a mano un 55 % y Gemini un
85 %. Uno solo, y no la pareja, porque la pareja era Gemini + Sonnet en cualquier orden y el veredicto no cambiaba. Con
Gemini solo, el acuerdo del banco en Insights pasa del 67 % al 87 % (κ 0,33 → 0,52) y cada respuesta cuesta un juicio,
no dos. `trends.summary` sigue con la pareja que abre Sonnet.

## `chat.answer`: el juez va aparte (sesión 2 · chat y nota)

`npm run bench -- --task chat.answer` aplica solo el criterio determinista (cifras que salen del contexto, idioma,
la cifra que se preguntó). Lo que eso no ve —una cifra real atribuida a otra cosa, una comparación al revés— lo decide
un juez de OTRO proveedor, después y solo si su acuerdo con una muestra puntuada a mano es alto:

```bash
npx vite-node bench/tasks/chat.answer.judge.ts -- sample --n 36        # plantilla: se puntúa A MANO antes de ver al juez
npx vite-node bench/tasks/chat.answer.judge.ts -- agree --judges anthropic:claude-sonnet-5-5,gemini:gemini-3.8-flash
npx vite-node bench/tasks/chat.answer.judge.ts -- apply --judges anthropic:claude-sonnet-5-5,gemini:gemini-3.8-flash --first
npm run bench -- --report --task chat.answer
```

`--first` usa el primer juez que no sea del proveedor del candidato. Desde el 2026-10-08 Sonnet 5.5 va primero (acuerdo
100 %, κ 1,00 en la muestra del 7-oct) y juzga a todos menos a Anthropic; a Anthropic lo juzga Gemini. Nadie juzga a su
propio proveedor. Los juicios quedan en `<tarea>.judge.jsonl`, con su coste (lo cuenta `--spend`), y no se pagan dos veces.
Si se corrige un criterio después de medir, `chat.answer.judge.ts -- regrade` y `text.regrade.ts -- --task
text.parse|chat.rewrite` vuelven a puntuar con la respuesta guardada, sin llamar a nadie. Informe de la sesión 2:
`results/2026-10-07/REPORT-chat-y-nota.md`.
