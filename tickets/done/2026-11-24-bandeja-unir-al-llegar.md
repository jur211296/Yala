---
id: 2026-11-24-bandeja-unir-al-llegar
status: done
area: "bandeja, apple pay, correo del banco, aviso del banco, yala web, conector de IA, sync"
created: 2026-11-24
updated: 2026-11-24
source: "Jürgen, 24-nov (14:30 y 14:32 Lima): «vamos con todo lo recomendado» de docs/propuestas/bandeja-sin-duplicados/README.md (opción B). Lote 2 del plan, en 2.3"
---

# Bandeja: unir al llegar, con «Separar» (lote 2)

## Qué se pidió
Cablear el emparejador del lote 1 al llegar cada borrador de Apple Pay, el aviso del banco, el correo del banco, Yala
web y tu IA; recordar lo unido en un campo sincronizado (SwiftData, iCloud y la nube, con su marcha atrás); y «Separar»
en el borrador. Que una base de 2.2 migre sin perder borradores.

## Qué cambia para la persona
- El mismo consumo que llega por Apple Pay, el aviso y el correo del banco es UN pendiente en la Bandeja, no tres.
  Toma el importe del banco, la hora exacta y el nombre limpio de Apple Pay.
- Dos compras iguales por la misma fuente siguen siendo dos (dos cafés por Apple Pay son dos cafés).
- Solo se une lo que coincide con seguridad (misma cuenta o mismos últimos 4, mismo importe ±0,01, mismo día). Lo
  dudoso entra como hoy, pendiente aparte: preguntarlo es el lote 3.
- En el borrador unido sale «Juntamos el mismo gasto: Apple Pay · Correo del banco» con **Separar**: cada fuente vuelve
  como pendiente tal como llegó, y lo que la persona editó después de unir se queda.
- Grupos y cuentas compartidas, fuera (decisión 7).

## Qué se tocó
- `InboxDraft.joinRecordRaw` (JSON de `InboxJoinRecord`): lo absorbido y los valores antes y después de unir.
- `InboxArrivalJoin` (punto común, antes del guardado de cada fuente; si el guardado falla, se deshace) en
  `ApplePayDraftService`, `BankNoticeDraftService` y `BankEmailDraftService.materialize` (correo, web e IA). La IA vista en
  otro aparato se reconoce también dentro de un registro de unión.
- «Separar» en `InboxDraftEditSheet` (`InboxJoinedSourcesSection`, textos en `BandejaUnir.strings`, 16 idiomas).
- iCloud: `CD_joinRecordRaw` en los `.ckdb` de desarrollo; producción en `pendingProductionDeploy` (lo despliega Dan).
- Nube: `inbox_drafts.join_record_raw` (`since: 11`, manifest v11), apunte y reemisión al subir de versión, DDL de
  staging, migración `qa/cloud/g36_01_*` con su marcha atrás, tests del gateway a v11.
- Semilla `-uitest-inbox-joined-draft`.

## Pruebas
- `YalaTests/BandejaUnirAlLlegar/`: escenarios E1, E2, E4, E8, E9 por el código real de cada fuente, grupos fuera,
  registro ilegible, IA en otro aparato, Separar (con y sin ediciones), revert; lógica pura; canal v10/v11; base de 2.2.
- `YalaUITests/BandejaUnirAlLlegar/BandejaUnirAlLlegarUITests`: un pendiente, «Separar», dos pendientes.
- Mutantes: Separar sin respetar ediciones y la IA absorbida olvidada caen.

## Pendiente fuera de este lote
- Desplegar `CD_joinRecordRaw` a CloudKit Production, `g36_01` y el Worker v11 (staging → producción) antes de
  publicar una build que lo escriba. `scripts/asc-preflight.sh` para la subida mientras falte lo de iCloud.
- Lote 3 (la fila con las fuentes, «¿Es el mismo gasto?», «Ya registrado») y lote 4 (planificados).
