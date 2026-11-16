---
name: reference-vista-previa-vercel-protegida
description: La vista previa de Vercel de la web de Yala responde 302 al login; se lee con `vercel curl --deployment` sin depender de Chrome
metadata:
  type: reference
---

Las vistas previas de los PR que tocan `Web/` (`yala-app-git-<rama>-jur211296s-projects.vercel.app`) están tras la
protección de Vercel: `curl` devuelve 302 y la extensión de Chrome puede no estar conectada.

Lo que funcionó el 2026-11-09 (CLI 54.2, sesión `jur211296`):

1. Copiar `~/Yala/Web/.vercel/project.json` al `Web/.vercel/` del worktree (está en .gitignore).
2. `vercel curl /privacy --deployment <url de la vista previa> -- -s -o fichero.html` desde `Web/`.
3. La URL sale de `gh api repos/jur211296/Yala/deployments` filtrando por `ref` → `statuses[0].environment_url`.

Para capturas del «después», el mismo commit compilado y servido en local (`.vercel/output/static` con
`python3 -m http.server`) + `agent-browser screenshot --full`. Jürgen sí abre la vista previa con su sesión.
