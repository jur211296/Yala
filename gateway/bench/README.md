# Banco de calidad de modelos de IA

Mide qué modelo hace bien cada tarea de IA de Yala, y a qué coste. De aquí sale cada fila de la tabla
tarea → modelo del gateway (`src/ai/routes.ts`). El principio es **primero calidad medida, después
precio**: gana el modelo más barato que pase el listón de su tarea.

## Revisión periódica: un comando

```bash
cd gateway
npm ci
npm run bench -- --task all          # las tres tareas, todos los candidatos con clave
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

## Añadir una tarea (sesión 2)

1. Su cuerpo en `lib/appRequests.ts` (prompts desde Swift), su criterio en `lib/grading.ts`, sus casos en
   `cases/<tarea>.json`.
2. Sus parámetros base en `baseParams()` de `run.ts` y su esquema en `TASK_SCHEMAS` (`src/ai/routes.ts`).
3. `npm run bench -- --task <tarea>` y, con el resultado, su fila en `ROUTES`.
