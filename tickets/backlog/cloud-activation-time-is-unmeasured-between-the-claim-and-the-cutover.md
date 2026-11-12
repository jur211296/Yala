---
id: cloud-activation-time-is-unmeasured-between-the-claim-and-the-cutover
status: backlog
priority: medium
area: "modo-nube, telemetría"
created: 2026-10-23
updated: 2026-10-23
source: "encargo 2026-10-23 activar-la-nube-progreso-2-2 (cards ppxk, igt9, 27z3)"
---

# «Activar la nube» con pocos datos tarda minutos y todavía no sabemos en qué paso

## En lenguaje de usuario

Con 5 movimientos, activar la nube tardó 9 min y medio en producción (TF19) y entre 2 y 7 min en staging. La pantalla ya
dice qué hace en cada momento (opción B), pero el tiempo en sí no se ha podido medir por paso.

## Lo medido (Analytics Engine, hora del servidor)

- TF19, 20-oct: consentimiento 21:37:42 · claim 21:37:47 · **ni un evento hasta 21:46:45** · cutover 21:47:17.
- Staging, 20-oct: 13:36:36 → 13:38:51 y 21:57:05 → 22:03:59, con el mismo hueco mudo antes del primer export.
- El primer export del espejo llega justo antes del corte: hasta ese momento el teléfono no escribió nada en el store
  personal que iCloud subiera.

## Hipótesis (INFERIDAS, sin medir)

1. **La espera al import de iCloud** (pre-espera de 300 s + 120 s del runner por entrada). Si es esto, el canario nuevo
   `cloudMigrationImportWaited` lo dirá.
2. **La subida cuenta todas las filas, no solo movimientos**: un teléfono con años de tipos de cambio (una fila por día) o
   duplicados de restauraciones sube cientos o miles de filas. El comentario de `SyncPushClient` midió ~300 ms por delta en
   el Worker en julio; con 1.000 filas serían 5 min. Si es esto, `cloudMigrationStep upload>verify` lo dirá, y la decisión
   sería de producto (¿hace falta subir todo el histórico de tipos de cambio en la activación?).

## Siguiente paso

Una activación en iPhone con el build que lleva los canarios `cloudMigrationStep` y `cloudMigrationImportWaited`, y leer la
serie de esa instalación. Con eso se elige qué atacar; no antes.
