---
name: techo-de-la-subida-del-snapshot
description: PR del 2026-09-22 — la subida de la ida (55 %) tiene techo 15 min/72 h, texto por motivo y «Cancelar»; la review cazó 10 defectos míos y dejó 2 tickets.
metadata:
  type: project
---

Ticket `snapshot-upload-has-no-ceiling-and-no-way-out`, a `qa` con guion de 7 pasos en teléfono (modo avión a mitad
de la subida). El encargo llegó VACÍO (0 bytes): se trabajó desde el ticket del mismo slug, y el hook de escritura exige
igualmente un `## Paso 0` en el fichero del encargo — se escribió allí un resumen que apunta al del ticket.

**Why:** la fase `uploadingSnapshot` cortaba sin evento ante cualquier fallo y la barra se quedaba al 55 % para siempre;
`verify-reads-a-failed-local-fetch-as-an-empty-outbox` le había añadido una segunda causa. Jürgen decidió en una
ronda de día: 15 min/72 h como la vuelta, texto POR MOTIVO (se apartó de mi recomendación de reusar el genérico),
«Cancelar» con confirmación, y solo la subida.

**How to apply:**

- **Los otros tres pasos de la ida sin techo** (22 %, 35 %, 80 %) esperan en `forward-migration-steps-have-no-ceiling-and-no-exit`.
  Allí ya hay piezas: `CauseStallClock` (compartido con la vuelta) y `StorageFailureCopyLogic`.
- **El 401 con la sesión guardada va al plazo LARGO**: lo cazaron las tres lentes. Ver
  [[feedback_el_copy_lo_elige_quien_produjo_el_motivo]], sección de la clasificación.
- **El «sí» de Cancelar se apunta en el runner** (`requestSnapshotCancel`) y vale para esa visita a la fase; sin él, un
  re-kick con red terminaba la migración que la persona acababa de cancelar.
- Residual inferido con ticket: `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved`.
- 18 mutantes medidos uno a uno, todos muertos al final; M1 sobrevivió a la primera tanda porque la limpieza de delante
  hacía equivalente el sello de la página salvo que pasara tiempo entre la página y el siguiente vistazo. El test que
  lo mata necesita un hook en el fake que avance el reloj DENTRO de una pasada (`onUploadSnapshot`).

Relacionado: [[project_reloj_por_causa_en_el_techo_pre_mount]], [[feedback_un_reinicio_se_mide_contra_su_cadencia]],
[[feedback_el_mutante_que_sobrevive_puede_sobrar]].
