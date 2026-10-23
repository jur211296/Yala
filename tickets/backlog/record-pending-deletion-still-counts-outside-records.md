---
id: record-pending-deletion-still-counts-outside-records
status: backlog
priority: low
area: "records, deletion"
created: 2026-10-20
updated: 2026-10-20
source: "lote decidido 2.2 · 08 (L15-13), review adversarial"
---

# Un registro que espera su borrado con «Deshacer» sigue contando fuera de Registros

Desde L15-13 (2026-10-20) borrar un registro desde el menú, ⌫ o su detalle lo esconde de Registros y lo borra de verdad
a los 5 s, con el aviso «Eliminaste … · Deshacer» (`RecordPendingDeletion`, molde de los pagos planificados). Dos cosas
que vio la review adversarial y quedaron fuera, porque el molde de los pagos tiene las mismas:

1. **Durante esos 5 s el registro sigue en el Panel, Buscar, los widgets y el hero de Estadísticas**: solo lo esconde
   `RecordsViewModel.applyFilters`. Si en esos segundos se edita desde el Panel, la edición se pierde con el borrado.
2. **Un segundo aviso le quita el «Deshacer» al primero** (`DraftDiscardUndoNotice.show` llama a `hide()`): borrar dos
   registros seguidos deja el primero sin botón ni ⌘Z antes de tiempo, aunque su pregunta prometía unos segundos.

## Hecho cuando

Lo pendiente de borrar no se ve en ninguna pantalla mientras espera (o el Panel lo excluye de sus cifras), y dos
borrados seguidos conservan cada uno su «Deshacer» hasta su plazo. Con test.
