---
id: import-of-thousands-of-rows-in-cloud-mode-is-unmeasured
status: done
priority: medium
area: "import, cloud"
created: 2026-10-29
updated: 2026-11-22
source: "auditoría del import 2.2 (sesión S27j), H15 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Un import de miles de filas en modo nube no está medido

**Versión propuesta: 2.4.** Media (integridad de datos en la nube, tema 2.4). La decide Jürgen. Card: `2u45`.

## Qué ve el usuario

Desconocido: cuánto tarda en llegar a otra instalación, si la subida trocea, qué pasa con un Deshacer de 3.000 borrados.

## Evidencia

El import no distingue modo nube de iCloud privado: guarda en local y sincroniza después (historial que drena `CloudSyncEngine`, deltas de `DeltaEmitter`). Es un solo guardado con miles de inserciones; no encontré troceo pensado para ese caso ni telemetría de su duración. Relacionado: `debounce-sync-imported-transactions`.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H15.

## Propuesta

Medir en `Yala Dev` contra staging: 3.000 filas, tiempo hasta verlas en la otra instalación, tamaño de los lotes, reintentos. Repetir con el Deshacer de `import-cannot-be-undone`.

## Criterio de hecho

- [ ] Medición escrita en el ticket.
- [ ] Si algo falla o tarda más de lo razonable, su ticket propio.

## Hecho (2026-11-22, lote 1 de Importar registros)

Medido contra STAGING con el arnés de `CloudSyncE2EStagingTests` (usuario sintético A, dos stores en disco en el
simulador: A importa, drena y sube; B, que ya estaba al día, baja). Test `ImportarLote1NubeStagingTests`, gateado con
`YALA_CLOUD_E2E=1` + contraseña. Producción no se tocó.

Corrida del 2026-11-22, 3.000 filas, simulador en la Mac mini (Lima) contra el Worker y el Supabase de staging:

| Paso | Tiempo |
|---|---|
| Poner al día el dispositivo B antes (todo el corpus del usuario A) | 9,6 s |
| Importar en A (store en disco) | 2,9 s |
| Drenar y subir desde A: 3.003 filas (movimientos, la cuenta y la categoría) en 61 peticiones de 50 | **409 s (~6,8 min)** |
| Bajar en B: 7 páginas de 500 | 9,3 s |
| Deshacer en A, por tandas de 100 | 8,0 s |
| Drenar y subir los 3.000 borrados | **391 s (~6,5 min)** |
| Bajar los borrados en B: 6 páginas | 15,8 s |

La otra instalación ve las 3.000 filas en cuanto baja, y deja de verlas tras el deshacer. Lo lento es la SUBIDA: ~6,7 s por
petición de 50 filas. Ticket propio: `cloud-upload-of-thousands-of-rows-takes-minutes`.


- La subida trocea: 50 filas por petición (`SyncPushClient.pushChunkSize`), así que 3.000 filas son ~60 peticiones; la
  bajada, páginas de 500. Sin reintentos en la corrida.
- B ve las 3.000 filas, y tras «Deshacer» en A deja de verlas: el borrado viaja como cualquier otro.

- [x] Medición escrita en el ticket.
- [x] Si algo falla o tarda más de lo razonable, su ticket propio: ver «Encontrado» en el PR.
