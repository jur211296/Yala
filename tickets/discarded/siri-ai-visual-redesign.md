---
id: siri-ai-visual-redesign
status: discarded
priority: medium
area: "siri, design, ux"
created: 2026-09-17
source: "UX Jürgen 2026-09-17 — rediseño; brief visual pendiente de Dan (sesión de ideas en Claude)"
---

# Rediseño visual de la integración Siri AI

## Qué quiere Jürgen

Un **rediseño** de la experiencia Siri AI (no solo el ticket de investigación de plataforma). Dijo que **Dan tenía info** de una sesión de ideas visuales que él tuvo en Claude.

## Estado

- Frank preguntó a Dan (2026-09-17) por el material de esa sesión.
- Hasta tener el brief/transcript, **no implementar**.
- Relacionado pero distinto: `siri-ai-integration-ios-27` (investigación de plataforma iOS 27).

## Siguiente paso

Pegar aquí el resumen/brief de Dan y entonces partir diseño + tickets de implementación.

## 2026-09-17 — Dan no tiene el material

Dan buscó memoria, transcript y tickets: no hay brief visual. Solo existe este stub + `siri-ai-integration-ios-27` (plataforma, sin spec). Pendiente de que Jürgen aporte el chat/export de la sesión Claude; hasta entonces no se diseña.

## 2026-09-17 — Dan: el material era el pack UI del 15-sep (posible mal etiquetado)

Dan no encontró una sesión «Siri AI» aparte. Lo que hay es el **pack de referencias UI del 15-sep** (PRs #171/#172), commit `0c4f58ff0`:

- Memorias Frank: `.claude/agent-memory/frank/reference_skills_pulido_ui.md` (`better-ui` + `emil-design-eng`), `reference_ui_flujo_por_pasos.md`, `reference_ui_onboarding_login.md`
- Capturas: `docs/design/referencias/`
- Tickets ya abiertos ese día: `ai-chat-reads-heavier-than-a-messaging-app`, `settings-redesign-as-grouped-lists-like-ios`

Usar como contexto de rediseño UX. **No inventar diseño** — las referencias ya están. Pendiente confirmación de Jürgen: ¿el pedido «rediseño Siri AI» era este pack mal recordado, o hay otra sesión solo de Siri?

## Descartado (2026-09-17)

Jürgen aclaró: **no era Siri AI**. Se refería al **chat Yala AI** en la app, y cada punto del pack UI del 15-sep va como ticket aparte (nada que ver con `siri-ai-integration-ios-27`).

Sustituto: `ai-chat-reads-heavier-than-a-messaging-app`. Pack Dan → tickets propios (ajustes, flujo por pasos, onboarding login, reglas de pulido).
