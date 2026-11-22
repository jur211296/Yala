Yala
# Encender Yala IA ampliada en producción, conector en mcp.yala-app.pe y navegadores conectados en la app publicada
---
toca: gateway/src/connector/,gateway/src/ai/,gateway/wrangler.toml,gateway/RUNBOOK.md,Yala/App/Views/ConnectedBrowsers/,Yala/App/Views/Profile/YalaAccountView.swift,gateway/test/ProduccionIaConector/,tickets/backlog/2026-11-21-ia-ampliada-produccion-navegadores-publicada.md,tickets/done/2026-11-21-ia-ampliada-produccion-navegadores-publicada.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen dio OK explícito de producción el 21-nov a las 08:39 (Lima), decisión t1868-reconfirma, para este encargo. Decisiones de la auditoría `docs/auditorias/2026-11-21-decisiones-vs-2-3.md`:
- 14 (t1503u-ia-ampliada): «Yala IA ampliada: encender en producción apenas la 2.2 esté publicada». Hoy está al 0 %.
- 64 (t1656u-dominio): «El conector MCP sale a producción en mcp.yala-app.pe (el conector de pruebas pasa a otro nombre); después despliega Dan».
- 42 y 51: Yala web como un dispositivo más en modo nube; «aprueba las opciones recomendadas en las 13 decisiones de la maqueta». Los navegadores conectados hoy solo funcionan en Yala Dev (`ConnectedBrowsersConfig.isAvailable`).
Cards: «Encender Yala IA ampliada en la nube (staging → producción)» y «Endurecer el conector MCP en producción…»; reutilízalas.

## Qué hacer
1. Lee `gateway/RUNBOOK.md` y define el plan escalonado: porcentajes (por ejemplo 1 %, 10 %, 50 %, 100 %), con la verificación entre cada paso (errores, latencia, costo de tokens).
2. Antes de encender nada, escribe cómo volver atrás (bajar el porcentaje a 0 % o revertir el despliegue) y pruébalo en staging.
3. Enciende Yala IA ampliada en producción empezando por el porcentaje más bajo; avanza solo si la verificación sale limpia. Deja el porcentaje final y la evidencia en el artifact.
4. Lleva el conector MCP a mcp.yala-app.pe y renombra el de pruebas; verifica con una llamada real.
5. Activa los navegadores conectados en la app publicada (que dejen de depender de Yala Dev), con pruebas.
6. Los secretos se leen del Llavero o de `~/Secrets`, nunca se imprimen ni se escriben. Las consolas y el navegador solo a través de Dan, si hiciera falta.

## Criterios de aceptación
- Yala IA ampliada encendida en producción con el porcentaje final documentado y la forma de revertir probada.
- `mcp.yala-app.pe` responde y el conector funciona de punta a punta.
- Los navegadores conectados aparecen y funcionan en la app publicada.
- Verificación en producción incluida en el artifact; `tests`, `coverage-index` y `gateway` en verde.

Autorización: OK de producción de Jürgen, 21-nov 08:39 Lima. Sin gastos nuevos; si algo cuesta dinero, detente y déjalo propuesto.

## Cómo verificar y entregar
- Puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP.
- Capturas antes y después en el cierre.
- La entrega visual se hace como artifact de Claude.
- Trabajo solo en tu rama de encargo; no toques archivos que no estén en `toca:`.

Índices compartidos: `docs/TICKETS.md` y `qa/coverage-index.json` no van en `toca:`; edítalos solo al final, justo antes del PR, tras `git rebase origin/2.3`, resolviendo por fila o área sin pisar lo de otra sesión.

Termina con /cerrar-total cuando el PR esté dentro de 2.3.
## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (22-nov, 04:50–05:10 Lima): el DNS de `yala-app.pe` ya está en Cloudflare;
`mcp.yala-app.pe` es hoy un dominio propio del Worker **de staging** del conector; el Worker de producción del conector
no existe (1042) y en la Mini no hay `~/Secrets/yala-mcp-production/` (ni cliente OAuth ni cuenta de prueba de
producción). El gateway de producción corre la versión `86849564`, hecha con un parche sin commit de la sesión
pausada de «cuenta sola». Tráfico de IA en producción: 5–10 llamadas al día y ninguna de chat en 7 días. La 2.2
publicada ya trae `chat.explore` con su consentimiento. La web de producción (`app.yala-app.pe`) ya sirve
`/api/dispositivo/*`. El iPhone 14 está bloqueado (pide a Jürgen).

**D1 · ¿Cómo se cambia el porcentaje de la IA ampliada en producción sin subir código ajeno?** → Solo la variable,
sobre la versión que ya corre, con la API de ajustes de Cloudflare (bindings heredados, mismo código).
Por qué: producción corre un parche que no está en ningún commit; desplegar desde 2.3 o desde mi rama le cambiaría
el código. Alternativa descartada: `npm run deploy:production` desde la rama (arrastra lo pendiente del RUNBOOK).

**D2 · ¿Cómo se vuelve atrás?** → La misma llamada con 0 (corte inmediato en el gateway: `exploreEnabled` mira > 0) y,
si hiciera falta código, `wrangler rollback` a la versión anterior. Probado en staging antes de tocar producción.

**D3 · ¿Escalones con espera de días?** → 1 → 10 → 50 → 100 en esta sesión, con verificación entre cada uno
(`/config`, humo del gateway, errores y tokens en Analytics Engine) y una medición real de `chat.explore` en staging.
Por qué: con ~0 llamadas de chat al día, esperar días por escalón no da datos; el riesgo de coste está acotado por
los topes por pregunta (3 rondas, 4 herramientas) y la cuota de chat. Alternativa descartada: dejarlo en 10 % y
abrir otra sesión (no añade evidencia).

**D4 · ¿El conector a producción en `mcp.yala-app.pe` esta noche?** → Se prepara entero (configuración de producción
con el dominio, KV creado, runbook al día) y se renombra el de pruebas a `mcp-staging.yala-app.pe`; el alta en
Supabase producción (cliente OAuth, rol, hook, Auth) y el despliegue quedan para Dan, como dice la propia decisión 64
(«después despliega Dan»).
Por qué: el encargo prohíbe tocar Supabase de producción («Nada en producción, ni CloudKit ni Supabase»), las consolas
van solo por Dan, y «una llamada real» exige un inicio de sesión con Apple o Google en el navegador. Alternativa
descartada: hacer el DDL del hook de acceso en producción (si falla, cae todo inicio de sesión de la app).

**D5 · Nombre del conector de pruebas** → `mcp-staging.yala-app.pe` (el repo llama «staging» a ese entorno en los tres
Workers). Menor y reversible.

**D6 · Navegadores conectados en la app publicada** → `ConnectedBrowsersConfig.baseURL` apunta a `app.yala-app.pe`
fuera de Yala Dev; Yala Dev sigue con staging. Se toca `Yala/Services/ConnectedBrowsers/ConnectedBrowsersClient.swift`,
fuera de `toca:` pero es donde vive la única condición que ata la fila a Yala Dev. Test nuevo contra
`webapp/wrangler.toml` para que la dirección no derive. Llega a los usuarios con la 2.3: un binario publicado no cambia.

**D7 · Ficheros fuera de `toca:`** → `mcp/wrangler.toml`, `mcp/RUNBOOK-produccion.md`, `mcp/CONECTAR-TU-IA.md`
(el conector vive en `mcp/`, no en `gateway/src/connector/`), `gateway/test/config.test.ts` (fija el porcentaje de
producción) y el test nuevo en `YalaTests/`. Ninguna otra sesión los toca (`turno_merge.py ver`).
