---
name: migrar-a-la-nube-no-adopta
description: PR #187 (2026-09-16) — «Migrar a la nube» ya no fusiona con una cuenta que tiene datos; en qa esperando el QA en iPhone contra staging, con diez tickets de residuales
metadata:
  type: project
---

«Migrar a la nube» ya no adopta: una comprobación antes del claim y la intención `migrateOnly` journaleada en el runner.
Ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`, en `qa`.

**Why:** el ticket decía «adopta y no sube lo mío» y la medición lo corrigió: el adopt sube lo local que el backend no
conoce, así que era una fusión silenciosa con la cuenta de otra persona. Jürgen decidió en tres rondas (D2–D4, D10,
D13–D15, D18), todas con la recomendada salvo D15, donde pidió permitir otro Apple ID en vez de aceptar el límite de
Sign in with Apple nativo.

**How to apply:**
- Lo que espera es el QA en iPhone del ticket (guion con SQL de staging). El simulador no firma, así que la respuesta real
  del servidor solo se ve ahí.
- **D18 deja una salida cerrada a sabiendas**: una migración abandonada por su líder, o por el mismo iPhone tras
  reinstalar, ya no se puede retomar desde «Activar la nube» en otro dispositivo. Si aparece en campo, el sitio es
  `settings-migrate-blocks-a-second-device-before-its-marker`, no reabrir el seguidor.
- El ticket `high` que dejó, `fresh-start-keeps-a-groups-session-that-migrate-promotes`, lo cerró el PR #190 en un teléfono sellado: ver [[sesion-anterior-tras-empezar-de-cero]].
- Relacionado: [[mi-puerta-bloquea-lo-que-su-propio-flujo-dejo]], [[una-ventana-dura-lo-que-su-reintento]].
