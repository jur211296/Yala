Yala
# Construir «Conecta tu IA» (opción C): Ajustes, puertas, Bandeja con el nombre de la IA, listar y desconectar, y web del conector con marca
---
toca: Yala/App/Views/Settings/ConectaTuIA/,Yala/App/Logic/ConectaTuIA/,Yala/App/Views/Profile/ProfileView.swift,Yala/App/Views/Inbox/InboxView.swift,Yala/App/Logic/InboxDraftSourceName.swift,Yala/App/Logic/AIConnectorDraftLogic.swift,Yala/App/Views/Onboarding/PrimerosPasos/ConectaTuIAPuerta.swift,mcp/src/pages.ts,mcp/src/connections.ts,mcp/src/index.ts,mcp/test/conectaTuIA/,YalaTests/ConectaTuIA/,YalaUITests/ConectaTuIA/,tickets/backlog/2026-11-22-conecta-tu-ia-diseno.md,tickets/done/2026-11-22-conecta-tu-ia-diseno.md,tickets/backlog/claude-mcp-connected-apps-in-the-app.md,tickets/done/claude-mcp-connected-apps-in-the-app.md,tickets/backlog/mcp-consent-page-overflows-on-a-phone.md,tickets/done/mcp-consent-page-overflows-on-a-phone.md
esfuerzo: high
cierre: cierra-sola
---

