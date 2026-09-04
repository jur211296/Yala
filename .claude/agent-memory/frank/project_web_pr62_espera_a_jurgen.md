---
name: web-pr62-espera-a-jurgen
description: Revisión web del 2026-09-03 (PR #62, preview Vercel) — qué espera de Jürgen y las dos decisiones legales/identidad que dejé sin tocar a propósito
metadata:
  type: project
---

**El PR #62 (`encargo/2026-09-03-revision-web-ux-a11y-preview`) espera a Jürgen: revisar el preview y
mergear.** Informe formal en `Web/REVISION-WEB-UX-A11Y-2026-09-03.md`. Preview
`https://yala-kwy4wozwi-jur211296s-projects.vercel.app` (protección SSO: solo con su login de Vercel).

**Why:** el encargo pedía preview y PR, nada en producción — aunque `CLAUDE.md` deja pasar los diffs de
`Web/` directo a `2.1` desde un worktree, `2.1` es lo que Vercel publica, así que su encargo escrito ganó a
la regla general. Y actué sin esperar aprobación por «más de 3 ficheros» porque el encargo era la
aprobación escrita («implementa los cambios que consideres razonables»); si Jürgen lo corrige, esta nota
se actualiza.

**Lo que dejé sin tocar y es decisión suya (caduca cuando decida):**

- **Texto legal de Grupos (4 claves × 6 idiomas)** dice «vía iCloud, no por servidores nuestros»; el repo
  tiene backend propio de Grupos al 100 % en prod (`gateway/wrangler.toml:166`). No reescribí texto legal
  sin que él verifique el camino real del dato. Medido: existencia del backend y del flag. Inferido: qué
  ruta usa hoy un usuario.
- **Autoalojar Inter** (RGPD DE/FR/IT/PT, sentencia Múnich 2022): binarios en el repo + identidad tipográfica.
- **Tono del acento** en texto pequeño: `#6366F1` → `#818CF8` en oscuro por contraste. Es `--accent` en
  `global.css`; si prefiere otro, una línea.
- **Tema del sistema por defecto** (antes siempre oscuro): script del `<body>` en `Layout.astro`, una línea.

**How to apply:** si vuelve a pedir trabajo en `Web/`, primero mirar si #62 se mergeó (`gh pr view 62`) y
si tomó alguna de estas cuatro; no repetir la auditoría — está en el informe con fecha y método.

Relacionado: [[decisiones-que-esperan-a-jurgen]] · [[medir-la-web-a11y-y-preview]]
