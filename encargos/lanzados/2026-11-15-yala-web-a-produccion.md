Yala
# Preparar la salida de Yala web a producción, con escritura en Grupos
---
toca: webapp/wrangler.toml, webapp/README.md, webapp/src/worker/, webapp/supabase/, Web/src/components/PrivacyPage.astro, Web/src/pages/privacy.astro, Web/src/pages/en/privacy.astro, Web/src/pages/pt/privacy.astro, Web/src/pages/fr/privacy.astro, Web/src/pages/it/privacy.astro, Web/src/pages/de/privacy.astro, docs/web-app/produccion/
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen decidió el 14-nov que la escritura en Grupos de Yala web pasa a producción, junto con toda la web (no sube sola). Hoy en producción NO hay nada: según webapp/README.md, cada lote dice «Producción: nada». No hay Worker, cliente OAuth, hook ni uri_allow_list, y faltan en producción los SQL web0_01, web1_01, web3_01 y web3_02 (cada uno ya tiene su rollback en webapp/supabase/).

## Qué hacer
1. Hacer un inventario exacto de lo que necesita producción: proyecto Supabase de producción (OAuth client, hook web, uri_allow_list, los cuatro SQL en orden), Worker de producción (wrangler.toml con entorno production, secretos por nombre, nunca valores), Turnstile real (config.ts rechaza claves de prueba en producción) y dominio.
2. Supabase producción: antes de aplicar, verificar que los cuatro SQL y sus rollbacks corren limpios en staging de punta a punta. Recién entonces aplicarlos en producción en orden, con respaldo o un punto de restauración verificado y la marcha atrás probada. Son cambios aditivos; si algo no es aditivo o toca datos existentes de la app, eso es decisión vital: no lo apliques y pregúntalo.
3. Worker: dejar listo el entorno production en wrangler.toml. Despliégalo solo si ya existen el widget real de Turnstile y el dominio. Si faltan, déjalo listo y documentado sin desplegar.
4. Política de privacidad (Web/, los seis idiomas): agregar que la web guarda la sesión, el navegador y la ciudad aproximada. Ojo: la web pública en Vercel sigue la rama 1.0, así que deja indicado el cherry-pick a 1.0, que es necesario para que se publique.
5. Dominio: app.yala-app.pe hoy exige mover el DNS de yala-app.pe de RCP a Cloudflare, y ese dominio también sirve la web pública desde Vercel. Prepara las opciones (mover la zona completa con los registros de Vercel replicados, un subdominio alternativo, workers.dev temporal u otra que encuentres) con riesgos, tiempo de caída y una recomendación.
6. Pasos de paneles (crear el widget de Turnstile y cambiar el DNS/nameservers): no los hagas tú. Déjalos como checklist exacta para Dan (URL, cuenta y objetivo), con una card asignada a Jürgen «Espera decisión» para el dominio y el OK de esos pasos.
7. Actualizar webapp/README.md con el estado real de producción de cada lote.

## Entregable
Un artifact visual de Claude (no Markdown ni PDF) en docs/web-app/produccion/ con lo siguiente: qué quedó en producción, qué falta, las opciones de dominio para elegir y la checklist para Dan. Fuente en ese mismo directorio.

## Reglas
- No se tocan datos de usuarios. Nunca imprimas secretos.
- Commits y PR sin firma de IA. PR contra 2.3.
- No te saltes pasos ni inventes acceso. Si te falta una credencial de producción, pídela (pregunta viva en semi; checkpoint en nocturno).
- Cierre: /cerrar-total si queda completo dentro de lo que se puede hacer sin los pasos de paneles; esos quedan en la card para Jürgen/Dan.
- Si hace falta probar la web, puedes usar un segundo simulador o el iPhone 14 por DeviceMCP.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (2026-11-15, Management API, solo lectura): Supabase producción (`kefvaiymtgytemwbltlz`)
no tiene rol `yala_mcp_reader`, ni hook de token (`hook_custom_access_token_enabled = false`), ni servidor OAuth
(`oauth_server_enabled = false`, 0 clientes), ni `pg_cron`, ni el Services ID web de Apple ni el cliente web de Google
en sus proveedores. El gateway de producción no declara `WEB_GROUPS_READER` ni `WEB_GROUPS_WRITER`. El conector de
Claude, que pone esa base, sigue «listo, sin desplegar» (`mcp/RUNBOOK-produccion.md`, «lo despliega Jürgen; nadie más»).

**D1 · ¿Se aplican los cuatro SQL en producción esta noche?** → No. Es decisión vital y va a checkpoint nocturno.
Por qué: los cuatro presuponen la base del conector (mcp0_01–03) y su guarda aborta sin ella; y para que sirvan hay que
encender en el Auth de producción el hook de token, que corre en CADA login y refresh de la app: un fallo ahí deja sin
entrar a todos los usuarios. Eso no es aditivo frente a la app, que es justo el caso que el encargo manda preguntar.
Alternativa descartada: aplicar solo los SQL sin encender el hook (fallan en su guarda; y forzarla sería aplicar DDL
sin el estado que la valida).

**D2 · ¿Cómo se prueban los SQL y sus marchas atrás en staging sin tumbar staging?** → En una sola transacción que se
deshace al final (`webapp/supabase/ciclo_staging.py`): huella del estado, las cuatro marchas atrás, comprobación del
estado previo a la web, los cuatro SQL, comprobación de que la huella vuelve a ser la misma, y un RAISE que lo deshace.
Por qué: prueba el camino entero sin dejar staging sin web ni un segundo. Alternativa descartada: marcha atrás y
reaplicar de verdad (deja una ventana con la web de staging rota y no prueba nada más).

**D3 · ¿Cómo quedan listos los SQL para producción?** → Un generador (`webapp/supabase/sql_produccion.py`) que cambia
los ids de staging por los de producción y recalcula cada guarda md5, con `--verificar` contra los md5 medidos en
staging. Molde: `mcp/scripts/sql-produccion.py`. Por qué: los ids van dentro del cuerpo del hook y cambian su md5, así
que a mano las guardas abortarían. No toca ninguna base.

**D4 · ¿Se crean recursos de Cloudflare de producción (KV) esta noche?** → No: `[env.production]` queda con
`PENDIENTE-…` donde falta un id, como el conector. Por qué: el Worker no se despliega sin Turnstile ni dominio, y el
paso se hace junto al despliegue con el comando exacto escrito. `config.ts` ya devuelve 503 a todo con un PENDIENTE.

**D5 · ¿Se despliega el Worker?** → No: faltan el widget real de Turnstile, el dominio y la base de Supabase.

**D6 · ¿Se toca el gateway (los dos interruptores de Grupos de la web en producción)?** → No: queda como paso del
encendido. Por qué: `gateway/` no está en el `toca:` de este encargo y encenderlos sin la web desplegada no sirve.

**D7 · Política de privacidad** → se agrega en los seis idiomas (es, en, pt, fr, it, de) en `Web/`, con PR a `2.3` y
el cherry-pick a `1.0` indicado en el PR y en la card. Por qué: Vercel publica desde `1.0`.

**D8 · Dominio** → se recomienda en el artifact; lo elige Jürgen en la card «Espera decisión». El checklist de paneles
(Turnstile y DNS) va para Dan.

**D9 · Cierre** → `checkpoint_nocturno.py preservar` (PR en borrador, sin merge) por D1, no `/cerrar-total`.
