---
id: cloud-activation-time-is-unmeasured-between-the-claim-and-the-cutover
status: backlog
priority: medium
area: "modo-nube, telemetría"
created: 2026-10-23
updated: 2026-11-05
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

## Instrumentación lista (2026-11-05, lote N9)

Lo que una sola activación en un iPhone deja en Analytics Engine (`blob1 = canary`, `blob2` = nombre, `blob3` = detalle,
`double1` = valor, `index1` = instalación), filtrando por la instalación del teléfono:

| Canario | `detail` | `x` | Responde |
|---|---|---|---|
| `cloudMigrationStep` (ya estaba) | `<de>><a>` | segundos del paso que se deja (-1 si empezó en otro proceso) | qué paso se lleva el tiempo |
| `cloudMigrationImportWaited` (ya estaba) | `<preWait\|runner>\|<settled\|cut\|cap>` | segundos esperados | hipótesis 1: la espera al import de iCloud |
| `cloudSnapshotPageUploaded` (**nuevo**) | `<tabla>\|<filas de la página>` | segundos de la página, de encolar a confirmar | hipótesis 2: si `upload>verify` es largo, qué tabla y cuántas filas |

- Lectura: ordenar los `cloudMigrationStep` por hora; si el largo es `identity>upload` o antes, mirar
  `cloudMigrationImportWaited`; si es `upload>verify`, sumar `cloudSnapshotPageUploaded` por tabla (filas y segundos).
  Páginas de 200 filas: una tabla de 1.000 tipos de cambio son 5 eventos.
- Los segundos son del reloj del TELÉFONO (`x`), no del servidor: valen aunque el evento llegue tarde por la cola.
- Con la cola de métricas llena, un envío ya no se lleva canarios que no salieron (mismo lote): la serie no tiene huecos
  por eso.
- Falta solo la medida: un build con este código (TestFlight o `Yala Dev` contra staging) y una activación con pocos
  datos. La decide y la hace Jürgen; no se pidió desde esta sesión.