Construye «Conecta tu IA» con la opción C de la maqueta (https://claude.ai/artifact/65CmVCQkr1JWd7JaFEXnRm, copia en `docs/diseno/conecta-tu-ia/index.html`). Lee primero `tickets/backlog/2026-11-22-conecta-tu-ia-diseno.md` (sección «Medido en 2.3») y `tickets/backlog/claude-mcp-connected-apps-in-the-app.md` (propuesta del servicio, decisión 1A del 5-nov).

## Decisiones de Jürgen (23-nov, t1919u), no las reabras
1. Opción **C**: casa en Ajustes (fila «Tu IA» junto a «Tu cuenta de Yala») y puertas desde Primeros pasos y la Bandeja vacía, con aviso si falta la nube.
2. **Gratis para todos**: leer y apuntar. No hay muro Pro.
3. **Todo junto**: listar y desconectar desde la app entra ahora, no en una fase 2. Construye el servicio del Worker: `GET /connections` y `DELETE /connections/<id>`, autenticados con el token normal de la app y nunca con uno del conector (`role = authenticated`, sin `client_id`).
4. **No** se guarda «última actividad»; basta el último borrador.
5. **Sin** página «Listo» en la web; tras iniciar sesión se vuelve directo a la IA.
6. En la Bandeja la etiqueta es **el nombre de la IA** («Claude», «ChatGPT», «Grok»), sacado de `evidence.client`, con «Tu IA» solo si no se conoce el nombre. Incluye el filtro «De tu IA».

## Web del conector (`mcp/src/pages.ts`)
Con la marca de la web: logo SVG dentro de la página; colores índigo, cian y rosa; tipografía servida por el Worker (`font-src 'self'`) o la del sistema. Usa los botones oficiales «Continuar con Apple» y «Continuar con Google» en claro y oscuro. Cubre las pantallas de permiso, inicio de sesión y error, sin «Listo». Respeta la CSP actual (`default-src 'none'`) y arregla que la página del permiso se salga de la pantalla en el celular (`mcp-consent-page-overflows-on-a-phone`).

## Orden
1. Servicio y web, con tests en `mcp/test/conectaTuIA/`, probados contra staging. **No despliegues a producción.** Al cerrar, deja la lista exacta de lo que Dan tiene que desplegar en el Worker de producción (mcp.yala-app.pe); el despliegue lo hace Dan con el OK de Jürgen.
2. App: Ajustes, puertas, Bandeja y filtro, y la lista con «Desconectar» contra el servicio. Revísalo en modo claro, modo oscuro y con el iPhone girado. Puede ser el mismo PR o dos, como convenga.
Si algo del `toca` no alcanza (por ejemplo, otro archivo de Ajustes), agrégalo y anótalo en el cierre.

## Pruebas
Antes de usar el simulador, comprueba si el iPhone 14 (DeviceMCP, conectado a la Mini) está libre. Si estás en la Max, puedes usar un segundo simulador. No des el iPhone por ocupado sin comprobarlo.

## Entregable visual
Al cerrar, entrega un artifact visual de Claude con capturas de las pantallas construidas (app y web, claro y oscuro), no un texto.

## Cierre
Commits y PR sin firma de IA. Espera el merge real en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. Si falta un acceso, una credencial o una decisión de seguridad, pregúntalo y no lo inventes. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones

> Modo semi. D1 la contestó Jürgen en el chat (10:05); el resto, la recomendación de Frank, se discute en el PR.

**D1 · Qué cierra «Desconectar» desde la app** → el grant del Worker y sus tokens: la IA deja de leer y de apuntar al
momento. La sesión de Supabase que llevaba dentro queda inservible y la borra el barrido diario en ≤31 días, como al
reconectar. (Jürgen: «Como al reconectar».)
Por qué: esa sesión solo se descifra con el refresh de la IA. Descartadas: retirar el permiso de Supabase al quitar la
última (abre una salida nueva del Worker) y una función en la base (cambio de esquema para lo mismo que hace el barrido).

**D2 · Quién puede llamar a `/connections`** → solo el token normal de la app: firma del JWKS, emisor, `aud` y
`role = authenticated`, `session_id`, y sin `client_id`. Un token de IA o de otro cliente recibe 401 igual que uno malo.
Por qué: lo pide la decisión 3. Alternativa descartada: comprobar además la sesión viva en `/user` (un viaje más por
llamada para un token que caduca en una hora).

**D3 · Qué devuelve cada fila** → `id`, `ia` («Claude», «ChatGPT», «Grok» o `null`, por la vuelta registrada),
`vuelta` (dominio), `local` y `conectadaEl`. Claves en español, como «Navegadores conectados».
Por qué: el nombre que el cliente se pone lo elige él; la vuelta es lo que lo identifica. Sin tokens ni ids de sesión.

**D4 · Límite de peticiones** → `/connections` va al cubo `RL_OAUTH` por IP. Por qué: no pide un binding nuevo ni
tocar `wrangler.toml`; el despliegue de Dan es solo código.

**D5 · Con qué conector habla la app** → Yala Dev con staging y Yala con `mcp.yala-app.pe`, como «Navegadores
conectados». Mientras producción no tenga el servicio, la lista dice que no pudo cargar y la página sigue sirviendo
para conectar.

**D6 · Dónde vive** → fila «Tu IA» en la tarjeta «Tu cuenta» de Ajustes, encima de «Tu cuenta de Yala», también sin
la nube (la página lo avisa). Fuera en la vista de solo grupos: el conector lee finanzas personales.

**D7 · La puerta de Primeros pasos** → una sexta manera, «Tu IA», al final del paso 7 («Anota sin abrir Yala»), solo
con los datos en la nube (sin ellos la IA no ve nada). Su «Enséñame cómo» enseña los pasos de conectar.
Por qué: el paso 7 ya es «otras formas de anotar» y la IA apunta en la Bandeja. Alternativa descartada: un paso nuevo
del mazo (mueve la numeración y el progreso de todos).

**D8 · La puerta de la Bandeja vacía** → en «Pendientes» vacío, una tarjeta «Conecta tu IA» que abre la misma página en
una hoja. Sale mientras no haya ningún borrador de una IA; sin la nube, la tarjeta igual (la página avisa).

**D9 · Filtro «De tu IA»** → un tercer chip en la Bandeja, solo si hay pendientes de una IA (o está elegido). Se
comporta como «Pendientes» (deslizar, guardar los listos) sobre ese subconjunto.

**D10 · Etiqueta** → la fila y el editor dicen el nombre de `evidence.client`; «Tu IA» si falta o no es uno conocido.

**D11 · Web** → tipografía del sistema (sin servir fuentes: la CSP no cambia), logo de Yala y logos de Apple y Google
en SVG dentro de la página, índigo/cian/rosa de la web, botones oficiales en claro y oscuro, y `box-sizing` arreglado.

**D12 · Textos nuevos de la app** → una tabla propia `ConectaTuIA.strings` en los 16 idiomas, leída como
`PrimerosPasosPaso7Text`.
