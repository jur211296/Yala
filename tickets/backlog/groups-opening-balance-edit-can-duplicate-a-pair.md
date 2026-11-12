---
id: groups-opening-balance-edit-can-duplicate-a-pair
status: backlog
priority: low
area: groups
created: 2026-10-28
updated: 2026-10-28
source: "hallazgo de la card t3fq (PR #667), review adversarial del 2026-10-28"
---

# Editar un saldo inicial puede dejar dos de la misma pareja y moneda

Desde la card t3fq rige «un saldo inicial por pareja y moneda»: `GroupExpenseService.setOpeningBalance` edita el que
había (`OpeningBalanceEdgeLogic.replaceable`). La regla solo vive en el ALTA. Dos caminos la saltan:

1. **Editar y cambiar la pareja o la moneda.** Con «Ana debe a Yo 100 PEN» y «Luis debe a Yo 50 PEN», editar el segundo
   (su fila en «Saldos iniciales» o el detalle del registro) y poner a Ana en «Quién debe» deja dos aristas Ana–Yo en
   PEN, que se suman. `updateOpeningBalance` no busca otra arista con la pareja nueva.
2. **Parejas con dos saldos de antes de la regla.** El menú de la persona abre uno nuevo (no elige uno a ciegas) y al
   guardar se reemplaza el más antiguo; el otro sigue ahí y se suma, aunque el usuario creyera estar poniendo el total.

No se pierde dinero: los dos saldos son visibles y editables. Lo que falla es la promesa de «uno por pareja».

Opciones: (a) en `updateOpeningBalance`, si la pareja y moneda nuevas ya tienen otra arista, fundirlas (editar ésa y
borrar la editada, con el guard de liquidaciones de las dos); (b) avisar en el formulario antes de guardar; (c) una
pasada que funda los duplicados legacy. (a) y (c) mueven datos sin preguntar: según la regla de cuándo pregunta la app,
probablemente toca (b) o preguntar.
