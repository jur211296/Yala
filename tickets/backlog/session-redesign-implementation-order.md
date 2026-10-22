---
id: session-redesign-implementation-order
status: backlog
priority: high
area: "proceso, modo-nube, onboarding, groups, settings"
created: 2026-09-09
source: "ADR 2026-09-09 «Sesiones — dos ejes» · pedido por Jürgen para que Frank Bot lo siga ticket a ticket"
---

# Rediseño de sesiones — el orden de implementación, para seguirlo uno tras otro

## Para quien lo ejecuta

Este ticket no se implementa: **se sigue**. Jürgen va a pedir «implementa el siguiente» y el siguiente
es el primero de la lista de abajo que no esté en `tickets/done/`. Se cierra cuando los 13 estén hechos.

Reglas fijas para CADA paso:

0. **Las decisiones ya están tomadas: no las repreguntes.** El 2026-09-09 Jürgen recorrió los trece
   tickets uno a uno y contestó cada ambigüedad. Cada ticket lleva al final una sección
   **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»** que **manda sobre el cuerpo del ticket
   y sobre el ADR** cuando se contradigan. Léela ANTES que nada; varias derogan cosas escritas arriba.
   El índice de la pasada está en `docs/sessions/2026-09-09-desbloqueo-decisiones-rediseno-sesiones.md`.
   Si aun así aparece una decisión nueva de producto, **para y pregunta**: no la inventes.

1. **Leer antes de tocar**: el ADR (`docs/DECISIONS.md` → «[2026-09-09] Sesiones — dos ejes»), la matriz
   (`docs/sessions/2026-09-09-matriz-escenarios-sesiones.md`) y el ticket entero. Las líneas citadas son
   del árbol `3a94604e` y **envejecen**: re-greppear cada una antes de abrir el fichero.
2. **Un ticket = una sesión = un PR.** No se empieza el siguiente hasta que el anterior esté mergeado en
   `2.1`; varios de ellos tocan `WelcomeCloudSignInView` y `CloudSignOutFlowLogic` y en paralelo chocan.
3. `/spec` + Plan Mode + `/review-plan` **obligatorios** en los pasos marcados **[spec]**; en los demás,
   construcción directa con `/verify-ios` en el bucle corto.
4. **Review adversarial** (varias lentes + refutación por hallazgo) en los pasos marcados **[adv]**: tocan
   mount del store, borrado de datos, identidad o sync. El 8-sep una review así cazó siete defectos de un
   arreglo que se daba por bueno.
5. `/gate` en verde antes de commitear. Si un paso **borra** código, la suite entera, no la filtrada.
6. Al cerrar cada paso: marcar en la matriz las filas que ese ticket cubre como «verificada por <test o
   device-QA>», y actualizar `qa/coverage-index.json` en el mismo commit.
7. Lo que exija **device-QA** (CloudKit no existe en simulador) se deja en `tickets/qa/` con el montaje
   descrito en el ticket; lo prueba Jürgen. No se declara PASS desde el simulador.

## El orden (dependencias reales, no preferencias)

| # | Ticket | Por qué aquí | Modo |
|---|---|---|---|
| **0** | `retire-guest-vocabulary-for-session-terms` | **movido aquí el 2026-09-09**: fija el vocabulario ANTES de que los pasos 4-10 escriban copy nuevo. Es docs puro, va directo a `2.1` sin gate y **no bloquea al paso 1** | directo |
| 1 | `wrangler-prod-onboarding-choice-percent-drift` | protege algo que YA está en producción; cualquier deploy del gateway sin esto apaga la elección nube | directo |
| 2 | `backend-account-kind-complete-or-groups-only` | el dato del que dependen 3, 8, 9 y 10. Staging primero (runbook de DDL), luego prod | **[spec]** |
| 3 | `cloud-sign-in-discovers-account-kind` | el bloque [I]; sin él ninguna puerta sabe rutear | **[spec] [adv]** |
| 4 | `welcome-private-fresh-start-skips-icloud-check` | bug medido en device; independiente de 2-3 | **[adv]** |
| 5 | `groups-only-second-launch-mounts-icloud-mirror` | bug medido en device (captura); retira la puerta «datos ajenos» | **[adv]** |
| 6 | `beacon-routes-only-never-blocks` | necesita 3 para «crear con Google» | directo |
| 7 | `onboarding-purpose-drops-groups-card` | pequeño e independiente; aquí para no dejar la card viva cuando 8 abra el chooser | directo |
| 8 | `full-mode-activation-must-ask-where-personal-data-lives` | necesita 2, 3 y 4 (validación de iCloud) | **[adv]** |
| 9 | `session-exits-one-verb-per-session` | necesita 3 (`kind`); lleva el export de CloudKit antes del borrado | **[spec] [adv]** |
| 10 | `groups-account-association-in-storage-row` | necesita 2, 3 y 9 (el «equipo» usa la asociación) | **[adv]** |
| 12 | `shell-derives-from-two-session-axes` | el barrido de las 19 vistas y la retirada de M1; necesita TODO lo anterior | **[spec] [adv]** |
| 13 | `after-session-redesign-review-widgets-siri-applepay-and-web-copy` | solo tiene sentido sobre la app terminada. **Partido el 2026-09-09**: la mitad de web/ficha/legal es de Lola y vive en `session-redesign-web-and-store-copy` | medir |

> **El número 11 está vacante a propósito.** Era `retire-guest-vocabulary-for-session-terms`, que el
> 2026-09-09 pasó al paso 0. Los demás **no se renumeran**: las secciones de decisiones de los tickets
> se refieren unas a otras por estos números («lo mira el ticket 12», «necesita el 3»), y renumerar
> rompería esas referencias. Siguen siendo doce pasos de código más el paso 0 de vocabulario.

## Lo que Jürgen tiene que hacer entre pasos

- Tras el 2: aplicar la migración en staging y luego en prod (credencial DDL).
- Tras el 4, 5, 8, 9 y 10: device-QA con CloudKit real (su iPhone + una reinstalación).
- Tras el 12: la tanda de device-QA de la matriz entera, y avisar a Lola para el 13.
- **Antes de publicar el rediseño en la App Store:** la política de privacidad y los términos tienen que
  estar corregidos (hoy afirman que Grupos viaja por iCloud). Decisión de Jürgen del 2026-09-09: eso
  **bloquea el release**. Vive en `session-redesign-web-and-store-copy`.

## Criterio de cierre de ESTE ticket

- [ ] Los 13 en `tickets/done/` (o `qa/` con device-QA pendiente, si Jürgen lo prefiere así).
      `session-redesign-web-and-store-copy` **no cuenta**: es de Lola y se cierra por su cuenta.
- [ ] La matriz con todas sus filas marcadas como verificadas.
- [ ] `docs/sessions/2026-09-09-*` movidos a `docs/sessions/_archive/`.
