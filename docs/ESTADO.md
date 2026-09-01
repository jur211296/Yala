---
updated: 2026-09-01
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-01 (Lima)

**Rama** `2.1` · **HEAD** `5fa484b3`. TestFlight build **12** (CPV 12).
**Subida Yala (TF/store) = solo Mini.**

## Esta sesión
Las contraseñas de las cuentas de test de staging salen del repo: se leen del entorno en los tres
frentes que las usaban (tests de Swift, `qa/cloud`, goldens del gateway) y `qa/cloud/README.md`
dice qué exportar. Con eso caen las 4 exenciones de la allowlist. **La app no cambia.**
Dos correcciones medidas a doc envejecida: el hook de secretos **ya no está registrado en ningún
`settings.json`** (ADR-009) ⇒ nada escanea antes de un push; y `encargos/` **sí está versionado**.
**Proceso nuevo** (`CLAUDE.md` → «Dónde se commitea»): la rama la decide **dónde corre la sesión**.
Árbol principal → commit directo en `2.1` sin PR, también código, con `/gate` verde y sin trabajo
ajeno en el árbol. Worktree → rama y PR. Solo-documentación va directo, salvo `.claude/`.

## Abiertos
- **`ci-suite-simulador-duplicada-y-allowlist-incompleta`** (backlog, alta) — el CI corre la
  suite **dos veces por commit** (~100 min cada una) y la corre para cambios de `gateway/` y
  `qa/cloud/`, que no son input de `xcodebuild`. Medido; con chip.
- **El sello de `/gate`** — `git add` de un fichero nuevo invalida la huella y bloquea el commit
  diciendo en falso que el código cambió. Aislado hoy. Sin ticket; con chip.
- **`AUDIT-appstore-guidelines.md`** — 3 hallazgos de alto riesgo de rechazo por la divulgación
  del uso de OpenAI, sin atacar. Es de Lola (copy de ficha, consent, `PrivacyInfo.xcprivacy`).

## Release 2.1 (sin cambios)
2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 ·
GROUPS_BACKEND 100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device,
no corrida; D-R1 sigue sin `ok_` (QA device pendiente). **Cero `ok_` inventado.**

## Siguiente
El ticket de CI: quitar el run duplicado y ampliar la allowlist. Medido y con chip.

## Bloqueo
Ninguno.
