# Gateway · runbook de despliegues pendientes

El Worker no se despliega solo: `deploy:staging` y `deploy:production` los corre Jürgen a mano (`README.md`, «Deploy»).
Aquí se apunta lo que está mergeado y espera despliegue, con cómo comprobarlo. Lo desplegado se borra de aquí.

**Pendiente (2026-11-04, rama 2.3): registro de uso de tokens de IA y topes de salida** (sesión «Control del coste de
la IA»). El binding `AI_USAGE` → dataset `yala_ai_usage` (se crea solo con el primer punto) y los topes de `photo.read`,
`chat.intent`, `chat.suggestions` y de las filas passthrough. **Staging ya lo corre** (versión `f48d2794`, desplegada
desde la rama de la sesión sobre `origin/2.3`, que incluye también `paymentHint`). Producción: `npm run deploy:production`
desde 2.3 y, a los dos minutos, la consulta de `README.md` («Uso de tokens por llamada») sobre `yala_ai_usage` debe
devolver filas.

**Pendiente (2026-11-04, rama 2.3): `paymentHint` en el esquema de `text.parse`** (card v466, «Yala IA: detectar medio
de pago»). Solo cambia `TEXT_PARSE_SCHEMA` (`src/ai/schemas.ts`): un campo nuevo, nullable y obligatorio en modo estricto.
Sin él desplegado, el modelo no puede devolver el campo y la app nueva cae a buscar el medio de pago en la frase (un solo
movimiento, una sola mención). Las versiones instaladas ignoran el campo al decodificar. Orden: staging → probar en Yala Dev
«25 almuerzo yape» con una cuenta llamada Yape (el borrador sale con esa cuenta) → producción. Se puede desplegar antes de
publicar 2.3. **Cuidado**: un despliegue posterior desde `2.2` o `1.0` (sin este cambio) quita el campo otra vez.

**Antes de eso, nada pendiente** (2026-11-02). Los dos entornos corren el manifest de Grupos **v3** (g29_01, card xi74: el autor de
gastos y liquidaciones), desplegado desde la rama `encargo/2026-11-02-grupos-autor-del-gasto` sobre `origin/2.2`, sin
más cambios de gateway que ése: staging `453090c6`, producción `9b651957`. Personal sigue en v6. Detalle en
`docs/RUNBOOK-staging-ddl.md`, entrada g29_01.

**Sigue en pie el guard de `predeploy:*`** (`scripts/check-manifest-not-older.mjs`): para el despliegue si el árbol trae
un manifest más viejo que el desplegado. **`1.0` lo trae desde el 2026-11-04** (PR aparte de la sesión «Control del
coste de la IA»): desde `1.0`, con los manifests en v1, `npm run deploy:*` para. El Worker de producción no se despliega
desde ninguna rama sin `manifest_version: 3`. Forzar desde 2.2:
`ALLOW_MANIFEST_DOWNGRADE=1`, y solo junto con los `*_rollback.sql`.
