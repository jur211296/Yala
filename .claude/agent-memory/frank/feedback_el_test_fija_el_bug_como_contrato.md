---
name: el-test-fija-el-bug-como-contrato
description: Antes de cambiar un contrato, busca el test que da el comportamiento VIEJO por correcto; el 24-sep el golden 28 esperaba del reintento justo el `existing_stable` que era el bug
metadata:
  type: feedback
---

**Al cambiar un contrato, grep del valor viejo en los tests ANTES de darlo por nuevo.** Un test puede estar fijando el
bug como si fuera la especificación, y entonces el cambio correcto lo pone en rojo —o, si ese test salta por estado
previo, lo deja en verde mintiendo—.

**Why:** en `claim-promotion-lost-response-blocks-the-retry` (2026-09-24) el golden 28 del gateway tenía un paso «(4)
Idempotente: repetir la promoción → `existing_stable`» del MISMO dispositivo: era exactamente el bloqueo que el ticket
arreglaba, escrito como contrato. Y el golden 1 dependía, sin decirlo, de si el usuario A tenía filas en el contador.
Los dos salían en skip ese día (estado previo), así que ninguna corrida los habría cantado.

**Y el golden que no fija su estado lo hereda de la corrida ANTERIOR** (2026-09-24, g16_04): el 9 y el 9-bis heredaban
el `migrated_at` del golden 6, y el 3 heredaba de la última corrida un lease vencido con `migrated_at` — pasaban con el RPC
viejo por casualidad y el cambio los puso en rojo sin que describieran el caso nuevo. Al cambiar una rama del RPC, cada
golden que llegue a ella tiene que fijar por PATCH TODAS las columnas que la rama lee.

**How to apply:** `grep` del valor que el cambio retira (aquí `existing_stable`) en `gateway/test`, `YalaTests` y
`qa/cloud`; por cada acierto, ¿describe el caso nuevo o el viejo? Y los tests que saltan por estado previo se leen
enteros: su verde no dice nada. Relacionado: [[el-predicado-del-ticket-no-es-el-criterio]],
[[mis-mediciones-fallan-por-el-filtro]].
