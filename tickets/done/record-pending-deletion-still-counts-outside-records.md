---
id: record-pending-deletion-still-counts-outside-records
status: done
priority: low
area: "records, deletion"
created: 2026-10-20
updated: 2026-10-25
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

## Cerrado (cola 2.2 · lote 12.5, 2026-10-25)

Las dos mitades: (1) lo pendiente de borrar no carga en el Panel, Estadísticas, Buscar, los widgets, la ficha de cuenta, Presupuestos, el Informe ni Ajustes › Cuentas (`RecordPendingDeletion.visible`), así que no cuenta en sus cifras ni se edita desde ellas; siguen sin el filtro el Flujo de caja, Yala IA y la comprobación «¿hay registros?» de Perfil, que no enseñan el registro suelto; (2) dos borrados seguidos comparten aviso y plazo: «Eliminaste 2 registros · Deshacer» devuelve los dos, y el plazo se alarga al del último en vez de quitarle el «Deshacer» al primero (decisión reversible tomada en el Paso 0 del lote), con un tope de 30 s: pasado eso, lo que esperaba se borra antes de empezar otro lote. Tras la review adversarial: «Deshacer» rehace la foto de los widgets, y al vencer el plazo las pantallas recargan aunque el borrado no llegara a hacerse. Tests: `RecordPendingDeletionTests` (compartir el deshacer, borrar juntos al vencer, dejar fuera de las pantallas, cableado) y `UXAudit22Lote08UITests.test_twoDeletionsInARow_undoBringsBothBack`. El mismo hueco en los pagos planificados va en `scheduled-payment-pending-deletion-loses-undo-on-a-second-delete`.
