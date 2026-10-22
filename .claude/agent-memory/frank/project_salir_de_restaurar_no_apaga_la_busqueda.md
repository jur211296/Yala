---
name: salir-de-restaurar-no-apaga-la-busqueda
description: PR #196 — el token por intento y la puerta de montaje; en qa con 8 pasos en iPhone y dos Apple ID de trabajo, deciden el 3 y el 5
metadata:
  type: project
---

`restore-back-and-reenter-closes-the-live-session-window` quedó en `qa` el 2026-09-21 con el PR
**#196**. Salir de Restaurar y volver a entrar ya no apaga la ventana de sesión del intento vivo.

**Why:** el ticket pedía «un token por flujo» y eso solo no bastaba. La review adversarial cazó dos
caminos más, y los dos los cierra la misma pieza —que la espera no se monte sin intento—: el apagado
podía correr **antes** del encendido cuando el espejo ya estaba quieto, y `.iCloudDisabled` (que
ganó botón de reintentar en el #195) dejaba **dos esperas vivas** dentro de una sola pantalla.

**How to apply:**

- **Lo que espera es device-QA, y no se puede montar en simulador**: el defecto necesita que el
  import de CloudKit TARDE. Guion de 8 pasos en el ticket; **deciden el 3 y el 5**, los dos a los
  90 s, y el 4 pide apagar iCloud Drive.
- **El residual está acotado y tiene ticket**: `force-fetch-and-wait-ignores-cancellation` (medium)
  — la espera no observa cancelación y el `refresher` no hereda la del padre. Es coste, no
  corrupción, y la primitiva la usa el arranque de la app, así que no se toca de paso.
- Si alguien reabre este área, el Paso 0 del ticket tiene las cinco decisiones con su medición,
  incluida la que se descartó (`.task(id:)`) y por qué.

Relacionado: [[feedback_la_pantalla_se_monta_antes_de_decidir]] ·
[[project_vuelta_icloud_pide_volver_a_entrar]]
