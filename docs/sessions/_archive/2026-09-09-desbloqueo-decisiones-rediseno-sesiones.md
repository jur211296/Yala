---
fecha: 2026-09-09
tags: [sesiones, rediseño, decisiones, desbloqueo]
---

# Desbloqueo del rediseño de sesiones: las decisiones, ticket a ticket

## Qué es esto y cómo se usa

Antes de soltar la cola autónoma del rediseño de sesiones, Jürgen pidió que **cada ticket pasara por una
pasada de preguntas**: cualquier ambigüedad, supuesto, borde, copy o criterio se le preguntó de frente en
vez de resolverlo por defecto. Esta sesión hizo esa pasada sobre los **trece tickets** del runbook
`session-redesign-implementation-order`.

**Este documento es un índice, no la fuente.** Las decisiones viven **dentro de cada ticket**, en una
sección final llamada **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»**, que es donde las va
a leer quien implemente. No se copian aquí a propósito: duplicarlas es exactamente como divergen.

**Esas secciones mandan sobre el cuerpo del ticket y sobre el ADR** cuando se contradigan. Varias derogan
cosas escritas antes, y se dice en cada caso.

## Dónde está cada una

| # | Ticket | Lo que se desbloqueó |
|---|---|---|
| 0 | `retire-guest-vocabulary-for-session-terms` | **adelantado al paso 0**; dos vocabularios que conviven (interno vs. copy) |
| 1 | `wrangler-prod-onboarding-choice-percent-drift` | alcance del test de percents, sin red; sí se despliega tras mergear |
| 2 | `backend-account-kind-complete-or-groups-only` | **fresh start de producción, `auth.users` incluido**; columna `kind` explícita; corrección al refrescar |
| 3 | `cloud-sign-in-discovers-account-kind` | adopción silenciosa; `.notFound` va al consentimiento; Grupos cambia de motor, no de aspecto |
| 4 | `welcome-private-fresh-start-skips-icloud-check` | se pregunta a CloudKit **antes** de relanzar; alert con cifras y tercera salida «restaurar» |
| 5 | `groups-only-second-launch-mounts-icloud-mirror` | esperar al export antes de borrar; avisar sin confirmar; **evitar el relanzamiento** |
| 6 | `beacon-routes-only-never-blocks` | el chooser entero, privado incluido (deroga A26); faro huérfano se cubre aquí |
| 7 | `onboarding-purpose-drops-groups-card` | borrar el caso del enum y su gate; los textos se retiran |
| 8 | `full-mode-activation-must-ask-where-personal-data-lives` | el historial de grupos al Panel **se pregunta**; promoción al final; gana lo restaurado |
| 9 | `session-exits-one-verb-per-session` | salida de emergencia avisada; «Vaciar datos» dice que borra en todos los dispositivos |
| 10 | `groups-account-association-in-storage-row` | **se pregunta** qué hacer con las filas puenteadas; identidad completa, no hash |
| 12 | `shell-derives-from-two-session-axes` | **sin migración legacy**; un solo PR; grep cero también en comentarios |
| 13 | `after-session-redesign-review-widgets-siri-applepay-and-web-copy` | **partido en dos**; el widget invita a activar Yala completo |
| — | `session-redesign-web-and-store-copy` | **ticket nuevo** (de Lola): política y términos **bloquean el release** |

El **11 quedó vacante**: era el vocabulario, que pasó al paso 0. Los demás no se renumeran porque las
secciones de decisiones se citan entre sí por estos números.

## Lo que cambió fuera de los tickets

- **El runbook** (`session-redesign-implementation-order`) gana una **regla 0**: las decisiones ya están
  tomadas y no se repreguntan; y su tabla de orden refleja el paso 0 y el reparto del 13.
- **Un ticket nuevo**, `session-redesign-web-and-store-copy`, con la mitad de Lola.
- **`docs/TICKETS.md`** reindexado (259 = 259 contra disco).

## Lo que se midió en esta pasada, y no estaba escrito antes

Cinco mediciones cambiaron una respuesta o descartaron una premisa:

1. **Producción son dos cuentas, las dos de Jürgen, y cero datos de terceros** (MCP Supabase, proyecto
   `kefvaiymtgytemwbltlz`). Los dos grupos tienen exactamente esas dos cuentas como miembros. Con eso
   delante, Jürgen decidió el fresh start. El detalle, con conteos, está en el ticket 2.
2. **`profiles.personal_claimed_at` ya clasifica bien las dos cuentas**, así que el «medir en staging qué
   tabla lo prueba» del ticket 2 estaba contestado antes de empezar.
3. **`OnboardingUsageMode.groupsOnly` no se persiste** (es `@State`), así que borrarlo no rompe a nadie.
4. **`OnboardingUsageMode` y `UsageFocus` son dos enums distintos con un case homónimo**, y el docblock de
   `OnboardingGroupsPurposeGateLogic:15` afirma lo contrario. Eso convirtió una contradicción aparente
   entre dos respuestas de Jürgen en una falsa alarma.
5. **`SECONDARY_SESSION_ROLLOUT_PERCENT` está en 100 en staging** (`gateway/wrangler.toml:56`) aunque M1
   se retire: un dispositivo de pruebas contra staging sí puede tener datos en `YalaModel-Secondary`.

## Huecos nuevos que esta pasada abrió, y dónde quedaron

- **El espejo que se adjunta tarde** repite el bug del ticket 4 por la puerta de atrás (activar iCloud
  después de haber hecho el onboarding sin él). Se cubre **dentro del ticket 4**.
- **El faro huérfano** tras el fresh start apuntará a una cuenta borrada. Se cubre **dentro del ticket 6**,
  y con él se cierra `restore-beacon-outlives-account-deletion`.
- **`GroupsRetentionView` escribe `UsageFocus.groupsOnly`**: anotado en el **ticket 12** (y el 9 retira esa
  vista entera; el que llegue antes se lo lleva).
