---
id: pro-theme-resets-silently-when-pro-ends
status: backlog
priority: medium
area: pro, settings, themes
created: 2026-10-19
updated: 2026-10-19
source: lote decidido 2.2 · 06 — Yala Pro (encargo 2026-10-19-lote-decidido-2-2-06-yala-pro, PR #561)
---

# El tema de Pro vuelve al de siempre en silencio al perder Pro

## Qué pasa

Al acabarse Pro, `AppBootstrapper.checkForDowngrade` llama a `resetProThemeIfNeeded()` y el tema elegido (Rosa, Teal, Minimalista…) pasa a Liquid Glass sin ningún aviso. La persona abre Yala y la app ha cambiado de aspecto sin explicación.

## Contexto

La decisión L16-11 de Jürgen (2026-10-18) pide avisar una vez **antes de volver al icono original**, y es lo que hace el lote 06: la hoja de fin de Pro lo avisa y devuelve el icono al confirmar. Del tema no dice nada, así que se dejó como estaba.

## Pregunta para Jürgen

¿El tema entra en el mismo aviso? Opciones:
- A. Dejarlo como está (vuelve en silencio).
- B. Una línea más en la hoja de fin de Pro, «Tu tema vuelve a Liquid Glass», y que vuelva al confirmar, como el icono. ← recomendada: es la misma hoja y la misma regla de «no quitar nada sin decirlo».
