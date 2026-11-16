Yala
# Subir Yala web a producción en app.yala-app.pe para que Jürgen la pruebe con su cuenta personal
---
toca: webapp/wrangler.toml, webapp/README.md, webapp/src/worker/, webapp/supabase/, webapp/test/, gateway/wrangler.toml, docs/web-app/produccion/, tickets/done/2026-11-16-yala-web-produccion-subir.md
esfuerzo: high
cierre: cierra-sola
---
Encargo autorizado por Jürgen el 16-nov en el chat: «podemos ir subiéndolo y lo voy probando con mi cuenta personal. Aún no lo enlazamos a la web principal». Continuación del PR #984 «Yala web a producción: preparado y probado, espera decisión» (rama `encargo/2026-11-15-yala-web-a-produccion`, informe https://claude.ai/artifact/ARVRr2bc6MSfxsVLYD3vHi). Las decisiones que esperaba ya están tomadas (docs/DECISIONS.md, lote del 15-nov): dominio `app.yala-app.pe`; OK a encender en Supabase Production el hook de token del login y a aplicar los SQL de Yala web; la escritura en Grupos sube junto con toda la web; el arreglo de Grupos y del móvil (#988) ya está en 2.3.

Qué hacer:
1. Poner al día el PR #984 con origin/2.3 y regenerar los SQL de producción desde 2.3 con `sql_produccion.py`. Repetir el ciclo en staging y la simulación de producción.
2. Supabase Production: con respaldo o punto de restauración verificado y la marcha atrás probada, aplicar los SQL en orden y encender el hook de token. Verifica justo después que el login de la app iOS publicada sigue funcionando (una cuenta de prueba en el iPhone 14 o el simulador con la build de producción). Si algo no es aditivo o falla el login, marcha atrás inmediata y `BLOQUEANTE:`.
3. Cliente OAuth y URLs de vuelta de producción en Supabase; gateway de producción con la lectura y escritura de Grupos de la web encendidas (solo `gateway/wrangler.toml`; si hace falta código del gateway, anótalo y no lo toques).
4. Worker en `app.yala-app.pe` como dominio propio (el DNS ya está en Cloudflare). No enlazarlo desde la web pública ni tocar `Web/`.
5. Pasos de panel que no puedes hacer tú (widget real de Turnstile, añadir `app.yala-app.pe` al Services ID de Apple `pe.yala.app.web`, URL de vuelta en el cliente web de Google de `yala-502622`): déjalos como checklist exacta (URL, cuenta y objetivo) para Dan, avisa con `BLOQUEANTE:` y sigue lo posible. Cuando estén, despliega el Worker y prueba de punta a punta.
6. Mergear el PR cuando producción esté arriba y verificado, y actualizar `webapp/README.md` con el estado real.

Prueba final: entrar en https://app.yala-app.pe con Apple y con Google en una cuenta de prueba de la nube de producción, ver el mismo saldo que en el iPhone y apuntar un borrador. Deja indicado qué falta para que la app publicada recoja lo apuntado en la web (es de la 2.3 del iPhone, fuera de este encargo).

## Reglas
- Nunca imprimas secretos; ponlos por nombre. No toques datos de usuarios.
- Commits y PR sin firma de IA. PR contra 2.3.
- No te saltes pasos ni inventes acceso; credencial que falte, pregunta viva en semi o checkpoint en nocturno. En nocturno no apliques nada en producción: checkpoint con card «Espera decisión».
- Puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP.
- Entrega visual: artifact de Claude con qué quedó en producción, la prueba y lo que falta.
- Cierre según el modo fijado al arrancar: semi con trabajo completo, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar» (con motivo o «Nada»).

## Paso 0 — decisiones (resueltas por Frank, modo semi)

1. **PR.** La rama de este encargo trae los commits del PR de la sesión del 15-nov (merge limpio) más 2.3. Se abre un PR
   nuevo contra 2.3 y el del 15-nov se cierra apuntando a él: el cierre de esta sesión trabaja sobre su propia rama, y la
   del 15-nov sigue montada en otro worktree.
2. **Producción de Supabase se prueba antes de tocarla.** La cadena entera (conector con id nulo + los cuatro SQL de la
   web y sus marchas atrás) se corre primero en producción dentro de una sola transacción que termina en RAISE: valida
   contra la base real (sin `pg_cron`, sin conector) sin dejar nada. Solo si cuadra, se aplica paso a paso.
3. **Respaldo.** Los SQL cambian roles, funciones, permisos y políticas, no datos. Respaldo = copia de seguridad diaria de
   Supabase verificada + foto de la config de Auth (guardada en la Mini, no en el repo) + las marchas atrás probadas en
   el paso 2. Si el plan no tiene copia reciente, se pregunta.
4. **El conector de Claude no sale a producción.** Su id va como uuid nulo en el hook (como planeó el 15-nov).
5. **Login de la app tras encender el hook:** llamada directa al hook con un evento de la app (debe devolver los claims
   tal cual), login real con una cuenta de prueba creada en producción para esto, y lectura de los logs de Auth. Si
   algo falla: apagar el hook (un cambio de config) y marchas atrás, `BLOQUEANTE:`.
6. **Gateway:** solo `gateway/wrangler.toml` (`WEB_GROUPS_READER`/`WRITER = "on"` en producción). Antes de desplegar se
   mide qué corre hoy en producción frente a 2.3; desplegar desde 2.3 es lo que decidieron el 14 y el 15-nov.
7. **Turnstile:** se intenta por la API con los accesos que hay; si no alcanza, va a la checklist de Dan.
8. **Lo que añada el arreglo de Grupos de 2.3 a los SQL** (función `web_member_ref`) también lo retira su marcha atrás:
   lo cazó el ciclo de staging y se corrige aquí.
