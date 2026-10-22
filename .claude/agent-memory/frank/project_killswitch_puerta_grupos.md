---
name: killswitch-puerta-grupos
description: PR #146 — con el kill de la nube bajado la cuenta de grupos ya se puede soltar; el predicado del ticket era el equivocado y la review lo cazó con dos lentes; device-QA SÍ simulable
metadata:
  type: project
---

**La fila «¿Dónde viven tus datos?» ya no desaparece cuando hay una cuenta de grupos que soltar, y la
entrada a la nube sigue cerrada bajo el kill.** PR #146, 2026-09-12, encargo autónomo de Jürgen.

**Why:** desde el paso 10 (9-sep) detrás de esa fila vive la única superficie para soltar la cuenta de
grupos, y Grupos va por otro flag ⇒ el kill de la nube apagaba un control de Grupos.

**How to apply — lo que hay que saber si se vuelve por aquí:**

- **El término no es `hasAssociation`**, aunque el ticket lo nombrara: es «hay una cuenta que esta
  pantalla pueda soltar» (`GroupsAssociationPresence.offersDetach`). El porqué, en
  [[feedback_el_predicado_del_ticket_no_es_el_criterio]].
- **`GroupsAssociationPresence` es nuevo y tiene un source-scan que prohíbe derivar ese estado por tu
  cuenta.** Si añades un tercer consumidor, entra por ahí.
- **La decisión de Jürgen del 6-sep («las dos puertas de la nube cerradas bajo el kill») sigue vigente**
  y se cumple con `offersCloudMigrationEntry`. Lo que cambió fue la premisa, no la política — anotado en
  la cabecera del gate y en `tickets/qa/reentry-killswitch-closes-both-doors.md`. No lo reabras creyendo
  que el código la desobedece.
- **El device-QA SÍ es simulable**, al revés que los de los pasos 8-10: toggle «Simular remote OFF» del
  panel DEBUG en un build `Yala Dev`. Ticket `device-qa-cloud-killswitch-groups-door`.
- **Deja cuatro tickets**, uno `high`: `groups-killswitch-403-blocks-detach-forever` — el mismo agujero
  por el eje de Grupos, y ahí la puerta está abierta pero el gesto es imposible si hay outbox pendiente.

La review adversarial (3 lentes + la rule de área) cazó **lo mío**: la divergencia de predicado (dos
lentes por caminos distintos), el gate que solo cubría el render, tres huecos en mis source-scans y una
aserción que no podía fallar.
