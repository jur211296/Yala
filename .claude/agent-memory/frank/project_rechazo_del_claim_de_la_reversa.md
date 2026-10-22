---
name: rechazo-del-claim-de-la-reversa
description: PR #186 — un rechazo del servidor al «Volver a iCloud» ya vuelve a la nube con nota y alerta; en qa por pasos en iPhone con SQL en staging; la review cazó que mi salida perdía el único productor de `complete`.
metadata:
  type: project
---

**Un claim de la reversa que el servidor no concede ya no deja la barra al 15 %** (PR #186, 2026-09-16). Vuelve al origen,
deja nota en la tarjeta y alerta con la pantalla delante; `other_leader` también avisa. Cinco respuestas de Jürgen, todas
con la recomendada, en el Paso 0 del encargo (D1–D17).

**Why:** must-fix de 2.1 («nube sin callejones»), gemelo del #185. Tras relanzar con la fase clavada el motor de la nube no
arrancaba: el daño era mayor que el que contaba el ticket.

**How to apply:**
- **Lo que espera es el device-QA**, y no es simulable: hace falta cuenta en la nube real. Cada rechazo se monta con una
  línea de SQL en staging y se deshace (guion en `tickets/qa/reverse-claim-rejection-has-no-way-out-in-the-client.md`).
  El de `not_complete` necesita abrir el trigger de `kind` dentro de la misma transacción.
- **La salida REPONE los pendientes del origen** que `reverseActivated` reemplaza (schema v5). Lo cazaron dos lentes: sin
  eso un líder con el `complete` a medias dejaba `migration_in_progress` puesto para toda la cuenta. Si alguien propone
  «simplificar» la salida a «sin efectos» a secas, esto es lo que se lleva. Ver [[mi-arreglo-deja-el-mecanismo-sin-productor]].
- **Residual aceptado con ticket:** un pendiente repuesto que falla siempre (líder desplazado) deja el motor sin arrancar
  esa sesión si relanzó con la vuelta a medias. Debajo hay dos gates que arrancan el motor con criterios distintos (el 14.7
  solo mira la fase; el controlador exige cero pendientes).
- **Tickets que deja:** `reverse-before-mount-stays-stuck-with-an-expired-session`, `reverse-tap-is-lost-while-a-resume-is-running`,
  `reverse-claim-exit-with-a-restored-failing-effect-keeps-the-engine-off`; y notas nuevas en
  `reverse-exit-on-a-reverted-account-rejects-the-retry` (tres caminos al mismo `not_complete`, raíz en el backend) y
  `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date`.
- Medido ese día: el cuerpo vivo de `migration_progress` en producción se lee con `execute_sql` (md5 `14fc5e2c…`).

Relacionado: [[reversa-abierta-a-born-cloud]] · [[antes-de-poner-techo-mide-que-la-espera-existe]].
