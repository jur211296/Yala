---
updated: 2026-09-01
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-01 (Lima)

**Rama** `2.1` · **HEAD** `a2df76fb` — *Merge pull request #56 (la receta de snapshots del /cerrar no borraba nada)*.
En TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión
Higiene, sin tocar la app. Fuera el comando `/bug-triage` y sus dos llamadas a un webhook de
n8n muerto hacía un mes. Las cuentas de test del Supabase de staging estaban en claro en el
repo, que es público: **rotadas y verificadas** (las viejas ya no autentican). Se tituló el
ticket de prefs para el kanban y se arregló el bloque de disco de `/cerrar`, que llevaba sin
liberar un byte y sin avisar. Y 27 ramas fuera: sólo quedan `1.0` y `2.1`.

## Abiertos
- **`staging-test-credentials-in-public-repo`** (backlog, alta) — rotación HECHA; falta sacar
  las credenciales al entorno en 16 ficheros y **retirar en el mismo movimiento** las 4
  exenciones de la allowlist, que hoy son un punto ciego.
- **`AUDIT-appstore-guidelines.md`** (`docs/audit/`) — tres hallazgos de alto riesgo de rechazo
  por la divulgación del uso de OpenAI, sin atacar. Es de Lola y toca copy de ficha, consent en
  16 locales y `PrivacyInfo.xcprivacy` (revisar D-C).
- **`encargos/` sin versionar** — es el canal del grokbot para dejar mandatos a este repo y el
  playbook promete que «queda versionado»; aquí nunca se commiteó, así que no sobrevive a un
  clon. Commitearlo, no borrarlo.

## Release 2.1 (sin cambios)
- 2.0.5 no se lanza. Release = 2.1. A7 y M5 en 2.1: **HOLD, no flip**.
- Prod: CLOUD_MODE 100 · GROUPS_BACKEND 100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0.
- Cola C: 9 ACs owner/device, no corrida. D-R1 sigue sin `ok_` (QA device pendiente).
- Cero `ok_` inventado.

## Siguiente
Atacar el ticket de credenciales: sacar los literales al entorno y quitar las 4 exenciones.

## Bloqueo
Ninguno.
