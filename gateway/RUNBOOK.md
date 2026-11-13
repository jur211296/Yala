# Gateway · runbook de despliegues pendientes

El Worker no se despliega solo: `deploy:staging` y `deploy:production` los corre Jürgen a mano (`README.md`, «Deploy»).
Aquí se apunta lo que está mergeado y espera despliegue, con cómo comprobarlo. Lo desplegado se borra de aquí.

**Pendiente (2026-11-05, rama 2.3): repartir un recibo en un grupo** (card «Grupos: repartir un recibo con IA»). Dos
tareas nuevas, `receipt.photo` (cubo `vision`, exige imagen) y `receipt.voice` (cubo `voice`, va con la nota), con el
esquema `RECEIPT_SPLIT_SCHEMA` y JSON estricto. Sin ellas desplegadas, «Desde un recibo» de Nuevo gasto de grupo contesta
400 (tarea desconocida) y la app enseña «No pude leer el recibo». Las versiones instaladas no las piden. Orden:
`deploy:staging` desde 2.3 → en Yala Dev, un grupo → «+» → «Desde un recibo» → foto de un recibo y «Ana el lomo, yo la
pizza» → la revisión sale con las líneas y los nombres → `deploy:production`. Se puede desplegar antes de publicar 2.3.
**Cuidado**: un despliegue posterior desde `2.2` o `1.0` las quita.

**Pendiente (2026-11-04, rama 2.3): correo del banco por reenvío** (`src/mail/`, encargo S2). Nada desplegado: sin
el OK de Jürgen al gasto (cierre del PR) no se toca producción. Orden, y cada paso se comprueba antes del siguiente:

1. **Migración D1** `0003_mail_forwarding.sql`: `npm run migrate:staging`, después `npm run migrate:production`. Sin
   ella, `/mail/address` da 500 y la entrada `email` rechaza todo (no encuentra la dirección).
2. **Worker**: `deploy:staging` y, tras probarlo, `deploy:production`. El `email` del export va en el mismo Worker.
3. **Email Routing** (card de Jürgen «Activar el buzón», dominio aparte decidido el 2026-11-10): en Cloudflare, zona
   **`yalainbox.com`** (no `yala-app.pe`) → Email → Email Routing → activar (crea los MX y el TXT de SPF; la zona tiene
   que tener su DNS en Cloudflare) → activar **Subaddressing** en sus ajustes, para que `auto+<código>@` llegue a la
   regla de `auto@` → regla `auto@yalainbox.com` con la acción «Send to a Worker» → `yala-gateway-production`, y regla
   `auto-staging@yalainbox.com` → `yala-gateway-staging`. Las dos direcciones ya están en `wrangler.toml`
   (`MAIL_ADDRESS_LOCAL` y `MAIL_ADDRESS_DOMAIN` de cada entorno; las fija `test/mail.wrangler.test.ts`): staging da
   `auto-staging+<código>@yalainbox.com` y producción `auto+<código>@yalainbox.com`.
4. **Comprobar**: en Yala Dev con la nube, Ajustes › Correo del banco da la dirección; un correo a ella deja
   `[mail] outcome=draft` en `wrangler tail` y el borrador sale en la Bandeja al volver a la app.

**La política de privacidad va antes que el paso 3 en producción**: la web de producción publica desde `1.0`. La
política publicada ya dice `auto+…@yalainbox.com` en español e inglés desde el 2026-11-12.

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
