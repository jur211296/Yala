---
name: verificacion-gmail-video-v2
description: Verificación de gmail.readonly (yala-502622) — video v3 hecho el 12-nov con las 3 correcciones de Jürgen; espera que Jürgen lo apruebe y Dan lo suba
metadata:
  type: project
---

El 11-nov Google pidió otro video. El v2 (12-nov) no valía: permisos de inicio de sesión sin abrir, borrador «Disney
Plus» que parecía un correo de Disney y sin selector de cuenta. El **v3** (12-nov, `~/Claude/entregas/2026-11-12-video-verificacion-gmail-google-v3/`
en la Max) corrige las tres cosas. **Espera a Jürgen:** que lo apruebe; subirlo a YouTube y responder lo hace Dan.

**Why:** Frank no sube a YouTube ni contesta a Google (lo prohíbe el encargo), y el login de Google lo hace él.
El proyecto tiene **tres** clientes OAuth desde el 4-nov («Yala Web (MCP)», solo `email profile`).

**How to apply:** si hay que regrabar, montaje con `docs/verificacion-google/video-v3/` (plan.json + montar.py con
`mask`). Receta de toma limpia sin contraseña: Jürgen inicia sesión una vez; ensayo dejando Gmail SIN marcar (concede
solo los de inicio de sesión) → la toma muestra «Choose an account» y «See the 3 services» sin pedir contraseña.
El simulador nuevo necesita cuentas creadas a mano (no trae categorías: no se puede guardar el borrador).
Ver [[consola-google-cloud-authuser]], [[idioma-de-google-en-el-simulador]], [[taps-en-la-hoja-de-google]].
