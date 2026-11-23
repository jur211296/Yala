---
id: 2026-11-22-comercios-en-comun-construir
status: done
area: "captura"
created: 2026-11-22
updated: 2026-11-22
source: "Jürgen eligió el 22-nov las opciones recomendadas de la propuesta del histórico compartido de comercios (decisión t1890u-2; `decision/jurgen` del artifact vacío ⇒ todas las recomendadas). Encargo `encargos/lanzados/2026-11-22-comercios-en-comun-construir.md`, con su Paso 0."
---

# «Comercios en común»: lista anónima de comercio a tipo

Construcción de la propuesta `tickets/done/2026-11-22-historico-comercios-compartido-propuesta.md` (artifact
https://claude.ai/artifact/PsU8Pp6cwPbEPaBPLiw8tL), con las opciones recomendadas: variante B, D1 del gateway, aviso una
vez + salida en Perfil, línea «Así suele categorizarse…», todos reciben, solo aportan los gastos capturados.

## Qué cambia para quien usa la app

- **Un comercio que nunca apuntaste puede llegar ya categorizado.** Si varias personas coinciden en que «Tambo» es un
  supermercado, al leer una foto, un pago de Apple Pay, un aviso o correo del banco o una nota de voz de Tambo, Yala
  propone tu categoría de supermercado. Solo propone: lo confirmas tú.
- **En «Esto leí»** sale la línea «✓ Así suele categorizarse Tambo en Yala. Cambiar» cuando la categoría viene de la lista
  común. «Cambiar» abre el selector. Al guardar pasa a tu memoria y la próxima vez ya no sale.
- **Tu memoria manda**, aunque sea de una sola vez: si una vez pusiste Tambo en «Antojos», eso gana a la lista común.
- **Aportar**: al aprobar un gasto capturado, el nombre limpio del comercio y su tipo esperan en el teléfono y salen una
  vez por semana, todos juntos y en orden al azar. Nunca el importe, la fecha, la cuenta ni tus categorías. Antes del
  primer envío sale un aviso, una vez, con «No aportar». La salida permanente: Perfil › Comercios en común.

## Qué se tocó

- **Servidor** (`gateway/src/comercios-comun/`, migración `0005_comercios_comun.sql`): `POST /comercios-comun/aportes`
  y `GET /comercios-comun/lista`, con el token de App Attest. Huella del teléfono = HMAC del keyId con llave del servidor;
  semana ISO, sin día ni hora; 7 días de uso, tope 30 por semana; regla B (3 teléfonos, ≥75 %, dos de ventaja, 5 para
  cambiar); votos borrados al publicar o a las 13 semanas; lista recalculada al primer GET de cada día UTC (sin cron),
  servida desde KV con ETag.
- **App** (`Yala/Services/ComerciosEnComun/`): limpieza del nombre (marca del banco de 666 si casa; sin sucursal, calle,
  ciudad, números ni razón social), traducción inversa subcategoría → tipo, estado en un JSON de Application Support (no
  SwiftData), cliente, aviso y línea. Enganche en `MerchantMemoryService` (orden y aporte), `source:` en las tres
  aprobaciones (`DraftService` ×2, `InboxDraftEditSheet`), la línea en `VoiceDraftReviewCard`, la fila y su pantalla en
  Perfil (`ProfileDestination.comerciosEnComun`), y la sincronización al volver a primer plano (`AppBootstrapper`).
- **Textos**: `ComerciosEnComun.strings` en los 16 idiomas (español neutro en las cuatro variantes).
- **Web**: apartado «Comercios en común» dentro de la sección 6 de la política, más una línea en conservación y otra en
  identificadores, en los 6 idiomas (`Web/src/i18n/translations.ts`, `PrivacyPage.astro`). Se publica con la web de la
  próxima versión.
- **Regla**: `.claude/rules/ai-gateway.md` (el orden de las sugerencias y lo que no se toca).

## Probado

- Gateway: 17 tests propios (`gateway/test/comercios-comun/`) contra SQLite real con las migraciones 0001 y 0005 + suite
  entera (788) y typecheck.
- App: 28 unit (5 suites nuevas + `MerchantMemoryNatureFilterTests`), 3 XCUITest (`ComerciosEnComunUITests`: con lista,
  sin lista y Perfil), build de las dos schemes, `YalaTests` entero en el gate.
- Web: `astro build` y el apartado en el HTML generado.
- Gate: build 2/2 · `YalaTests` entero (15.826 tests, 1.895 suites) · 11 clases de XCUITest de lo tocado (89 casos, 0 fallos, centinela limpio) · 29/29 pasos de `coverage-index`.
- Evidencia: `~/Claude/entregas/2026-11-22-comercios-en-comun-construir/evidencia/` (Esto leí sin y con lista, Perfil, política web antes y después).

## Qué queda

Jürgen eligió el 22-nov la opción B: staging y producción los hace Dan. El código entró en 2.3 antes de staging porque no
tiene efecto sin la migración (las rutas dan error, la app reintenta y no cambia nada).

### Para Dan: staging

Desde `gateway/` en la rama `2.3` ya mergeada, con sesión de Wrangler. Nada de esto toca producción.

```bash
cd gateway && npm ci
# 1. Migración D1 0005 en staging (crea cc_votes, cc_device_week y cc_published; no toca las tablas que ya existen)
npm run migrate:staging          # = wrangler d1 migrations apply yala-gateway-staging --remote
# 2. Deploy del gateway de staging (el predeploy copia y comprueba el manifest)
npm run deploy:staging           # = wrangler deploy
# 3. Token de desarrollo (solo staging; DEV_SHARED_SECRET es el secret del Worker de staging)
BASE=https://yala-gateway-staging.misty-surf-6866.workers.dev
TOKEN=$(curl -s -X POST "$BASE/v1/attest/dev" -H "X-Yala-Dev-Secret: $DEV_SHARED_SECRET" -H "X-Yala-Dev-Tier: free" | python3 -c 'import sys,json; print(json.load(sys.stdin)["sessionToken"])')
# 4. Aporte: espera HTTP 200 y {"status":"ok","accepted":1}
curl -s -w '\nHTTP %{http_code}\n' -X POST "$BASE/comercios-comun/aportes" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"items":[{"merchant":"Tambo","kind":"supermarket"}]}'
# 5. Lista: espera HTTP 200, cabecera etag y {"version":"…","items":[]} (un solo teléfono no publica nada: hacen falta 3)
curl -s -D - "$BASE/comercios-comun/lista" -H "Authorization: Bearer $TOKEN"
#    Repetida con el etag de la respuesta anterior: espera HTTP 304 sin cuerpo
curl -s -o /dev/null -w 'HTTP %{http_code}\n' "$BASE/comercios-comun/lista" -H "Authorization: Bearer $TOKEN" -H 'If-None-Match: "<etag>"'
# 6. Comprobación en D1: una fila con merchant TAMBO, kind supermarket y la semana ISO, sin hora ni cuenta
npx wrangler d1 execute yala-gateway-staging --remote --command "SELECT merchant, kind, week FROM cc_votes"
```

Sin token, las dos rutas responden 401. Producción (migración `npm run migrate:production`, `npm run deploy:production`), la web y la etiqueta de la App Store esperan el OK de Jürgen.

### Después, con el OK de Jürgen

1. Migración D1 `0005_comercios_comun.sql` en staging y en producción (`npm run migrate:staging` / `migrate:production`).
2. Desplegar el gateway (staging y producción). Antes de la migración, las rutas dan 500 (tabla inexistente) y la app no
   pierde nada: reintenta.
3. Publicar la web con la política nueva (va con la versión, rama 1.0).
4. Etiqueta de privacidad de la App Store: añadir «Historial de compras», **no vinculado** a la persona, uso
   «Funcionalidad de la app». El resto de la etiqueta no cambia.
5. Probar en el teléfono contra staging: aprobar un gasto capturado, ver el aviso al volver a abrir Yala, y con el reloj
   o una semana después comprobar en D1 staging que entró el voto (`SELECT merchant, kind, week FROM cc_votes`).
