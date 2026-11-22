---
id: 2026-11-22-conector-mcp-runbook-produccion-al-dia
status: done
priority: high
area: "conector, mcp, supabase, producción"
created: 2026-11-22
updated: 2026-11-22
source: "encargo 2026-11-22-conector-mcp-runbook-produccion-al-dia (Dan se frenó antes del paso 3)"
---

## Qué se pidió

Poner al día `mcp/RUNBOOK-produccion.md` y el SQL del conector contra lo que producción tiene desde Yala web (16-nov),
sin desplegar ni escribir en producción, para que Dan lo ejecute.

## Hecho

- **Medido en producción, solo lectura:** hook md5 `7a703d85…` (web3_02 con el conector nulo y la web `79c7e38e…`),
  roles `yala_mcp_reader` y `yala_web`, un único cliente OAuth, `pg_cron` con el barrido de la web, Auth con servidor OAuth,
  hook, Apple y Google (web primero) y email apagado, `site_url = http://localhost:3000`, 0 factores MFA.
- **`mcp/scripts/sql-conector-produccion.py`**: genera `conector01` (el hook vigente con el id real del conector) y
  `conector02` (el barrido `mcp0_04` con ese id), con marchas atrás, guardas (md5 medido, roles, cliente web, cliente del
  conector confidencial con la vuelta de producción) y comprobación final. Modos `estado` (lectura), `ensayo`
  (transacción deshecha), `aplicar` (una transacción) y `ensayo-staging`.
- **`mcp/RUNBOOK-produccion.md` reescrito**: pasos 0-7 con comprobación y marcha atrás; variante completa recomendada y
  la de solo lectura como plan B; `site_url` sí hace falta (medido); lo que ya no se hace.
- `mcp/scripts/sql-produccion.py` deja de servir para producción (pide `--historico`); `webapp/supabase/sql_produccion.py`
  dice que se aplicó el 16-nov.
- Artifact: https://claude.ai/artifact/3m5SxX9tBpiVWVambRwUeZ (`docs/propuestas/2026-11-22-conector-runbook/`).

## Probado

- `ensayo-staging`: 12/12 en una transacción deshecha (forma de producción → SQL → atrás → otra vez; negativos).
- Ciclo real en staging (09:24:40–09:25:08 Lima): sin conector, e2e de Yala web 8/8 y el conector rechazado; con el SQL,
  web 8/8 y e2e del conector 18/19 (el rojo cuenta 6 herramientas y hay 7: ajeno). Huella final igual a la de partida.
- `mcp`: 303/303 tests y typecheck.

## Pendiente (de Dan y Jürgen)

- Dan ejecuta el runbook. El id del cliente en `mcp/wrangler.toml` vuelve a 2.3 en un PR de una línea.
- Jürgen: variante completa o solo lectura (recomendada la completa); avisos por correo de cuenta (sí/no).
