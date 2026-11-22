Yala
# Conector de Claude: poner al día la guía de producción y el SQL contra lo que hoy tiene producción
---
toca: mcp/RUNBOOK-produccion.md,mcp/README.md,mcp/CONECTAR-TU-IA.md,mcp/wrangler.toml,mcp/scripts/,mcp/sql/,webapp/supabase/sql_produccion.py,docs/propuestas/2026-11-22-conector-runbook/,tickets/backlog/2026-11-22-conector-mcp-runbook-produccion-al-dia.md,tickets/done/2026-11-22-conector-mcp-runbook-produccion-al-dia.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen autorizó el 22-nov (08:49 y 08:51 Lima, decisiones registradas) que Dan despliegue el conector de Claude en producción en https://mcp.yala-app.pe, con Google ya probado. El login con Apple lo prueba Jürgen directamente en producción. A las 09:15 dio el GO a esta sesión. Dan se frenó antes del paso 3 sin tocar producción porque `mcp/RUNBOOK-produccion.md` quedó desfasado desde que salió Yala web el 16-nov.

Esta sesión NO despliega ni escribe en producción. Deja la guía y el SQL correctos y verificados para que Dan los ejecute.

## Lo que Dan encontró (verifícalo, no lo des por hecho)
1. Producción ya tiene encendidos el servidor OAuth de Supabase y el hook de tokens, con Apple y Google (el id web primero) y el email apagado. `site_url` no lo usa ningún flujo. Los pasos de Auth (6 y 8) del runbook pueden sobrar o pisar la configuración de la web.
2. SQL del paso 5: los `mcp0_0*` abortarían por la guarda md5 y, si pasaran, borrarían el rol `yala_web`. Dan cree que lo correcto es regenerar el hook combinado (web3_02) con `webapp/supabase/sql_produccion.py <id-cliente-conector> <id-cliente-web>`, con la guarda md5 del hook vigente y la marcha atrás con el uuid nulo. Confírmalo leyendo los `webapp/supabase/*.sql` y `sql_produccion.py`, y deja un solo camino: un hook que reconozca al cliente web y al del conector sin borrar nada de la web.
3. Gateway: producción no tiene la migración 0004 ni `ConnectorDrafts`. Hoy, entre las 04:58 y las 05:12, se desplegó «Yala IA ampliada» al gateway desde la rama de «Cuenta sola», cuyo PR https://github.com/jur211296/Yala/pull/1115 está en auto-merge. El runbook tiene que decir el orden: el gateway se despliega desde 2.3 solo después de que entre ese PR. Si el conector se puede sacar primero solo de lectura (sin el binding `[[env.production.services]]`), documenta las dos variantes y recomienda una.
4. El cliente OAuth confidencial del conector se crea desde el dashboard de Supabase, porque no hay API sin la service role key. Wrangler en producción se usa desde la Max con la cuenta de Cloudflare de Yala (admin@yala-app.pe), no desde la Mini.

## Qué hacer
1. Reescribe `mcp/RUNBOOK-produccion.md` con el estado real de producción al 22-nov, paso a paso, solo con lo que falta. Cada paso lleva su comprobación y su marcha atrás.
2. Deja el SQL generado y probado: guárdalo en `mcp/sql/` o en un script, con guardas que aborten si producción no está como se espera. Pruébalo de punta a punta en staging (crear, verificar que la web sigue entrando, marcha atrás) con `webapp/supabase/ciclo_staging.py` o equivalente.
3. Si para confirmar algo de producción necesitas leer su configuración, hazlo solo en lectura y sin imprimir secretos. Si no tienes acceso, deja la comprobación como primer paso del runbook para Dan.
4. Deja un artifact visual de Claude (no Markdown) en `docs/propuestas/2026-11-22-conector-runbook/` con el antes y el después, el orden de los pasos y los riesgos, para que Dan y Jürgen lo lean rápido.

## Criterios de aceptación
- El runbook nuevo no borra ni cambia nada de lo que usa Yala web, y lo demuestra en staging.
- Queda claro qué hace Dan, en qué orden y qué depende del PR de «Cuenta sola».
- PR a 2.3 con auto-merge. Solo docs, scripts y SQL. Nada desplegado ni ejecutado en producción.

## Cómo trabajar
- Commits y PR sin firma de IA. No te saltes hooks.
- Si algo solo lo puede decidir Jürgen (por ejemplo, sacar el conector solo de lectura), deja tu recomendación y la pregunta en el cierre. No lo decidas por él.
- Termina con /cerrar-total cuando el PR haya entrado. Si te frena una decisión vital, sigue el modo de la sesión.

## Paso 0 — decisiones (resueltas en semi, por la sesión; medidas el 22-nov en solo lectura)

Medido en producción (Management API desde la Mini, solo lectura, sin secretos): hook md5 `7a703d85…` con el conector
nulo y la web `79c7e38e…`; roles `yala_mcp_reader` y `yala_web`; un único cliente OAuth («Yala web»); `pg_cron` 1.6.4
con solo el barrido de la web; Auth con servidor OAuth, hook, Apple y Google (id web primero) y email apagado;
`site_url = http://localhost:3000`; 0 factores MFA.

1. **SQL: un solo camino.** No `mcp0_0*` ni regenerar la cadena web: un script nuevo
   (`mcp/scripts/sql-conector-produccion.py`) deriva el hook de `web3_02` cambiando solo el id del conector (nulo →
   real), con guarda del md5 medido y del cliente registrado, más el barrido `mcp0_04` con el id real. Cada uno con su
   marcha atrás. Se descarta regenerar con `sql_produccion.py`: reaplica cuatro ficheros cuando cambia una función.
2. **`site_url` SÍ hace falta**: medido en staging, Supabase manda el navegador a `site_url + /oauth/consent` para
   cualquier cliente; la web lee solo el `authorization_id` y no le importa el host. Dan tenía razón en que hoy no lo usa
   nadie; el conector sí lo usa. El resto de Auth (pasos 6 y 8 viejos) ya está y no se toca.
3. **Gateway**: el PR de «Cuenta sola» ya entró en 2.3 (es la base de esta rama). Recomiendo la variante completa
   (gateway desde 2.3 con `0004` → conector con el binding); la de solo lectura queda documentada como plan B.
4. **MFA y avisos de cuenta**: fuera del camino crítico. Recomiendo apagar MFA (0 factores, nadie lo usa) como paso
   opcional; los avisos por correo quedan como pregunta a Jürgen (mandarían correos a usuarios).
5. **Prueba**: ensayo en staging en una transacción deshecha + ciclo real corto en staging (atrás → la web entra →
   adelante → la web y el conector entran → huella igual). Nada en producción.
6. **Artifact**: HTML en `docs/propuestas/2026-11-22-conector-runbook/`, publicado.
