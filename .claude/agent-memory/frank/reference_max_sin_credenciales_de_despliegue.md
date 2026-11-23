---
name: max-sin-credenciales-de-despliegue
description: En la Max no hay PAT de Supabase, token de cktool ni sesión de Wrangler; migraciones (Supabase y D1), schema de iCloud y deploy del gateway no salen de ahí
metadata:
  type: reference
---

Medido el 2026-11-21 (encargo de límites del flujo de caja con pagos y moneda): en la Max **no existe**
`~/Secrets/yala-supabase-mgmt/pat` (los `qa/cloud/gNN-remote.sh` no corren) y `xcrun cktool get-teams` responde
«No management token found». En la Mini tampoco había token de cktool (medido el 2026-10-22).

**Cómo aplicarlo:** una columna nueva del Modo Nube o un campo nuevo de iCloud lanzado en la Max se deja con su SQL en
`qa/cloud/` y los pasos de consola en `docs/despliegue-cloudkit-2-2.md`, y va a «Necesita de ti» + card «Espera
decisión». El cliente es seguro mientras tanto: declara la menor versión con el Worker. Ver [[credencial-pendiente-se-aparca]].

**Y tampoco Wrangler (medido el 2026-11-22, «Comercios en común»):** `npx wrangler whoami` → «You are not
authenticated», sin `CLOUDFLARE_*` ni nada en `~/Secrets`. Migrar D1 o desplegar el gateway de STAGING tampoco sale de la
Max: se pregunta una vez al bot (login de Jürgen, Dan, o la Mini) y se sigue con `gateway/test/` (`node:sqlite` prueba el
SQL de verdad). El `node_modules` del gateway no viene en el worktree: `npm ci`, ~1 min.
