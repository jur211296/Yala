Yala
# Gateway: D1 DB is overloaded al vincular la suscripción
---
toca: gateway/src/sync/entitlement.ts,gateway/src/index.ts,gateway/src/d1-reintento.ts,gateway/test/d1-overloaded/,tickets/backlog/2026-11-25-gateway-d1-overloaded-vincular-suscripcion.md,tickets/done/2026-11-25-gateway-d1-overloaded-vincular-suscripcion.md
esfuerzo: high
cierre: cierra-sola
---

Bug de producción que Jürgen autorizó encolar (25-nov, 6:17 Lima). Card del tablero: «Gateway en producción: «D1 DB is overloaded» al vincular la suscripción · YALA-GATEWAY-2 y YALA-GATEWAY-3».

El 24-nov a las 21:15 Lima el gateway de producción (`yala-gateway-production`, Cloudflare Workers) devolvió `D1_ERROR: D1 DB is overloaded. Requests queued for too long.` en `/account/entitlement` (`handleEntitlementBind`, en `gateway/src/sync/entitlement.ts`, enrutado desde `gateway/src/index.ts`). Sentry abrió YALA-GATEWAY-3, y el resumen YALA-GATEWAY-2 trae otros dos eventos iguales: 3 eventos en total, 0 usuarios, handled.
- YALA-GATEWAY-3: https://yala-is.sentry.io/issues/7866245320/
- YALA-GATEWAY-2: https://sentry.io/organizations/yala-is/issues/7866245309/ y https://sentry.io/organizations/yala-is/issues/7866245376/

## Qué se pide
1. **Diagnóstico con Sentry:** lee los issues (stack, breadcrumbs, request, hora, release) y averigua la causa. ¿Hay ráfaga de vinculaciones o reintentos de la app? ¿Hay escrituras D1 concurrentes o en serie sin batch dentro del mismo request? ¿Hay alguna consulta sin índice o larga? Para producción solo lees Sentry y logs; no despliegues nada.
2. **Arreglo en el Worker gateway**, según lo que muestre la causa: reintento con backoff y jitter solo ante errores D1 transitorios (overloaded / queued too long), con tope de intentos y sin reintentar escrituras no idempotentes; o bien menos escrituras D1 concurrentes (batch, una sola sentencia, upsert idempotente). Si conviene un helper de reintento, ponlo en `gateway/src/d1-reintento.ts`. Si después del reintento sigue fallando, responde un error claro y que se pueda reintentar (503 con Retry-After), no un 500 genérico.
3. **Tests** en `gateway/test/d1-overloaded/`: simula el error de D1 y comprueba que hay reintento, que hay tope y que la vinculación queda bien una sola vez.
4. Ticket: crea `tickets/backlog/2026-11-25-gateway-d1-overloaded-vincular-suscripcion.md` y, al cerrar, muévelo a `tickets/done/`.
5. Despliega en **staging** si puedes y verifícalo. **Producción no la despliega la sesión:** en «Qué salió» deja los pasos exactos para que Dan la despliegue (migraciones si las hay, comando de deploy del Worker, cómo verificarlo y cómo dar los issues por resueltos en Sentry).

## Qué NO hay que tocar
- Nada fuera de `toca:`. Nunca `Yala/`, `YalaTests/`, `Yala/Resources`, ni `tickets/` entero.
- Si un archivo fuera de `toca:` es imprescindible, tócalo y anótalo en «Decidido sin consultar».
- No inventes credenciales ni accesos. Si falta acceso a Sentry o a staging, escribe `BLOQUEANTE:`.

## Cómo se sabe que está bien
Se encontró la causa, el arreglo tiene tests que pasan y quedan los pasos de deploy para Dan, incluidos los de resolver YALA-GATEWAY-2 y -3 en Sentry después del deploy.

## Cómo entregar
- Un PR contra 2.3, sin firma de IA. Deja el auto merge activado y cierra; no esperes al CI.
- **Entregable visual:** artifact público de Claude con la causa (línea de tiempo de los eventos), el flujo de `/account/entitlement` antes y después y los pasos de deploy para Dan. Pon el link en «Qué salió».
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión».
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi, sin decisión vital pendiente): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: los tres eventos (YALA-GATEWAY-3 POST `/account/entitlement`, YALA-GATEWAY-4 GET `/account/entitlement`, YALA-GATEWAY-2 GET `/mail/drafts`) comparten una traza y caen en 0,8 s (02:15:26–27 UTC). El POST era una compra Sandbox (TestFlight) y falló en la LECTURA final, no en una escritura. El Worker recibía ~10 peticiones/min y las métricas de D1 de producción no registran ninguna consulta en 02:14–02:15: la cola de Cloudflare se saturó sin carga nuestra. Todas las consultas de la ruta van por clave primaria o índice único. La app trata 500 y 503 igual (`.transient`, conserva el derecho cacheado): nadie perdió Pro.

**D1 · ¿Reintento o menos escrituras?** → Reintento con backoff y jitter, acotado a la familia «cola saturada».
Por qué: la causa es de plataforma y la ruta ya escribe en un solo batch idempotente; no hay escrituras que fusionar. Alternativa descartada: rehacer el SQL, que no habría evitado nada.

**D2 · ¿Qué se envuelve en el reintento?** → La secuencia D1 entera de cada rama del handler (leer → decidir → escribir → leer), no solo la escritura.
Por qué: así cada intento vuelve a leer el estado y una revocación del webhook que entre entre intentos se respeta. Alternativa descartada: reintentar solo el batch, que reusaría una decisión tomada sobre datos viejos.

**D3 · ¿Qué errores cuentan como transitorios?** → Los mensajes «D1 DB is overloaded», «Requests queued for too long» y «Too many requests queued», mirando también `cause`.
Por qué: los tres significan que la sentencia no llegó a ejecutarse. Alternativa descartada: reintentar «Network connection lost», que puede llegar después de ejecutar.

**D4 · Tope y espera** → 3 intentos en total, espera uniforme en [0, min(1 s, 100 ms·2^n)].
Por qué: el peor caso añade ~300 ms y la saturación medida fue de un instante. Alternativa descartada: más intentos, que alargan la petición sin evidencia de que ayuden.

**D5 · ¿Dónde se convierte en 503?** → En `app.onError` (global): error de D1 saturada → 503 `yala_unavailable` con `Retry-After: 2`; el resto sigue en 500.
Por qué: cubre también `/mail/drafts` (YALA-GATEWAY-2) sin tocar `src/mail/`, que está fuera de `toca:`. El webhook de App Store sigue recibiendo 5xx y Apple reintenta igual.

**D6 · Sentry** → Se sigue avisando, con nivel `warning` y huella única `d1-saturada` para que todas las rutas caigan en un solo issue.
Por qué: callarlo perdería la señal si la saturación se vuelve frecuente; un issue por ruta era ruido.

**D7 · Reintento en `/mail/drafts`** → No en este encargo (fuera de `toca:`); queda en «Encontrado».

**D8 · Despliegue** → Staging desde la Mini, sobre la base que ya corre verificada byte a byte + solo este parche. Producción, pasos para Dan.
