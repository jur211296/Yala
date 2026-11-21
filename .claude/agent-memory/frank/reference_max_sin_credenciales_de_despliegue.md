---
name: max-sin-credenciales-de-despliegue
description: En la Max no hay PAT de la Management API de Supabase ni token de cktool; migraciones y schema de iCloud no se aplican desde ahí
metadata:
  type: reference
---

Medido el 2026-11-21 (encargo de límites del flujo de caja con pagos y moneda): en la Max **no existe**
`~/Secrets/yala-supabase-mgmt/pat` (los `qa/cloud/gNN-remote.sh` no corren) y `xcrun cktool get-teams` responde
«No management token found». En la Mini tampoco había token de cktool (medido el 2026-10-22).

**Cómo aplicarlo:** una columna nueva del Modo Nube o un campo nuevo de iCloud lanzado en la Max se deja con su SQL en
`qa/cloud/` y los pasos de consola en `docs/despliegue-cloudkit-2-2.md`, y va a «Necesita de ti» + card «Espera
decisión». El cliente es seguro mientras tanto: declara la menor versión con el Worker. Ver [[credencial-pendiente-se-aparca]].
