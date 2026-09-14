---
name: aviso-pasajero-cierre-nube
description: PR #156 — el cierre en la nube ya distingue el fallo pasajero de grupos; la premisa del ticket era falsa, la review cazó dos defectos en MIS tests, y deja 4 tickets.
metadata:
  type: project
---

**Cerrar sesión en una cuenta en la nube ya no culpa a tu conexión de cualquier fallo de grupos.**
PR #156, mergeado a `2.1` el 2026-09-14. Un 5xx, un cortafuegos o la red caída se anuncian como lo que
son —«no llegaron al servidor, siguen en tu teléfono, inténtalo en un rato»— **al momento**, sin gastar
reintentos. `.channelPaused` (#152) intacto.

**Why:** decisión de Jürgen en la cola overnight (opción 2 del ticket), el mismo criterio que se tomó
para el kill-switch el 2026-09-13: reintentar contra un servidor que falla gasta ~22 peticiones y
retrasa 45 s un aviso que ya se puede dar.

**How to apply:**

- **La premisa del ticket era falsa y se medía con un grep.** Decía que el camino perdía el presupuesto
  de 45 s; ese camino **nunca** consultó `GroupsSignOutRetryDecision` —llama al push-all directo—. Lo
  corregí dentro del propio ticket. Ver [[la-premisa-del-encargo-tambien-se-mide]].
- **Lo que queda vivo, y es lo primero que preguntará quien retome:** el aviso nuevo **solo se ve si el
  outbox personal ya drenó**. El paso 1 del mismo cierre (push-all personal) descarta el motivo con `_`
  y bloquea antes, así que con filas personales pendientes sale el genérico de siempre. Ticket:
  `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`.
- **Tickets que deja**, los tres en `backlog`: el del paso 1 (arriba), `…-a-groups-session-expiry-into-permanent`
  (`.sessionExpired` sigue colapsado en el paso 2 — su copy manda a «volver a iniciar sesión» a quien
  acaba de pedir lo contrario, y eso lo decide Jürgen) y `signout-blocked-alert-button-has-no-test-identifier`.
  Más uno de tooling: `readme-index-scans-internal-worktrees`.
- **Device-QA NO simulable** y el ticket está en `tickets/qa/` con guion de 5 pasos: exige que
  `/groups/push` falle de verdad. No hay seam (34 launch args, ninguno lo hace) y el encargo prohibía
  inventarlo.
- **El patrón que sirve para el próximo motivo nuevo:** el ternario se sustituyó por una función pura
  con `switch` exhaustivo sin `default` (`cloudSignOutGroupsBlockReason`). Con ella, el compilador
  obliga a pronunciarse en los tres `switch` de vista que consumen `BlockReason`. El case nuevo va
  **al final** del enum y lleva `breadcrumbSlug` para los logs.

Relacionado: [[403-infra-no-es-veredicto-de-cuenta]] (el PR #154, que dejó esta celda al descubierto) y
[[la-asercion-que-no-puede-fallar]], cuyo noveno eslabón salió de esta review.
