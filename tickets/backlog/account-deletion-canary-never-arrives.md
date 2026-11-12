---
id: account-deletion-canary-never-arrives
status: backlog
area: metrics
priority: medium
created: 2026-10-28
updated: 2026-10-28
source: S12h (card pet5) — telemetría del 27-oct
---

# El canario de «Eliminar cuenta» casi nunca llega

## Qué pasa (medido)

`accountDeletionCompleted` ha llegado **una sola vez** a `yala_metrics` en los 90 días de retención (19-oct, `cloud`),
y `accountDeletionFailed` ninguna. El 27-oct Jürgen eliminó su cuenta al menos una vez entre las 20:55 y las 20:56
(Lima): Supabase prod tiene la cuenta nueva creada a las 21:05 y su membresía vieja de «matri» anonimizada, y su
instalación (`bf3f7909`) siguió enviando canarios antes y después. El de borrado no llegó.

## Hipótesis (sin medir)

`MetricsService.accountDeletionCompleted` encola en el spool (`UserDefaults`) justo antes del cierre local, que en
`.cloud` hace el cambio de contenedor en caliente o relanza. Algo en ese camino descarta o no drena el spool. El
barrido de preferencias (`removeUserPreferenceKeys`) no toca `metrics.*`, así que no es eso.

## Por qué importa

Sin este canario no se puede fechar un borrado de cuenta en un incidente ni contar cuántos hay.
