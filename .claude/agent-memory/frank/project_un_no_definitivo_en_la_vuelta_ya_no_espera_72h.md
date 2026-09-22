---
name: un-no-definitivo-en-la-vuelta-ya-no-espera-72h
description: PR #209 — el 401/403 del Merkle en la vuelta a iCloud sale tipado y ya no cae en el techo de 72 h; la review cazó 7 defectos míos y dejó 2 residuales con ticket.
metadata:
  type: project
---

PR **#209** a `2.1`. Ticket `reverse-verify-network-bucket-hides-a-definitive-server-no`, a `qa` con guion de 5 pasos
en teléfono (el caso del 403 necesita staging).

**Why:** `SyncMerkle.verifyIntegrity` aplanaba el 401/403 de `/sync/merkle` en `fetch-failed`, el mapping lo mandaba a
`.networkTimeout` y la vuelta a iCloud manda la red al techo LARGO (72 h). La persona esperaba tres días ante un «no»
que ya era definitivo. La ventana viva era la del rechazo que empieza **entre el pull y el Merkle**: el push y el pull
tipaban desde el 16-sep, el Merkle era el tercero.

**How to apply:** si algo de esta zona vuelve, lo que hay que saber:

- **El 401 conserva el techo LARGO a propósito.** Solo el 403 y los dos `blocked` nuevos eligen el corto. Es una
  decisión, no un olvido: a la sesión la renueva la persona, que ahora ve la tarjeta mucho antes de las 72 h.
- **`MerkleSkipReason`** existe porque el literal del `reason` era una junta entre dos ficheros y el test del mapping
  se medía contra sí mismo.
- **La serie `cloudReversePreMountWaiting` cambió de valores con este build** (`server_x` → `stop_x`), y
  `cloudSyncAttestRequired` estrenó el edge `merkle`. Una comparación con datos anteriores a este build no vale.
- **Dos residuales quedaron abiertos y son reales**:
  `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` (el reloj del techo es de la FASE y la causa de
  la ÚLTIMA observación ⇒ un fallo local aislado tras horas de espera por red saca en el acto) y
  `verify-reads-a-failed-local-fetch-as-an-empty-outbox`.

**Lo que costó y no está en git:** la review adversarial de tres lentes cazó **siete defectos míos**, y tres de ellos
eran tests que yo había escrito y **no podían fallar**. Gate verde en la Mini ya en **macOS 27.0 / Xcode 26.6** (7412
unit en 741 suites, 15 XCUITest en 6 suites). Un rojo de XCUITest que apareció antes del reinicio de la Mini era una
**muerte del runner sin veredicto** —`Failing tests:` sin una sola línea `Test Case … failed`—: repetida aislada, 4/4
verde.

Relacionado: [[feedback_tipar_un_desenlace_despierta_defensas_dormidas]],
[[feedback_el_copy_lo_elige_quien_produjo_el_motivo]], [[project_tope_90s_no_cierra_con_import_bajando]].
