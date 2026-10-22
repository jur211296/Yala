---
name: percent-eleccion-nube-alineado-con-prod
description: PR #128 — el repo ya no puede apagar la card born-cloud del Welcome en un deploy; desplegado y verificado en prod, y deja viva una ventana en que una card miente a la visita
metadata:
  type: project
---

**Paso 1 del rediseño de sesiones, cerrado y DESPLEGADO el 2026-09-10** (PR #128, merge `c4d5967a`).
`gateway/wrangler.toml` decía `CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT = "0"` mientras producción
servía 100, así que el siguiente `deploy` hecho por otro motivo habría apagado la card «Tu cuenta en
la nube» en todo el parque. Ya dicen lo mismo, comprobado con `curl` antes y después
(Version ID `e5f553f2`).

**Why:** es el único paso de la cola que tocaba producción de verdad. Los demás son código.

**How to apply:**

- **El deploy del gateway NUNCA es `wrangler deploy --env production` a pelo** — aunque un encargo lo
  pida. Va por `npm run deploy:production`: su `predeploy` copia los dos `*_capability_manifest.json`
  a `gateway/`, que **git ignora** y que `src/sync/manifest.ts` y `src/groups/manifest.ts` importan.
- **La consecuencia de producto ya está viva, y conviene tenerla presente al leer cualquier ticket
  del Welcome:** la card born-cloud **se ve en producción**. Todo comentario o ticket que diga «el
  sub-chooser no se muestra en prod» o «ese camino es el bypass de producción» describe el pasado.
  Nueve sitios corregidos; si aparece un décimo, es de esta familia.
- **Ventana abierta hasta el ticket 12:** `welcome.new.privateBody` promete «se sincronizan por tu
  iCloud privado», y en sesión secundaria (M1) eso es falso — el store va con
  `cloudKitDatabase: .none`. Antes casi nadie la leía porque el sub-chooser no salía; ahora sale.
  `welcome-private-card-promises-icloud-in-visit` está **descartado a propósito** (el ADR retira M1)
  y **no se reabre**: la ventana se cierra sola cuando el paso 12 retire M1.
- **Lo que el guard nuevo NO cubre:** fija el repo, no el gateway. Un cambio a mano desde el
  dashboard de Cloudflare no lo ve nadie. Y vive en la suite que ningún workflow ejecuta
  (`ci-no-corre-la-suite-del-gateway`), igual que la red anti-brick de `MIN_SUPPORTED_BUILD`.
- **`secondarySessionRolloutPercent` queda fuera del guard** por decisión de Jürgen: el ticket 12
  retira M1 y no se quiere tocar el test dos veces. Nadie lo vigila durante los pasos 1-11.

Deja tres tickets: dos enriquecidos (`ci-no-corre-la-suite-del-gateway`,
`gateway-typecheck-roto-y-fuera-del-ci`) y uno nuevo,
`sync-runtime-safety-note-assumes-every-prod-device-is-icloud` — el argumento que justifica tener el
motor de sync **encendido** dice «TODOS los devices en producción son `.icloud`», y con la card viva
ya puede ser falso.

Ver [[project_rediseno_sesiones_dos_ejes]] para el orden de la cola.
