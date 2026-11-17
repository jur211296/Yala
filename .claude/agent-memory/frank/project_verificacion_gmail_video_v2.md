---
name: verificacion-gmail-video-v2
description: Verificación de gmail.readonly (yala-502622) — v3 rechazado el 15-nov (Source Account Impact, End-to-End); v4 hecho el 16-nov, espera que Jürgen lo apruebe y Dan lo suba
metadata:
  type: project
---

Historia: v2 (12-nov) no valía; v3 (12-nov) enviado; Google lo rechazó el 15-nov pidiendo ver el correo en la cuenta de
Gmail de origen y el flujo de punta a punta en la cuenta de Google. **v4 (16-nov)** en
`~/Claude/entregas/2026-11-16-video-verificacion-gmail-google-v4/` (Max) con artifact https://claude.ai/artifact/LQMrk6LA2rEo8zuHiz87ck.
Espera: Jürgen aprueba, Dan lo sube sin listar y responde a Google.

**Why:** Frank no sube a YouTube ni contesta a Google (lo prohíbe el encargo), y el login de Google lo hace él.

**How to apply:** si hay v5, partir de `docs/verificacion-google/video-v4-2026-11-16.md` (plan, montar.py y la trampa
de `recordVideo`). El simulador `Yala-Gmail-Video` de la Max quedó con la sesión de Jürgen en Safari y en la hoja de
Google de Yala: **son dos inicios de sesión distintos**, pídelos juntos en un solo BLOQUEANTE. El ejemplo de correo
cambia con los días: Yala lee los 5 últimos del BCP; mide antes de escribir el guion.
Ver [[consola-google-cloud-authuser]], [[idioma-de-google-en-el-simulador]], [[taps-en-la-hoja-de-google]].
