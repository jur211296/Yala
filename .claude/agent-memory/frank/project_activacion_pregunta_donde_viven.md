---
name: activacion-pregunta-donde-viven
description: Paso 8 del rediseño de sesiones (PR #137) — «Activar Yala completo» pregunta privado / nube; qué espera el ticket en qa y por qué el orden «modo completo antes de converger» no se toca
metadata:
  type: project
---

**«Activar Yala completo» ya pregunta dónde viven los datos personales** (paso 8, PR #137, 2026-09-11).
El ticket `full-mode-activation-must-ask-where-personal-data-lives` está en `tickets/qa/` esperando
**device-QA de Jürgen, NO simulable**: 10 recorridos (sonda de CloudKit, relanzar, restaurar con corpus
real, promoción real). Antes de probar, **reinstalar** si la sesión solo-grupos del teléfono es de antes
del 10-sep: si no, sale el aviso de reinstalar (correcto, pero no llega al chooser).

**Why:** la review adversarial (cuatro lentes) cazó 14 defectos MÍOS; el más caro: con el modo aún en
`.groupInvite`, el bridge BORRA la transacción real de cada gasto que re-puentea, y con el espejo bajando
un corpus restaurado esas son las de la vida anterior del usuario. Medido contra el bridge real, con su
control (`GroupsBridgeRestoreConvergenceBehaviourTests`).

**How to apply:**

- Si alguien reordena `commitPlan` o quita la guarda de modo de `GroupsBridgeRestoreConvergence`, ese test
  lo tumba a propósito: no es un rojo a «arreglar».
- Quedan cinco tickets en backlog; el que puede subir de prioridad es
  `completed-mode-escalates-a-second-groups-only-device` (un 2.º dispositivo solo-grupos queda en shell
  completa sin espejo) — preexistente, no lo introdujo este paso, y es decisión de Jürgen.
- `claim-promotion-lost-response-blocks-the-retry`: «Reintentar» tras una respuesta perdida bloquea. Los
  docblocks que decían «el claim es idempotente, reintentar es seguro» ya se corrigieron.

Relacionado: [[rediseno-sesiones-dos-ejes]], [[neutro-durable-solo-grupos]],
[[la-correccion-de-la-lente-reintroduce-el-bug]].
