---
name: medir-la-web-a11y-y-preview
description: Trampas medidas el 2026-09-03 al auditar Web/ con axe, Lighthouse y un preview de Vercel — y una de zsh que me borró un bloque de código
metadata:
  type: feedback
---

**Al medir la web, cuatro cosas que ya me engañaron una vez:**

1. **axe sobre contenido con `opacity: 0` devuelve 0 violaciones y no es verde: es ciego.** El scroll-reveal
   de la home oculta el 90 % hasta que corre el observer. Antes de `axe.run`, forzar
   `.animate-on-scroll → .is-visible`. Y Lighthouse hereda el mismo hueco (su 100 de a11y no medía la home).
2. **En el navegador automatizado las transiciones CSS se quedan congeladas.** axe leía el color a mitad de
   `transition-all` y daba falsos positivos (botón secundario «#818cf8 en claro» que en realidad era `#4F46E5`).
   Inyectar `*{transition:none!important;animation:none!important}` antes de medir, y comprobar con
   `getComputedStyle` cuando axe y la vista no coincidan.
3. **Un preview de Vercel con SSO no se prueba con curl ni con la extensión de Chrome** (302 a `sso-api`; la
   extensión no tiene permiso en `*.vercel.app`). Lo que sí se puede medir sin login: que `vercel.json` entró
   en el deploy, leyendo `.vercel/output/config.json` tras `vercel build` (rutas con `has`/`missing`, headers).
   El comportamiento en vivo se lo dejo a Jürgen con pasos, o se prueba en `yala-app.pe` tras el merge. Y
   `vercel deploy --prebuilt` desde `Web/` funciona aunque el proyecto tenga Root Directory `Web` (el prebuilt
   esquiva ese ajuste); nunca `--prod`.
4. **El `npm run dev` de Astro no suelta un middleware borrado**: sigue registrado en el proceso y la página
   entera se cae con `MiddlewareCantBeLoaded`. Reiniciar el dev server tras borrar `src/middleware.ts`.

**Y una de mi propio taller:** en zsh, un heredoc suelto sin comando (`<<'X' … X`) **imprime su contenido**
(NULLCMD=cat) en vez de quedarse en stdin, y un `python3 - <<'PY'` que luego hace `open('/dev/stdin')`
lee vacío porque su stdin ya se consumió. Me borró el `<script>` entero de `HomePage.astro` y solo lo vi
porque conté `<script>` después. Para inyectar bloques largos: `cat >> fichero <<'X'` o el tool `Write`.

**Dos más, del 4-sep, al renderizar la web con Chrome sin cabeza para enseñársela a Jürgen:**

5. **`serve -s` reescribe TODO lo que no conoce a `index.html`**, y su *clean URLs* convierte `/x.html` en
   `/x` antes de buscar el fichero: mis copias «oscuro/claro» servían siempre la home real, y el tema
   «forzado» nunca cambiaba. Para renders con variantes, `python3 -m http.server` en otro puerto (sin
   reescrituras) y nombres únicos por corrida. El headless además **prefiere tema claro** y **no baja de
   ~500 px de ancho** (un `--window-size=390` recorta, no emula); para móvil, la captura de página entera de
   Lighthouse (`fullPageScreenshot.screenshot.data`, 412 px) o un iframe de 390 px en la extensión.
6. **`SendUserFile` rechaza (400) una imagen muy alta** (412×9458): partirla en columnas antes de enviarla.

**Why:** cada una me costó una vuelta y las dos primeras habrían dejado pasar 16 fallos de contraste con un
informe que decía «0 violaciones».

**How to apply:** cualquier auditoría de `Web/` (a11y, Lighthouse) y cualquier deploy de preview.

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] · [[web-pr62-espera-a-jurgen]]
